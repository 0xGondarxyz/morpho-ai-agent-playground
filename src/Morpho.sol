// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {
    Id,
    IMorphoStaticTyping,
    IMorphoBase,
    MarketParams,
    Position,
    Market,
    Authorization,
    Signature
} from "./interfaces/IMorpho.sol";
import {
    IMorphoLiquidateCallback,
    IMorphoRepayCallback,
    IMorphoSupplyCallback,
    IMorphoSupplyCollateralCallback,
    IMorphoFlashLoanCallback
} from "./interfaces/IMorphoCallbacks.sol";
import {IIrm} from "./interfaces/IIrm.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IOracle} from "./interfaces/IOracle.sol";

import "./libraries/ConstantsLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {MathLib, WAD} from "./libraries/MathLib.sol";
import {SharesMathLib} from "./libraries/SharesMathLib.sol";
import {MarketParamsLib} from "./libraries/MarketParamsLib.sol";
import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Morpho contract.
/// @dev ARCHITECTURE: Singleton contract managing isolated lending markets. Each market identified by keccak256(MarketParams).
/// @dev SECURITY: Uses CEI pattern - state updates before external calls. Callbacks execute after state is finalized.
/// @dev BOUNDS: All market totals use uint128 (max ~3.4e38). Virtual shares (1e6) prevent share inflation attacks.
/// @dev ROUNDING: All conversions round in protocol's favor - down for deposits, up for withdrawals/borrows.
contract Morpho is IMorphoStaticTyping {
    using MathLib for uint128;
    using MathLib for uint256;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using SafeTransferLib for IERC20;
    using MarketParamsLib for MarketParams;

    /* IMMUTABLES */

    /// @inheritdoc IMorphoBase
    bytes32 public immutable DOMAIN_SEPARATOR;

    /* STORAGE */
    // LAYOUT: Slots 0-8 used. See MorphoStorageLib for exact slot positions.
    // WARNING: position/market mappings store stale values - call accrueInterest() for current state.

    /// @inheritdoc IMorphoBase
    address public owner;
    /// @inheritdoc IMorphoBase
    address public feeRecipient;
    /// @inheritdoc IMorphoStaticTyping
    mapping(Id => mapping(address => Position)) public position;
    /// @inheritdoc IMorphoStaticTyping
    mapping(Id => Market) public market;
    /// @inheritdoc IMorphoBase
    mapping(address => bool) public isIrmEnabled;
    /// @inheritdoc IMorphoBase
    mapping(uint256 => bool) public isLltvEnabled;
    /// @inheritdoc IMorphoBase
    mapping(address => mapping(address => bool)) public isAuthorized;
    /// @inheritdoc IMorphoBase
    mapping(address => uint256) public nonce;
    /// @inheritdoc IMorphoStaticTyping
    mapping(Id => MarketParams) public idToMarketParams;

    /* CONSTRUCTOR */

    /// @param newOwner The new owner of the contract.
    constructor(address newOwner) {
        require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS);

        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)));
        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, ErrorsLib.NOT_OWNER);
        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @inheritdoc IMorphoBase
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != owner, ErrorsLib.ALREADY_SET);

        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    /// @inheritdoc IMorphoBase
    function enableIrm(address irm) external onlyOwner {
        require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET);

        isIrmEnabled[irm] = true;

        emit EventsLib.EnableIrm(irm);
    }

    /// @inheritdoc IMorphoBase
    /// @dev BOUNDS: lltv must be < WAD (1e18 = 100%). Common values: 0.8e18 (80%), 0.9e18 (90%).
    /// @dev SECURITY: Higher LLTV = more leverage = higher liquidation risk. Cannot be disabled once enabled.
    function enableLltv(uint256 lltv) external onlyOwner {
        require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET);
        // BOUNDS: LLTV >= 100% would allow infinite borrowing against collateral
        require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED);

        isLltvEnabled[lltv] = true;

        emit EventsLib.EnableLltv(lltv);
    }

    /// @inheritdoc IMorphoBase
    /// @dev BOUNDS: newFee must be <= MAX_FEE (0.25e18 = 25%). Fee is percentage of interest.
    /// @dev STATE: Accrues interest with OLD fee before applying new fee.
    function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(newFee != market[id].fee, ErrorsLib.ALREADY_SET);
        // BOUNDS: Protocol fee capped at 25% of interest
        require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED);

        // STATE: Accrue with OLD fee first - ensures fair accounting
        // Interest earned before fee change uses old fee rate
        _accrueInterest(marketParams, id);

        // STATE: Update fee for future interest accruals
        // BOUNDS: newFee <= MAX_FEE (0.25e18) fits safely in uint128
        market[id].fee = uint128(newFee);

        emit EventsLib.SetFee(id, newFee);
    }

    /// @inheritdoc IMorphoBase
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /* MARKET CREATION */

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Permissionless - anyone can create markets with whitelisted IRM and LLTV.
    /// @dev MATH: Market ID = keccak256(abi.encode(loanToken, collateralToken, oracle, irm, lltv)).
    /// @dev EXTERNAL: Calls IRM.borrowRate() to initialize stateful IRMs.
    function createMarket(MarketParams memory marketParams) external {
        // MATH: Market ID is deterministic hash of all parameters
        Id id = marketParams.id();

        // SECURITY: Only owner-whitelisted IRMs and LLTVs can be used
        require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED);
        require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED);

        // SECURITY: Cannot recreate existing market (lastUpdate > 0 means market exists)
        require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED);

        // STATE: Initialize market with current timestamp
        // NOTE: All other market fields start at 0 (totalSupply, totalBorrow, fee)
        market[id].lastUpdate = uint128(block.timestamp);
        idToMarketParams[id] = marketParams;

        emit EventsLib.CreateMarket(id, marketParams);

        // EXTERNAL: Initialize stateful IRMs (e.g., adaptive rate models)
        // NOTE: irm == address(0) is valid (0% APR market)
        if (marketParams.irm != address(0)) IIrm(marketParams.irm).borrowRate(marketParams, market[id]);
    }

    /* SUPPLY MANAGEMENT */

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Permissionless - anyone can supply on behalf of any address (no authorization needed).
    /// @dev SECURITY: Callback executes BEFORE token transfer but AFTER state update (CEI pattern).
    /// @dev MATH: shares = assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS), rounded DOWN.
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        // BOUNDS: Market must exist (lastUpdate > 0 means market was created)
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Exactly one of assets/shares must be 0 - prevents ambiguous input
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        // STATE: Accrue interest first to ensure accurate share pricing
        _accrueInterest(marketParams, id);

        // MATH: Convert between assets and shares
        // ROUNDING: assets→shares rounds DOWN (protocol gets slightly more value per share)
        // ROUNDING: shares→assets rounds UP (user pays slightly more for exact shares)
        if (assets > 0) shares = assets.toSharesDown(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        else assets = shares.toAssetsUp(market[id].totalSupplyAssets, market[id].totalSupplyShares);

        // STATE: Update position and market totals
        // BOUNDS: toUint128() reverts if value > type(uint128).max (~3.4e38)
        position[id][onBehalf].supplyShares += shares;
        market[id].totalSupplyShares += shares.toUint128();
        market[id].totalSupplyAssets += assets.toUint128();

        emit EventsLib.Supply(id, msg.sender, onBehalf, assets, shares);

        // SECURITY: Callback AFTER state update - caller can use callback to source funds (flash pattern)
        if (data.length > 0) IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data);

        // EXTERNAL: Token transfer last - if callback reverts or user lacks tokens, all changes revert
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets);

        return (assets, shares);
    }

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Requires authorization - msg.sender must be onBehalf OR authorized by onBehalf.
    /// @dev MATH: shares = assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS), rounded UP.
    /// @dev INVARIANT: After withdrawal, totalBorrowAssets <= totalSupplyAssets must hold.
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // SECURITY: Authorization check implicitly validates onBehalf != address(0)
        // (address(0) cannot authorize anyone, and msg.sender != address(0))
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _accrueInterest(marketParams, id);

        // ROUNDING: assets→shares rounds UP (user burns more shares for exact assets)
        // ROUNDING: shares→assets rounds DOWN (user gets fewer assets for exact shares)
        if (assets > 0) shares = assets.toSharesUp(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        else assets = shares.toAssetsDown(market[id].totalSupplyAssets, market[id].totalSupplyShares);

        // STATE: Decrease position and market totals
        // NOTE: Will underflow and revert if user lacks sufficient shares
        position[id][onBehalf].supplyShares -= shares;
        market[id].totalSupplyShares -= shares.toUint128();
        market[id].totalSupplyAssets -= assets.toUint128();

        // INVARIANT: Liquidity check - cannot withdraw if it would leave borrows undercollateralized
        require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY);

        emit EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares);

        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        return (assets, shares);
    }

    /* BORROW MANAGEMENT */

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Requires authorization AND health check. Position must remain healthy after borrow.
    /// @dev EXTERNAL: Calls oracle.price() via _isHealthy() - oracle manipulation risk.
    /// @dev INVARIANT: collateral * price * lltv >= borrowed (health) AND totalBorrow <= totalSupply (liquidity).
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // SECURITY: Authorization required to borrow against another's collateral
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _accrueInterest(marketParams, id);

        // ROUNDING: assets→shares rounds UP (borrower owes more shares)
        // ROUNDING: shares→assets rounds DOWN (borrower gets fewer assets for exact shares)
        if (assets > 0) shares = assets.toSharesUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
        else assets = shares.toAssetsDown(market[id].totalBorrowAssets, market[id].totalBorrowShares);

        // STATE: Increase debt position and market totals
        position[id][onBehalf].borrowShares += shares.toUint128();
        market[id].totalBorrowShares += shares.toUint128();
        market[id].totalBorrowAssets += assets.toUint128();

        // SECURITY: Health check AFTER state update - calls oracle externally
        // MATH: maxBorrow = collateral * price / 1e36 * lltv; require(maxBorrow >= borrowed)
        require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL);
        // INVARIANT: Cannot borrow more than total supply
        require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY);

        emit EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares);

        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        return (assets, shares);
    }

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Permissionless - anyone can repay on behalf of any borrower.
    /// @dev MATH: shares = assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS), rounded DOWN.
    /// @dev EDGE CASE: assets may exceed totalBorrowAssets by 1 due to rounding - handled by zeroFloorSub.
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        _accrueInterest(marketParams, id);

        // ROUNDING: assets→shares rounds DOWN (borrower repays fewer shares, owes slightly more later)
        // ROUNDING: shares→assets rounds UP (borrower pays more assets for exact shares)
        if (assets > 0) shares = assets.toSharesDown(market[id].totalBorrowAssets, market[id].totalBorrowShares);
        else assets = shares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);

        // STATE: Reduce debt
        position[id][onBehalf].borrowShares -= shares.toUint128();
        market[id].totalBorrowShares -= shares.toUint128();
        // EDGE CASE: zeroFloorSub handles assets > totalBorrowAssets (possible by 1 due to rounding)
        market[id].totalBorrowAssets = UtilsLib.zeroFloorSub(market[id].totalBorrowAssets, assets).toUint128();

        // NOTE: assets may be 1 greater than actual debt due to rounding
        emit EventsLib.Repay(id, msg.sender, onBehalf, assets, shares);

        // SECURITY: Callback BEFORE token transfer but AFTER state update
        if (data.length > 0) IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data);

        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets);

        return (assets, shares);
    }

    /* COLLATERAL MANAGEMENT */

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Permissionless - anyone can supply collateral for any address.
    /// @dev OPTIMIZATION: Does NOT accrue interest - not required for collateral deposits (saves gas).
    /// @dev NOTE: Collateral tracked as raw assets (uint128), not shares.
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external
    {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        // OPTIMIZATION: No interest accrual needed for collateral operations
        // (collateral doesn't earn interest, health check not needed on deposit)

        // STATE: Increase collateral balance
        // BOUNDS: toUint128 reverts if assets > type(uint128).max
        position[id][onBehalf].collateral += assets.toUint128();

        emit EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets);

        // SECURITY: Callback AFTER state update
        if (data.length > 0) IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data);

        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Requires authorization. Position must remain healthy after withdrawal.
    /// @dev EXTERNAL: Calls oracle.price() via _isHealthy() for health check.
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external
    {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // SECURITY: Must be authorized to withdraw another's collateral
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        // STATE: Must accrue interest for accurate health calculation
        _accrueInterest(marketParams, id);

        // STATE: Decrease collateral
        position[id][onBehalf].collateral -= assets.toUint128();

        // SECURITY: Health check AFTER collateral reduction - calls oracle externally
        require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL);

        emit EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets);

        IERC20(marketParams.collateralToken).safeTransfer(receiver, assets);
    }

    /* LIQUIDATION */

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Permissionless - anyone can liquidate unhealthy positions. Incentive-based mechanism.
    /// @dev MATH: liquidationIncentiveFactor = min(1.15, 1/(1 - 0.3*(1-lltv))). Max 15% bonus for liquidator.
    /// @dev EXTERNAL: Calls oracle.price() - price manipulation could enable unfair liquidations.
    /// @dev BAD DEBT: If collateral == 0 after seizure, remaining debt is socialized to suppliers.
    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.INCONSISTENT_INPUT);

        _accrueInterest(marketParams, id);

        {
            // EXTERNAL: Oracle call - trust assumption on price accuracy
            uint256 collateralPrice = IOracle(marketParams.oracle).price();

            // SECURITY: Position must be UNHEALTHY (collateral * price * lltv < borrowed)
            require(!_isHealthy(marketParams, id, borrower, collateralPrice), ErrorsLib.HEALTHY_POSITION);

            // MATH: Liquidation incentive factor (LIF) calculation
            // Formula: LIF = min(1.15, 1/(1 - 0.3*(1-lltv)))
            // At LLTV=0.8: LIF = 1/(1-0.3*0.2) = 1/0.94 ≈ 1.064 (6.4% bonus)
            // At LLTV=0.5: LIF = 1/(1-0.3*0.5) = 1/0.85 ≈ 1.176 → capped at 1.15 (15% bonus)
            uint256 liquidationIncentiveFactor = UtilsLib.min(
                MAX_LIQUIDATION_INCENTIVE_FACTOR,
                WAD.wDivDown(WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParams.lltv))
            );

            // MATH: Calculate seized collateral OR repaid shares based on input
            if (seizedAssets > 0) {
                // Given seizedAssets → calculate repaidShares
                // seizedAssetsQuoted = seizedAssets * price / 1e36 (in loan token terms)
                // repaidShares = (seizedAssetsQuoted / LIF) converted to shares
                uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

                repaidShares = seizedAssetsQuoted.wDivUp(liquidationIncentiveFactor)
                    .toSharesUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
            } else {
                // Given repaidShares → calculate seizedAssets
                // seizedAssets = repaidAssets * LIF * 1e36 / price (in collateral token terms)
                seizedAssets = repaidShares.toAssetsDown(market[id].totalBorrowAssets, market[id].totalBorrowShares)
                    .wMulDown(liquidationIncentiveFactor).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
            }
        }
        // MATH: repaidAssets rounds UP - liquidator pays slightly more (protocol favored)
        uint256 repaidAssets = repaidShares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);

        // STATE: Reduce borrower's debt
        position[id][borrower].borrowShares -= repaidShares.toUint128();
        market[id].totalBorrowShares -= repaidShares.toUint128();
        // NOTE: zeroFloorSub handles edge case where repaidAssets > totalBorrowAssets (by 1 due to rounding)
        market[id].totalBorrowAssets = UtilsLib.zeroFloorSub(market[id].totalBorrowAssets, repaidAssets).toUint128();

        // STATE: Seize collateral from borrower
        position[id][borrower].collateral -= seizedAssets.toUint128();

        // BAD DEBT HANDLING: If no collateral remains but debt exists, socialize the loss
        uint256 badDebtShares;
        uint256 badDebtAssets;
        if (position[id][borrower].collateral == 0) {
            // All remaining debt becomes bad debt
            badDebtShares = position[id][borrower].borrowShares;
            badDebtAssets = UtilsLib.min(
                market[id].totalBorrowAssets,
                badDebtShares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares)
            );

            // SOCIALIZATION: Reduce totalSupplyAssets - suppliers absorb the loss
            market[id].totalBorrowAssets -= badDebtAssets.toUint128();
            market[id].totalSupplyAssets -= badDebtAssets.toUint128();
            market[id].totalBorrowShares -= badDebtShares.toUint128();
            position[id][borrower].borrowShares = 0;
        }

        // NOTE: repaidAssets may exceed totalBorrowAssets by 1 due to rounding
        emit EventsLib.Liquidate(
            id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares
        );

        // SECURITY: Collateral transfer BEFORE callback (liquidator receives collateral first)
        IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets);

        // SECURITY: Callback after state update and collateral transfer
        if (data.length > 0) IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data);

        // EXTERNAL: Liquidator repays the debt
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);

        return (seizedAssets, repaidAssets);
    }

    /* FLASH LOANS */

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: No fee charged. Access to ALL contract tokens (all markets + donations).
    /// @dev SECURITY: Callback is REQUIRED - caller must implement IMorphoFlashLoanCallback.
    /// @dev STATE: No state changes - tokens must be returned in same transaction.
    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        require(assets != 0, ErrorsLib.ZERO_ASSETS);

        emit EventsLib.FlashLoan(msg.sender, token, assets);

        // EXTERNAL: Send tokens to caller (any token held by contract, not just market tokens)
        IERC20(token).safeTransfer(msg.sender, assets);

        // CALLBACK: Caller executes their logic (arbitrage, liquidation, etc.)
        // SECURITY: If callback reverts, entire tx reverts - tokens are safe
        IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data);

        // EXTERNAL: Caller must return exact amount (no fee)
        // SECURITY: If caller doesn't have/approve tokens, this reverts
        IERC20(token).safeTransferFrom(msg.sender, address(this), assets);
    }

    /* AUTHORIZATION */

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: Authorizing an address allows them to withdraw/borrow from your positions.
    /// @dev SECURITY: Can be revoked anytime by calling with newIsAuthorized=false.
    function setAuthorization(address authorized, bool newIsAuthorized) external {
        require(newIsAuthorized != isAuthorized[msg.sender][authorized], ErrorsLib.ALREADY_SET);

        isAuthorized[msg.sender][authorized] = newIsAuthorized;

        emit EventsLib.SetAuthorization(msg.sender, msg.sender, authorized, newIsAuthorized);
    }

    /// @inheritdoc IMorphoBase
    /// @dev SECURITY: EIP-712 signature-based authorization. Nonce prevents replay attacks.
    /// @dev SECURITY: Deadline provides time-limited authorization windows.
    /// @dev NOTE: Signature is malleable but has no security impact (same authorization result).
    function setAuthorizationWithSig(Authorization memory authorization, Signature calldata signature) external {
        // NOTE: Don't check if already set - nonce increment is desired side effect
        // (allows revoking via signature even if already set to same value)
        require(block.timestamp <= authorization.deadline, ErrorsLib.SIGNATURE_EXPIRED);
        // SECURITY: Nonce must match AND increments - prevents replay attacks
        require(authorization.nonce == nonce[authorization.authorizer]++, ErrorsLib.INVALID_NONCE);

        // EIP-712: Compute digest for signature verification
        bytes32 hashStruct = keccak256(abi.encode(AUTHORIZATION_TYPEHASH, authorization));
        bytes32 digest = keccak256(bytes.concat("\x19\x01", DOMAIN_SEPARATOR, hashStruct));
        address signatory = ecrecover(digest, signature.v, signature.r, signature.s);

        // SECURITY: Verify signature is valid and matches authorizer
        require(signatory != address(0) && authorization.authorizer == signatory, ErrorsLib.INVALID_SIGNATURE);

        emit EventsLib.IncrementNonce(msg.sender, authorization.authorizer, authorization.nonce);

        isAuthorized[authorization.authorizer][authorization.authorized] = authorization.isAuthorized;

        emit EventsLib.SetAuthorization(
            msg.sender, authorization.authorizer, authorization.authorized, authorization.isAuthorized
        );
    }

    /// @dev Returns whether the sender is authorized to manage `onBehalf`'s positions.
    /// @dev SECURITY: Self-authorization (msg.sender == onBehalf) always allowed.
    function _isSenderAuthorized(address onBehalf) internal view returns (bool) {
        return msg.sender == onBehalf || isAuthorized[onBehalf][msg.sender];
    }

    /* INTEREST MANAGEMENT */

    /// @inheritdoc IMorphoBase
    function accrueInterest(MarketParams memory marketParams) external {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);

        _accrueInterest(marketParams, id);
    }

    /// @dev Accrues interest for the given market `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    /// @dev MATH: Uses Taylor expansion e^(r*t) - 1 ≈ rt + (rt)²/2 + (rt)³/6 for continuous compounding.
    /// @dev EXTERNAL: Calls IRM.borrowRate() - if IRM reverts, accrual fails.
    function _accrueInterest(MarketParams memory marketParams, Id id) internal {
        uint256 elapsed = block.timestamp - market[id].lastUpdate;
        // OPTIMIZATION: Skip if same block (no time elapsed = no interest)
        if (elapsed == 0) return;

        // IRM == address(0) means no interest accrual (e.g., 0% APR markets)
        if (marketParams.irm != address(0)) {
            // EXTERNAL: Get borrow rate from IRM (rate per second, scaled by 1e18)
            // TRUST: IRM must return reasonable rate. Extreme rates could cause overflow.
            uint256 borrowRate = IIrm(marketParams.irm).borrowRate(marketParams, market[id]);

            // MATH: interest = totalBorrowAssets * (e^(rate * elapsed) - 1)
            // Taylor expansion: e^x - 1 ≈ x + x²/2 + x³/6 (accurate for small x)
            // wTaylorCompounded(rate, elapsed) returns the multiplier
            uint256 interest = market[id].totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));

            // STATE: Interest increases both borrow AND supply assets equally
            // Borrowers owe more, suppliers are entitled to more
            market[id].totalBorrowAssets += interest.toUint128();
            market[id].totalSupplyAssets += interest.toUint128();

            // FEE HANDLING: Protocol takes a cut of interest as supply shares
            uint256 feeShares;
            if (market[id].fee != 0) {
                // feeAmount = interest * fee (e.g., 10% of 100 interest = 10)
                uint256 feeAmount = interest.wMulDown(market[id].fee);

                // MATH: Convert fee to shares. Subtract feeAmount from totalSupply because
                // totalSupply already includes the full interest. We want shares representing
                // feeAmount out of (totalSupply - feeAmount), not out of totalSupply.
                feeShares =
                    feeAmount.toSharesDown(market[id].totalSupplyAssets - feeAmount, market[id].totalSupplyShares);

                // STATE: Mint fee shares to feeRecipient (silent - no Supply event)
                position[id][feeRecipient].supplyShares += feeShares;
                market[id].totalSupplyShares += feeShares.toUint128();
            }

            emit EventsLib.AccrueInterest(id, borrowRate, interest, feeShares);
        }

        // STATE: Update timestamp (always, even if IRM is address(0))
        // BOUNDS: block.timestamp fits in uint128 until year ~10^31
        market[id].lastUpdate = uint128(block.timestamp);
    }

    /* HEALTH CHECK */

    /// @dev Returns whether the position of `borrower` in the given market `marketParams` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    /// @dev EXTERNAL: Calls oracle.price() - single point of failure for health checks.
    function _isHealthy(MarketParams memory marketParams, Id id, address borrower) internal view returns (bool) {
        // OPTIMIZATION: No debt = always healthy (skip oracle call)
        if (position[id][borrower].borrowShares == 0) return true;

        // EXTERNAL: Oracle price call - manipulation risk
        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        return _isHealthy(marketParams, id, borrower, collateralPrice);
    }

    /// @dev Returns whether the position of `borrower` in the given market `marketParams` with the given
    /// `collateralPrice` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    /// @dev Rounds in favor of the protocol, so one might not be able to borrow exactly `maxBorrow` but one unit less.
    /// @dev MATH: healthy = (collateral * price / 1e36 * lltv) >= borrowed
    function _isHealthy(MarketParams memory marketParams, Id id, address borrower, uint256 collateralPrice)
        internal
        view
        returns (bool)
    {
        // MATH: Calculate borrowed assets from shares
        // ROUNDING: toAssetsUp rounds UP - borrower appears to owe MORE (protocol favored)
        uint256 borrowed = uint256(position[id][borrower].borrowShares)
            .toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);

        // MATH: Calculate maximum borrow capacity
        // maxBorrow = collateral * price / ORACLE_PRICE_SCALE * lltv
        // ROUNDING: mulDivDown and wMulDown both round DOWN - borrower can borrow LESS (protocol favored)
        // Example: collateral=100, price=2e36, lltv=0.8e18 → maxBorrow = 100 * 2 * 0.8 = 160
        uint256 maxBorrow = uint256(position[id][borrower].collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);

        // INVARIANT: Position is healthy if maxBorrow >= borrowed
        return maxBorrow >= borrowed;
    }

    /* STORAGE VIEW */

    /// @inheritdoc IMorphoBase
    function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res) {
        uint256 nSlots = slots.length;

        res = new bytes32[](nSlots);

        for (uint256 i; i < nSlots;) {
            bytes32 slot = slots[i++];

            assembly ("memory-safe") {
                mstore(add(res, mul(i, 32)), sload(slot))
            }
        }
    }
}

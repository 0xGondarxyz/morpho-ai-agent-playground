// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

// --- IMPORTS ---
// Core interfaces for type definitions and callback patterns
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

// Libraries for math, safety, and utility functions
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
// --- CONTRACT OVERVIEW ---
// ARCHITECTURE: Singleton contract managing isolated lending markets.
//   - Each market identified by keccak256(MarketParams) containing (loanToken, collateralToken, oracle, irm, lltv)
//   - Markets are independent - no cross-collateralization between markets
//   - Permissionless market creation with owner-whitelisted IRMs and LLTVs
//
// SECURITY: Uses CEI (Checks-Effects-Interactions) pattern throughout
//   - All state updates occur BEFORE external calls
//   - Callbacks execute AFTER state is finalized but BEFORE token transfers
//   - Reentrancy safety via state-first pattern, not locks
//
// BOUNDS: Overflow protection via constrained types
//   - All market totals use uint128 (max ~3.4e38)
//   - Virtual shares (1e6) + virtual assets (1) prevent share inflation attacks
//   - toUint128() reverts on overflow
//
// MATH: All conversions round in protocol's favor
//   - Supply: assets->shares DOWN, shares->assets UP (user pays more)
//   - Withdraw: assets->shares UP, shares->assets DOWN (user gets less)
//   - Borrow: assets->shares UP, shares->assets DOWN (borrower owes more, gets less)
//   - Repay: assets->shares DOWN, shares->assets UP (borrower repays less shares)
//   - Health: borrowed UP, maxBorrow DOWN (harder to pass health check)
contract Morpho is IMorphoStaticTyping {
    // --- LIBRARY BINDINGS ---
    // MATH: MathLib provides WAD-scaled arithmetic (1e18 precision)
    using MathLib for uint128;
    using MathLib for uint256;
    // BOUNDS: UtilsLib provides toUint128() with overflow checks and zeroFloorSub()
    using UtilsLib for uint256;
    // MATH: SharesMathLib provides share<->asset conversions with virtual shares/assets
    using SharesMathLib for uint256;
    // SECURITY: SafeTransferLib handles non-standard ERC20 tokens (no return value, etc.)
    using SafeTransferLib for IERC20;
    // MATH: MarketParamsLib computes market ID = keccak256(abi.encode(marketParams))
    using MarketParamsLib for MarketParams;

    /* IMMUTABLES */

    /// @inheritdoc IMorphoBase
    // SECURITY: EIP-712 domain separator - chain-specific to prevent cross-chain replay attacks
    // MATH: DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, chainId, address(this)))
    bytes32 public immutable DOMAIN_SEPARATOR;

    /* STORAGE */
    // --- STORAGE LAYOUT ---
    // BOUNDS: Slots 0-8 used. See MorphoStorageLib for exact slot positions.
    // WARNING: position/market mappings store STALE values - call accrueInterest() for current state.
    // STATE: All position and market data may be outdated by accumulated interest since lastUpdate.

    /// @inheritdoc IMorphoBase
    // SECURITY: Owner can enable IRMs/LLTVs, set fees. Single admin - no timelock.
    // WARNING: No two-step transfer, can be set to zero address (disabling admin forever).
    address public owner;

    /// @inheritdoc IMorphoBase
    // STATE: Receives supply shares representing protocol fees.
    // WARNING: If set to address(0), fees are lost (shares still minted but inaccessible).
    address public feeRecipient;

    /// @inheritdoc IMorphoStaticTyping
    // STATE: Per-user position in each market.
    //   - supplyShares (uint256): User's claim on supplied assets
    //   - borrowShares (uint128): User's debt obligation
    //   - collateral (uint128): Raw collateral assets deposited
    // BOUNDS: borrowShares and collateral use uint128 (max ~3.4e38)
    mapping(Id => mapping(address => Position)) public position;

    /// @inheritdoc IMorphoStaticTyping
    // STATE: Global market state including totals and configuration.
    //   - totalSupplyAssets/Shares (uint128): Aggregate supply
    //   - totalBorrowAssets/Shares (uint128): Aggregate debt
    //   - lastUpdate (uint128): Timestamp of last interest accrual
    //   - fee (uint128): Protocol fee as WAD fraction of interest
    // BOUNDS: All fields uint128, lastUpdate uses block.timestamp
    mapping(Id => Market) public market;

    /// @inheritdoc IMorphoBase
    // SECURITY: Whitelist of enabled Interest Rate Models.
    // WARNING: Once enabled, cannot be disabled. Owner must trust IRM implementation.
    mapping(address => bool) public isIrmEnabled;

    /// @inheritdoc IMorphoBase
    // SECURITY: Whitelist of enabled Loan-to-Value ratios.
    // BOUNDS: Each LLTV must be < WAD (100%). Cannot be disabled once enabled.
    mapping(uint256 => bool) public isLltvEnabled;

    /// @inheritdoc IMorphoBase
    // SECURITY: Authorization mapping for position management.
    // STATE: isAuthorized[owner][manager] = true allows manager to withdraw/borrow from owner's positions.
    mapping(address => mapping(address => bool)) public isAuthorized;

    /// @inheritdoc IMorphoBase
    // SECURITY: Nonces for EIP-712 signature replay protection.
    // STATE: Increments on each setAuthorizationWithSig call. Each nonce usable exactly once.
    mapping(address => uint256) public nonce;

    /// @inheritdoc IMorphoStaticTyping
    // STATE: Reverse lookup from market ID to MarketParams.
    // Populated on market creation. Immutable per market (market cannot be recreated).
    mapping(Id => MarketParams) public idToMarketParams;

    /* CONSTRUCTOR */

    // --- CONSTRUCTOR ---
    // STATE: Initializes owner and computes EIP-712 domain separator.
    // SECURITY: Owner cannot be zero address (would leave contract without admin).
    /// @param newOwner The new owner of the contract.
    constructor(address newOwner) {
        // BOUNDS: Prevent accidental deployment with no owner
        require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS);

        // SECURITY: Domain separator includes chainId to prevent cross-chain replay
        // MATH: DOMAIN_SEPARATOR = keccak256(DOMAIN_TYPEHASH || chainId || contractAddress)
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)));
        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    /* MODIFIERS */

    // --- ACCESS CONTROL ---
    // SECURITY: Restricts administrative functions to contract owner.
    /// @dev Reverts if the caller is not the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, ErrorsLib.NOT_OWNER);
        _;
    }

    /* ONLY OWNER FUNCTIONS */

    // --- OWNER FUNCTIONS: setOwner ---
    // STATE: Transfers contract ownership to new address.
    // SECURITY: No two-step transfer - immediate and irreversible.
    // WARNING: Can set owner to address(0), permanently disabling admin functions.
    /// @inheritdoc IMorphoBase
    function setOwner(address newOwner) external onlyOwner {
        // BOUNDS: Prevent no-op state change
        require(newOwner != owner, ErrorsLib.ALREADY_SET);

        // STATE: Immediate ownership transfer
        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    // --- OWNER FUNCTIONS: enableIrm ---
    // STATE: Whitelists an Interest Rate Model for market creation.
    // SECURITY: Once enabled, CANNOT be disabled. Owner must trust IRM code.
    // NOTE: address(0) is a valid IRM (creates 0% APR markets).
    /// @inheritdoc IMorphoBase
    function enableIrm(address irm) external onlyOwner {
        // BOUNDS: Prevent re-enabling already enabled IRM
        require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET);

        // STATE: Permanently enable IRM
        isIrmEnabled[irm] = true;

        emit EventsLib.EnableIrm(irm);
    }

    // --- OWNER FUNCTIONS: enableLltv ---
    // STATE: Whitelists a Loan-to-Value ratio for market creation.
    // BOUNDS: lltv must be < WAD (1e18 = 100%). Common values: 0.8e18 (80%), 0.9e18 (90%).
    // SECURITY: Higher LLTV = more leverage = higher liquidation risk.
    // WARNING: Cannot be disabled once enabled.
    /// @inheritdoc IMorphoBase
    function enableLltv(uint256 lltv) external onlyOwner {
        // BOUNDS: Prevent re-enabling already enabled LLTV
        require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET);
        // BOUNDS: LLTV >= 100% would allow infinite borrowing against collateral
        // MATH: At LLTV=100%, collateral*price*1.0 >= borrowed, so any collateral allows infinite borrow
        require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED);

        // STATE: Permanently enable LLTV
        isLltvEnabled[lltv] = true;

        emit EventsLib.EnableLltv(lltv);
    }

    // --- OWNER FUNCTIONS: setFee ---
    // STATE: Sets protocol fee for a market. Fee is percentage of interest accrued.
    // BOUNDS: newFee must be <= MAX_FEE (0.25e18 = 25%).
    // MATH: Fee = interest * fee / WAD. At 25% fee and 100 interest, protocol gets 25.
    // STATE: Accrues interest with OLD fee before applying new fee (fair accounting).
    /// @inheritdoc IMorphoBase
    function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner {
        Id id = marketParams.id();
        // BOUNDS: Market must exist (lastUpdate > 0 indicates creation)
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Prevent no-op state change
        require(newFee != market[id].fee, ErrorsLib.ALREADY_SET);
        // BOUNDS: Protocol fee capped at 25% of interest to prevent excessive extraction
        require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED);

        // STATE: Accrue with OLD fee first - interest earned before change uses old rate
        // This ensures fair accounting: past interest uses past fee, future uses new fee
        _accrueInterest(marketParams, id);

        // STATE: Update fee for future interest accruals
        // BOUNDS: newFee <= MAX_FEE (0.25e18) fits safely in uint128 (max ~3.4e38)
        market[id].fee = uint128(newFee);

        emit EventsLib.SetFee(id, newFee);
    }

    // --- OWNER FUNCTIONS: setFeeRecipient ---
    // STATE: Sets address that receives protocol fee shares.
    // WARNING: If set to address(0), fees are LOST (shares minted to zero address).
    // NOTE: Changing recipient allows new recipient to claim any not-yet-accrued fees.
    /// @inheritdoc IMorphoBase
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        // BOUNDS: Prevent no-op state change
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);

        // STATE: Update fee recipient - no validation on address
        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /* MARKET CREATION */

    // --- MARKET CREATION ---
    // STATE: Creates a new isolated lending market with specified parameters.
    // SECURITY: Permissionless - anyone can create markets using owner-whitelisted IRM and LLTV.
    // MATH: Market ID = keccak256(abi.encode(loanToken, collateralToken, oracle, irm, lltv)).
    //       Same parameters always produce same ID - deterministic and collision-resistant.
    // EXTERNAL: Calls IRM.borrowRate() to initialize stateful IRMs (e.g., adaptive rate models).
    /// @inheritdoc IMorphoBase
    function createMarket(MarketParams memory marketParams) external {
        // MATH: Compute deterministic market ID from all parameters
        // This ensures each unique market configuration has a unique ID
        Id id = marketParams.id();

        // SECURITY: Only owner-whitelisted IRMs and LLTVs can be used
        // This prevents malicious/untested IRMs and dangerous LLTVs
        require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED);
        require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED);

        // SECURITY: Cannot recreate existing market (lastUpdate > 0 indicates market exists)
        // Markets are immutable once created - parameters cannot change
        require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED);

        // STATE: Initialize market with current timestamp
        // BOUNDS: block.timestamp fits in uint128 until year ~10^31
        // NOTE: All other market fields (totalSupply, totalBorrow, fee) initialize to 0
        market[id].lastUpdate = uint128(block.timestamp);
        // STATE: Store params for reverse lookup (useful for periphery contracts)
        idToMarketParams[id] = marketParams;

        emit EventsLib.CreateMarket(id, marketParams);

        // EXTERNAL: Initialize stateful IRMs (e.g., adaptive rate models that track utilization history)
        // SECURITY: IRM call is read-only conceptually, but stateful IRMs may update internal state
        // NOTE: irm == address(0) is valid - creates 0% APR market (no IRM call needed)
        if (marketParams.irm != address(0)) IIrm(marketParams.irm).borrowRate(marketParams, market[id]);
    }

    /* SUPPLY MANAGEMENT */

    // --- SUPPLY FUNCTION ---
    // STATE: Deposits loan tokens into market, crediting supply shares to onBehalf.
    // SECURITY: Permissionless - anyone can supply on behalf of any address (no authorization needed).
    //           This is safe because supplying only benefits the recipient.
    // SECURITY: Callback executes AFTER state update but BEFORE token transfer (CEI pattern).
    //           Caller can use callback to source funds (flash-mint pattern).
    // MATH: shares = assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS)
    //       Virtual shares (1e6) and virtual assets (1) prevent share inflation attacks.
    // MATH: Rounding - assets to shares rounds DOWN (protocol favored).
    /// @inheritdoc IMorphoBase
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        // BOUNDS: Market must exist (lastUpdate > 0 indicates market was created)
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Exactly one of assets/shares must be 0 - prevents ambiguous input
        // User specifies EITHER how many assets to supply OR how many shares to receive
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        // BOUNDS: Cannot credit shares to zero address
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        // STATE: Accrue interest first to ensure accurate share pricing
        // Interest must be up-to-date before computing share conversion
        _accrueInterest(marketParams, id);

        // MATH: Convert between assets and shares based on current exchange rate
        // sharePrice = (totalAssets + 1) / (totalShares + 1e6) [with rounding]
        if (assets > 0) {
            // MATH: assets → shares, rounds DOWN
            // User receives fewer shares (protocol gets slightly more value per share)
            shares = assets.toSharesDown(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        } else {
            // MATH: shares → assets, rounds UP
            // User pays slightly more assets to receive exact shares requested
            assets = shares.toAssetsUp(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        }

        // STATE: Update position and market totals
        // BOUNDS: toUint128() reverts if value > type(uint128).max (~3.4e38)
        // NOTE: supplyShares is uint256, so no overflow check needed for addition
        position[id][onBehalf].supplyShares += shares;
        market[id].totalSupplyShares += shares.toUint128();
        market[id].totalSupplyAssets += assets.toUint128();

        emit EventsLib.Supply(id, msg.sender, onBehalf, assets, shares);

        // SECURITY: Callback AFTER state update (CEI pattern)
        // Caller can use callback to source funds (e.g., flash loan to get tokens)
        // If callback reverts, entire transaction reverts and state changes are undone
        if (data.length > 0) IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data);

        // EXTERNAL: Token transfer last - completes CEI pattern
        // If user lacks tokens or approval, transfer fails and all changes revert
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets);

        return (assets, shares);
    }

    // --- WITHDRAW FUNCTION ---
    // STATE: Burns supply shares and withdraws loan tokens from market.
    // SECURITY: Requires authorization - msg.sender must be onBehalf OR authorized by onBehalf.
    //           This prevents unauthorized withdrawal from other users' positions.
    // MATH: shares = assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS), rounded UP.
    // MATH: Rounding - assets to shares rounds UP (user burns more), shares to assets rounds DOWN (user gets less).
    // INVARIANT: After withdrawal, totalBorrowAssets <= totalSupplyAssets must hold (liquidity constraint).
    /// @inheritdoc IMorphoBase
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        // BOUNDS: Market must exist
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Exactly one of assets/shares must be 0
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        // BOUNDS: Cannot send tokens to zero address
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // SECURITY: Authorization check - msg.sender must be onBehalf or authorized
        // NOTE: Implicitly validates onBehalf != address(0) because address(0) cannot authorize anyone
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        // STATE: Accrue interest for accurate share pricing
        _accrueInterest(marketParams, id);

        // MATH: Convert between assets and shares based on current exchange rate
        if (assets > 0) {
            // MATH: assets → shares, rounds UP
            // User burns MORE shares to withdraw exact assets (protocol favored)
            shares = assets.toSharesUp(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        } else {
            // MATH: shares → assets, rounds DOWN
            // User gets FEWER assets for exact shares burned (protocol favored)
            assets = shares.toAssetsDown(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        }

        // STATE: Decrease position and market totals
        // SECURITY: Underflow reverts if user lacks sufficient shares (built-in access control)
        position[id][onBehalf].supplyShares -= shares;
        market[id].totalSupplyShares -= shares.toUint128();
        market[id].totalSupplyAssets -= assets.toUint128();

        // INVARIANT: Liquidity check - ensure borrowers remain fully backed
        // Without this, withdrawals could leave borrowers with unbacked debt
        require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY);

        emit EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares);

        // EXTERNAL: Token transfer - state already updated (CEI pattern)
        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        return (assets, shares);
    }

    /* BORROW MANAGEMENT */

    // --- BORROW FUNCTION ---
    // STATE: Creates debt position by minting borrow shares and transferring loan tokens.
    // SECURITY: Requires authorization AND health check. Position must remain healthy after borrow.
    //           Authorization prevents borrowing against others' collateral without permission.
    // EXTERNAL: Calls oracle.price() via _isHealthy() - oracle manipulation is a trust assumption.
    //           Malicious oracle could allow under-collateralized borrows or block legitimate ones.
    // INVARIANT: Two invariants must hold:
    //   1. Health: collateral * price * lltv >= borrowed (position remains collateralized)
    //   2. Liquidity: totalBorrow <= totalSupply (borrowers can't exceed available funds)
    // MATH: Rounding - assets to shares rounds UP (borrower owes more), shares to assets rounds DOWN.
    /// @inheritdoc IMorphoBase
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        // BOUNDS: Market must exist
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Exactly one of assets/shares must be 0
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        // BOUNDS: Cannot send tokens to zero address
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // SECURITY: Authorization required - only position owner or authorized managers can borrow
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        // STATE: Accrue interest for accurate debt calculation
        _accrueInterest(marketParams, id);

        // MATH: Convert between assets and shares based on current borrow rate
        if (assets > 0) {
            // MATH: assets → shares, rounds UP
            // Borrower owes MORE shares for requested assets (protocol favored)
            shares = assets.toSharesUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
        } else {
            // MATH: shares → assets, rounds DOWN
            // Borrower gets FEWER assets for specified shares (protocol favored)
            assets = shares.toAssetsDown(market[id].totalBorrowAssets, market[id].totalBorrowShares);
        }

        // STATE: Increase debt position and market totals
        // BOUNDS: toUint128() reverts on overflow - borrow shares stored as uint128
        position[id][onBehalf].borrowShares += shares.toUint128();
        market[id].totalBorrowShares += shares.toUint128();
        market[id].totalBorrowAssets += assets.toUint128();

        // SECURITY: Health check AFTER state update (check-effects-interactions)
        // MATH: maxBorrow = collateral * price / ORACLE_PRICE_SCALE * lltv
        // EXTERNAL: Calls oracle.price() - trust assumption on oracle integrity
        require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL);

        // INVARIANT: Global liquidity constraint - can't borrow more than supplied
        require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY);

        emit EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares);

        // EXTERNAL: Token transfer - state and checks complete (CEI pattern)
        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        return (assets, shares);
    }

    // --- REPAY FUNCTION ---
    // STATE: Repays borrowed tokens, reducing debt position and market totals.
    // SECURITY: Permissionless - anyone can repay on behalf of any borrower (benefits borrower).
    //           No authorization needed because repaying only helps the position.
    // SECURITY: Callback executes AFTER state update but BEFORE token transfer (CEI pattern).
    // MATH: shares = assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS), rounded DOWN.
    // MATH: Rounding - assets to shares rounds DOWN (borrower repays fewer shares - mildly borrower favored).
    //       This slight rounding benefit is negligible and outweighed by other protocol-favoring rounds.
    // EDGE CASE: assets may exceed totalBorrowAssets by 1 due to rounding - handled by zeroFloorSub.
    /// @inheritdoc IMorphoBase
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        // BOUNDS: Market must exist
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Exactly one of assets/shares must be 0
        require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
        // BOUNDS: Cannot repay for zero address (would be pointless)
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        // STATE: Accrue interest for accurate debt calculation
        _accrueInterest(marketParams, id);

        // MATH: Convert between assets and shares based on current debt exchange rate
        if (assets > 0) {
            // MATH: assets → shares, rounds DOWN
            // Borrower repays fewer shares (slightly borrower-favored, but minimal impact)
            shares = assets.toSharesDown(market[id].totalBorrowAssets, market[id].totalBorrowShares);
        } else {
            // MATH: shares → assets, rounds UP
            // Borrower pays more assets for exact shares (protocol favored)
            assets = shares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
        }

        // STATE: Reduce debt position and market totals
        // SECURITY: Underflow reverts if trying to repay more shares than owed
        position[id][onBehalf].borrowShares -= shares.toUint128();
        market[id].totalBorrowShares -= shares.toUint128();
        // EDGE CASE: zeroFloorSub handles assets > totalBorrowAssets
        // This can happen when rounding causes assets to be 1 greater than actual remaining debt
        // Without zeroFloorSub, the subtraction would underflow
        market[id].totalBorrowAssets = UtilsLib.zeroFloorSub(market[id].totalBorrowAssets, assets).toUint128();

        // NOTE: In edge case, assets paid may be 1 greater than mathematical debt
        emit EventsLib.Repay(id, msg.sender, onBehalf, assets, shares);

        // SECURITY: Callback AFTER state update (CEI pattern)
        // Caller can use callback to source repayment funds
        if (data.length > 0) IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data);

        // EXTERNAL: Token transfer last
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets);

        return (assets, shares);
    }

    /* COLLATERAL MANAGEMENT */

    // --- SUPPLY COLLATERAL FUNCTION ---
    // STATE: Deposits collateral tokens to back borrowing positions.
    // SECURITY: Permissionless - anyone can supply collateral for any address (benefits recipient).
    //           No authorization needed because depositing only helps the position.
    // SECURITY: Callback executes AFTER state update but BEFORE token transfer (CEI pattern).
    // OPTIMIZATION: Does NOT accrue interest - collateral doesn't earn interest, so accrual unnecessary.
    //               This saves gas compared to supply/withdraw/borrow functions.
    // NOTE: Collateral tracked as raw assets (uint128), NOT shares.
    //       Unlike supply positions, collateral doesn't accrue value - it's static until withdrawn.
    /// @inheritdoc IMorphoBase
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external
    {
        Id id = marketParams.id();
        // BOUNDS: Market must exist
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Must supply non-zero amount (0 would be wasteful no-op)
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        // BOUNDS: Cannot credit collateral to zero address
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        // OPTIMIZATION: No interest accrual needed
        // Collateral doesn't earn interest, and no health check is needed on deposit
        // (depositing collateral only improves health, never worsens it)

        // STATE: Increase collateral balance
        // BOUNDS: toUint128() reverts if assets > type(uint128).max (~3.4e38)
        position[id][onBehalf].collateral += assets.toUint128();

        emit EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets);

        // SECURITY: Callback AFTER state update (CEI pattern)
        // Caller can use callback to source collateral (flash pattern)
        if (data.length > 0) IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data);

        // EXTERNAL: Token transfer last
        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    // --- WITHDRAW COLLATERAL FUNCTION ---
    // STATE: Withdraws collateral tokens, reducing backing for borrow position.
    // SECURITY: Requires authorization - only position owner or authorized managers can withdraw.
    //           This prevents unauthorized reduction of collateral backing.
    // SECURITY: Position must remain healthy after withdrawal - enforced by _isHealthy check.
    // EXTERNAL: Calls oracle.price() via _isHealthy() - oracle manipulation could block withdrawals.
    // NOTE: Unlike supplyCollateral, this DOES accrue interest because health check needs accurate debt.
    /// @inheritdoc IMorphoBase
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external
    {
        Id id = marketParams.id();
        // BOUNDS: Market must exist
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Must withdraw non-zero amount
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        // BOUNDS: Cannot send tokens to zero address
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // SECURITY: Authorization required to withdraw collateral
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        // STATE: Accrue interest for accurate health calculation
        // Interest accrual updates totalBorrowAssets, affecting the health check
        _accrueInterest(marketParams, id);

        // STATE: Decrease collateral balance
        // SECURITY: Underflow reverts if trying to withdraw more than deposited
        position[id][onBehalf].collateral -= assets.toUint128();

        // SECURITY: Health check AFTER collateral reduction (check-effects-interactions)
        // EXTERNAL: Calls oracle.price() - trust assumption on oracle integrity
        // MATH: Requires collateral * price * lltv >= borrowed (after reduction)
        require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL);

        emit EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets);

        // EXTERNAL: Token transfer last (CEI pattern complete)
        IERC20(marketParams.collateralToken).safeTransfer(receiver, assets);
    }

    /* LIQUIDATION */

    // --- LIQUIDATE FUNCTION ---
    // STATE: Liquidates unhealthy positions by repaying debt and seizing collateral at a discount.
    // SECURITY: Permissionless - anyone can liquidate unhealthy positions. This is by design:
    //           Economic incentive (liquidation bonus) ensures positions are kept healthy.
    // MATH: Liquidation Incentive Factor (LIF) formula:
    //       LIF = min(MAX_LIQUIDATION_INCENTIVE_FACTOR, 1 / (1 - LIQUIDATION_CURSOR * (1 - lltv)))
    //       LIF = min(1.15, 1 / (1 - 0.3 * (1 - lltv)))
    //       At LLTV=0.8: LIF = 1/(1-0.3*0.2) = 1/0.94 ~ 1.064 (6.4% bonus)
    //       At LLTV=0.5: LIF = 1/(1-0.3*0.5) = 1/0.85 ~ 1.176, capped to 1.15 (15% max)
    // EXTERNAL: Calls oracle.price() - price manipulation could enable unfair liquidations.
    // BAD DEBT: If collateral == 0 after seizure, remaining debt is socialized to suppliers.
    //           This is a loss-sharing mechanism - suppliers absorb unrecorverable debt.
    /// @inheritdoc IMorphoBase
    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        // BOUNDS: Market must exist
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        // BOUNDS: Exactly one of seizedAssets/repaidShares must be 0
        // Liquidator specifies EITHER how much collateral to seize OR how much debt to repay
        require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.INCONSISTENT_INPUT);

        // STATE: Accrue interest for accurate debt calculation
        _accrueInterest(marketParams, id);

        {
            // EXTERNAL: Oracle price call - critical trust assumption
            // SECURITY: Oracle manipulation could enable unfair liquidations at wrong prices
            uint256 collateralPrice = IOracle(marketParams.oracle).price();

            // SECURITY: Position must be UNHEALTHY to be liquidated
            // MATH: Unhealthy means collateral * price * lltv < borrowed
            require(!_isHealthy(marketParams, id, borrower, collateralPrice), ErrorsLib.HEALTHY_POSITION);

            // MATH: Calculate Liquidation Incentive Factor (LIF)
            // Formula: LIF = min(1.15, 1/(1 - 0.3*(1-lltv)))
            // The incentive increases as LLTV decreases (more buffer = more bonus)
            // Capped at 15% to prevent excessive liquidator profits
            uint256 liquidationIncentiveFactor = UtilsLib.min(
                MAX_LIQUIDATION_INCENTIVE_FACTOR,
                WAD.wDivDown(WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParams.lltv))
            );

            // MATH: Calculate seized collateral OR repaid shares based on input
            if (seizedAssets > 0) {
                // MATH: Given seizedAssets, calculate repaidShares
                // Step 1: seizedAssetsQuoted = seizedAssets * price / 1e36 (value in loan token terms)
                // Step 2: repaidValue = seizedAssetsQuoted / LIF (apply liquidation discount)
                // Step 3: repaidShares = convert repaidValue to borrow shares
                // ROUNDING: mulDivUp on quote, wDivUp on discount, toSharesUp for shares
                //           All round UP - liquidator repays MORE (protocol favored)
                uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

                repaidShares = seizedAssetsQuoted.wDivUp(liquidationIncentiveFactor)
                    .toSharesUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
            } else {
                // MATH: Given repaidShares, calculate seizedAssets
                // Step 1: repaidAssets = convert shares to assets
                // Step 2: seizedValue = repaidAssets * LIF (apply liquidation bonus)
                // Step 3: seizedAssets = seizedValue * 1e36 / price (convert to collateral terms)
                // ROUNDING: toAssetsDown, wMulDown, mulDivDown - all round DOWN
                //           Liquidator seizes LESS collateral (protocol favored)
                seizedAssets = repaidShares.toAssetsDown(market[id].totalBorrowAssets, market[id].totalBorrowShares)
                    .wMulDown(liquidationIncentiveFactor).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
            }
        }

        // MATH: Calculate repaidAssets from repaidShares
        // ROUNDING: rounds UP - liquidator pays slightly more (protocol favored)
        uint256 repaidAssets = repaidShares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);

        // STATE: Reduce borrower's debt
        // SECURITY: Underflow reverts if repaying more than owed
        position[id][borrower].borrowShares -= repaidShares.toUint128();
        market[id].totalBorrowShares -= repaidShares.toUint128();
        // EDGE CASE: zeroFloorSub handles repaidAssets > totalBorrowAssets (by 1 due to rounding)
        market[id].totalBorrowAssets = UtilsLib.zeroFloorSub(market[id].totalBorrowAssets, repaidAssets).toUint128();

        // STATE: Seize collateral from borrower
        // SECURITY: Underflow reverts if seizing more than borrower has
        position[id][borrower].collateral -= seizedAssets.toUint128();

        // --- BAD DEBT HANDLING ---
        // If borrower has no collateral remaining but still has debt, the debt is "bad"
        // Bad debt is socialized: suppliers absorb the loss via reduced totalSupplyAssets
        uint256 badDebtShares;
        uint256 badDebtAssets;
        if (position[id][borrower].collateral == 0) {
            // MATH: All remaining debt becomes bad debt
            badDebtShares = position[id][borrower].borrowShares;
            // MATH: Convert to assets, capped at totalBorrowAssets to prevent underflow
            badDebtAssets = UtilsLib.min(
                market[id].totalBorrowAssets,
                badDebtShares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares)
            );

            // STATE: SOCIALIZATION - reduce totalSupplyAssets
            // This means each supply share is now worth less - suppliers absorb the loss
            // SECURITY: This is a designed loss-sharing mechanism, not a bug
            market[id].totalBorrowAssets -= badDebtAssets.toUint128();
            market[id].totalSupplyAssets -= badDebtAssets.toUint128();
            market[id].totalBorrowShares -= badDebtShares.toUint128();
            position[id][borrower].borrowShares = 0;
        }

        emit EventsLib.Liquidate(
            id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares
        );

        // EXTERNAL: Collateral transfer to liquidator BEFORE callback
        // SECURITY: Liquidator receives collateral first, then callback, then repays
        // This allows flash liquidation patterns (use seized collateral to source repayment)
        IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets);

        // SECURITY: Callback after collateral received but before debt repayment
        if (data.length > 0) IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data);

        // EXTERNAL: Liquidator repays the debt
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);

        return (seizedAssets, repaidAssets);
    }

    /* FLASH LOANS */

    // --- FLASH LOAN FUNCTION ---
    // STATE: No persistent state changes - tokens borrowed and repaid atomically.
    // SECURITY: No fee charged - free flash loans for all users.
    // SECURITY: Access to ALL tokens held by contract, not just specific market tokens.
    //           This includes: all market loan tokens, all market collateral tokens, and donations.
    // SECURITY: Callback is REQUIRED - caller must implement IMorphoFlashLoanCallback.
    //           If callback reverts, entire transaction reverts and tokens remain safe.
    // SECURITY: Caller must approve Morpho to reclaim tokens via safeTransferFrom.
    /// @inheritdoc IMorphoBase
    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        // BOUNDS: Must borrow non-zero amount
        require(assets != 0, ErrorsLib.ZERO_ASSETS);

        // NOTE: Event emitted before transfer for consistency with other functions
        emit EventsLib.FlashLoan(msg.sender, token, assets);

        // EXTERNAL: Send tokens to caller
        // SECURITY: Can borrow ANY token held by contract (all markets + donations)
        // This is intentional - flash loans provide maximum flexibility
        IERC20(token).safeTransfer(msg.sender, assets);

        // CALLBACK: Caller executes their logic
        // Common use cases: arbitrage, liquidation, collateral swaps, leverage
        // SECURITY: If callback reverts, entire transaction reverts - no state changes persist
        IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data);

        // EXTERNAL: Reclaim tokens from caller
        // SECURITY: Caller must have approved Morpho to transfer tokens back
        // SECURITY: If caller doesn't have tokens or approval, this reverts
        // NOTE: No fee - caller returns exactly what they borrowed
        IERC20(token).safeTransferFrom(msg.sender, address(this), assets);
    }

    /* AUTHORIZATION */

    // --- SET AUTHORIZATION FUNCTION ---
    // STATE: Grants or revokes authorization for another address to manage caller's positions.
    // SECURITY: Authorizing an address allows them to:
    //   - withdraw() on behalf of caller (withdraw supply)
    //   - borrow() on behalf of caller (increase debt)
    //   - withdrawCollateral() on behalf of caller (reduce collateral)
    // SECURITY: Authorization can be revoked anytime by calling with newIsAuthorized=false.
    // NOTE: Self-authorization is implicit (msg.sender == onBehalf always passes auth check).
    /// @inheritdoc IMorphoBase
    function setAuthorization(address authorized, bool newIsAuthorized) external {
        // BOUNDS: Prevent no-op state change
        require(newIsAuthorized != isAuthorized[msg.sender][authorized], ErrorsLib.ALREADY_SET);

        // STATE: Update authorization mapping
        isAuthorized[msg.sender][authorized] = newIsAuthorized;

        emit EventsLib.SetAuthorization(msg.sender, msg.sender, authorized, newIsAuthorized);
    }

    // --- SET AUTHORIZATION WITH SIGNATURE FUNCTION ---
    // STATE: Sets authorization using EIP-712 signature, enabling gasless authorization.
    // SECURITY: Nonce system prevents replay attacks - each nonce usable exactly once.
    // SECURITY: Deadline provides time-limited authorization windows.
    // SECURITY: Domain separator is chain-specific to prevent cross-chain replay.
    // NOTE: Signature malleability (flipping s) has no security impact - same result.
    /// @inheritdoc IMorphoBase
    function setAuthorizationWithSig(Authorization memory authorization, Signature calldata signature) external {
        // NOTE: Don't check if authorization value already set
        // Nonce increment is a desired side effect (burns nonce even for no-op)
        // This allows revoking via signature even if already set to same value

        // BOUNDS: Signature must not be expired
        require(block.timestamp <= authorization.deadline, ErrorsLib.SIGNATURE_EXPIRED);

        // SECURITY: Nonce must match current value AND increments atomically
        // This prevents: (1) replay attacks, (2) out-of-order execution, (3) skipping nonces
        // Post-increment ensures nonce is used exactly once
        require(authorization.nonce == nonce[authorization.authorizer]++, ErrorsLib.INVALID_NONCE);

        // MATH: EIP-712 structured data hashing
        // hashStruct = keccak256(AUTHORIZATION_TYPEHASH || authorization fields)
        // digest = keccak256("\x19\x01" || DOMAIN_SEPARATOR || hashStruct)
        bytes32 hashStruct = keccak256(abi.encode(AUTHORIZATION_TYPEHASH, authorization));
        bytes32 digest = keccak256(bytes.concat("\x19\x01", DOMAIN_SEPARATOR, hashStruct));

        // SECURITY: Recover signer from signature
        // ecrecover returns address(0) for invalid signatures
        address signatory = ecrecover(digest, signature.v, signature.r, signature.s);

        // SECURITY: Verify signature is valid and matches authorizer
        // signatory != address(0) ensures signature is valid
        // signatory == authorizer ensures signer is the claimed authorizer
        require(signatory != address(0) && authorization.authorizer == signatory, ErrorsLib.INVALID_SIGNATURE);

        emit EventsLib.IncrementNonce(msg.sender, authorization.authorizer, authorization.nonce);

        // STATE: Update authorization mapping
        isAuthorized[authorization.authorizer][authorization.authorized] = authorization.isAuthorized;

        emit EventsLib.SetAuthorization(
            msg.sender, authorization.authorizer, authorization.authorized, authorization.isAuthorized
        );
    }

    // --- AUTHORIZATION CHECK HELPER ---
    // SECURITY: Returns true if msg.sender can manage onBehalf's positions.
    // MATH: authorized = (msg.sender == onBehalf) OR isAuthorized[onBehalf][msg.sender]
    // NOTE: Self-authorization always passes - users can always manage their own positions.
    /// @dev Returns whether the sender is authorized to manage `onBehalf`'s positions.
    function _isSenderAuthorized(address onBehalf) internal view returns (bool) {
        return msg.sender == onBehalf || isAuthorized[onBehalf][msg.sender];
    }

    /* INTEREST MANAGEMENT */

    // --- ACCRUE INTEREST PUBLIC FUNCTION ---
    // STATE: Manually triggers interest accrual for a market.
    // SECURITY: Permissionless - useful for keepers or before querying accurate balances.
    // NOTE: No-op if called in same block (elapsed time = 0).
    /// @inheritdoc IMorphoBase
    function accrueInterest(MarketParams memory marketParams) external {
        Id id = marketParams.id();
        // BOUNDS: Market must exist
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);

        _accrueInterest(marketParams, id);
    }

    // --- ACCRUE INTEREST INTERNAL FUNCTION ---
    // STATE: Computes and applies interest accrual for a market.
    // MATH: Uses continuous compounding approximated via Taylor expansion:
    //       e^(rt) - 1 approximately equals rt + (rt)^2/2 + (rt)^3/6
    //       This approximation is accurate for typical interest rates and time periods.
    // EXTERNAL: Calls IRM.borrowRate(marketParams, market) to get current rate.
    //           If IRM reverts, entire accrual fails - IRM is a critical dependency.
    // NOTE: Assumes marketParams and id match (caller responsibility).
    /// @dev Accrues interest for the given market `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _accrueInterest(MarketParams memory marketParams, Id id) internal {
        // MATH: Time elapsed since last accrual
        uint256 elapsed = block.timestamp - market[id].lastUpdate;

        // OPTIMIZATION: Skip if same block - no interest can accrue in 0 seconds
        // This saves gas when multiple operations happen in same block
        if (elapsed == 0) return;

        // IRM == address(0) means 0% APR market (no interest accrues)
        if (marketParams.irm != address(0)) {
            // EXTERNAL: Query Interest Rate Model for current borrow rate
            // MATH: borrowRate is per-second rate scaled by WAD (1e18)
            //       e.g., 5% APR = 0.05/31536000 * 1e18 ~ 1.585e9 per second
            // SECURITY: IRM is trusted external contract. Malicious IRM could:
            //           - Return extreme rates causing overflow
            //           - Revert to block protocol operations
            uint256 borrowRate = IIrm(marketParams.irm).borrowRate(marketParams, market[id]);

            // MATH: Calculate interest using Taylor expansion of continuous compounding
            // interest = principal * (e^(rate * time) - 1)
            // wTaylorCompounded approximates (e^(rate * elapsed) - 1)
            // Result: interest accrued on totalBorrowAssets over elapsed seconds
            uint256 interest = market[id].totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));

            // STATE: Interest increases both borrow AND supply assets
            // MATH: Borrowers owe more (totalBorrowAssets increases)
            //       Suppliers are entitled to more (totalSupplyAssets increases)
            //       This maintains the invariant: totalSupply >= totalBorrow
            market[id].totalBorrowAssets += interest.toUint128();
            market[id].totalSupplyAssets += interest.toUint128();

            // --- FEE HANDLING ---
            // Protocol takes a portion of interest as fee, converted to supply shares
            uint256 feeShares;
            if (market[id].fee != 0) {
                // MATH: feeAmount = interest * fee
                // e.g., 100 interest at 10% fee = 10 feeAmount
                uint256 feeAmount = interest.wMulDown(market[id].fee);

                // MATH: Convert feeAmount to supply shares
                // KEY INSIGHT: totalSupplyAssets ALREADY includes full interest
                // To mint shares representing feeAmount, we compute:
                //   feeShares = feeAmount * totalShares / (totalAssets - feeAmount)
                // This gives feeRecipient exactly feeAmount worth of the supply pool
                // ROUNDING: toSharesDown - protocol receives slightly fewer shares
                feeShares =
                    feeAmount.toSharesDown(market[id].totalSupplyAssets - feeAmount, market[id].totalSupplyShares);

                // STATE: Mint fee shares to feeRecipient
                // NOTE: No Supply event - fee minting is silent/implicit
                // WARNING: If feeRecipient == address(0), shares are burned (lost)
                position[id][feeRecipient].supplyShares += feeShares;
                market[id].totalSupplyShares += feeShares.toUint128();
            }

            emit EventsLib.AccrueInterest(id, borrowRate, interest, feeShares);
        }

        // STATE: Update timestamp - always, even for 0% APR markets
        // This ensures elapsed calculation is correct for future accruals
        // BOUNDS: block.timestamp fits in uint128 until year ~10^31
        market[id].lastUpdate = uint128(block.timestamp);
    }

    /* HEALTH CHECK */

    // --- HEALTH CHECK (3-param) ---
    // SECURITY: Checks if borrower's position is healthy by querying oracle.
    // EXTERNAL: Calls oracle.price() - oracle is single point of failure for health checks.
    //           Oracle manipulation could incorrectly mark positions healthy/unhealthy.
    // OPTIMIZATION: Returns true immediately if no debt (skips oracle call).
    // NOTE: Assumes marketParams and id match (caller responsibility).
    /// @dev Returns whether the position of `borrower` in the given market `marketParams` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _isHealthy(MarketParams memory marketParams, Id id, address borrower) internal view returns (bool) {
        // OPTIMIZATION: No debt means position is always healthy
        // This saves an external oracle call for collateral-only positions
        if (position[id][borrower].borrowShares == 0) return true;

        // EXTERNAL: Query oracle for current collateral price
        // SECURITY: Price is scaled by ORACLE_PRICE_SCALE (1e36)
        //           Price represents: (1 collateral token) is worth (price/1e36) loan tokens
        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        return _isHealthy(marketParams, id, borrower, collateralPrice);
    }

    // --- HEALTH CHECK (4-param) ---
    // MATH: Checks health using provided price (avoids redundant oracle calls).
    // MATH: Formula: healthy = (collateral * price / 1e36 * lltv) >= borrowed
    //       This means: collateral value * lltv ratio >= debt value
    //       Example: 100 ETH collateral, price=2000e36, LLTV=0.8
    //                maxBorrow = 100 * 2000 * 0.8 = 160,000 loan tokens
    // ROUNDING: All operations favor protocol:
    //   - borrowed rounds UP (borrower appears to owe more)
    //   - maxBorrow rounds DOWN (borrower can borrow less)
    //   This means positions right at the boundary are considered unhealthy.
    // NOTE: Assumes marketParams and id match (caller responsibility).
    /// @dev Returns whether the position of `borrower` in the given market `marketParams` with the given
    /// `collateralPrice` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    /// @dev Rounds in favor of the protocol, so one might not be able to borrow exactly `maxBorrow` but one unit less.
    function _isHealthy(MarketParams memory marketParams, Id id, address borrower, uint256 collateralPrice)
        internal
        view
        returns (bool)
    {
        // MATH: Calculate borrowed assets from borrow shares
        // ROUNDING: toAssetsUp - borrower appears to owe MORE than actual (protocol favored)
        // This makes health check stricter - position must be over-collateralized
        uint256 borrowed = uint256(position[id][borrower].borrowShares)
            .toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);

        // MATH: Calculate maximum borrow capacity based on collateral
        // Step 1: collateralValue = collateral * price / ORACLE_PRICE_SCALE
        //         (converts collateral to loan token terms)
        // Step 2: maxBorrow = collateralValue * lltv
        //         (applies loan-to-value ratio)
        // ROUNDING: mulDivDown and wMulDown both round DOWN
        //           Borrower can borrow LESS than theoretical max (protocol favored)
        // EXAMPLE: collateral=100, price=2e36, lltv=0.8e18
        //          collateralValue = 100 * 2e36 / 1e36 = 200
        //          maxBorrow = 200 * 0.8e18 / 1e18 = 160
        uint256 maxBorrow = uint256(position[id][borrower].collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);

        // INVARIANT: Position is healthy iff collateralization is sufficient
        // healthy = (maxBorrow >= borrowed)
        // Equivalently: (collateral * price * lltv) >= (borrowed * 1e36)
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

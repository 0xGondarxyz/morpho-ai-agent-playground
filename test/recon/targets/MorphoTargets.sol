// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {SelectorStorage} from "../SelectorStorage.sol";

import "src/Morpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";

abstract contract MorphoTargets is BaseTargetFunctions, Properties {
    using MarketParamsLib for MarketParams;

    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function morpho_setOwner_clamped(uint8 actorSeed) public trackOp(SelectorStorage.MORPHO_SET_OWNER) asAdmin {
        address[] memory actors = _getActors();
        address newOwner = actors[actorSeed % actors.length];

        // If we selected the caller, pick next one
        if (newOwner == address(this)) {
            newOwner = actors[(actorSeed + 1) % actors.length];
        }

        morpho.setOwner(newOwner);
    }

    function morpho_setFee_clamped(uint256 _newFee) public trackOp(SelectorStorage.MORPHO_SET_FEE) asAdmin {
        // Clamp newFee to MAX_FEE
        _newFee = _newFee % (0.25e18 + 1);

        // Skip if same as current fee
        Id id = marketParams.id();
        (,,,,, uint128 currentFee) = morpho.market(id);
        if (_newFee == currentFee) return;

        morpho.setFee(marketParams, _newFee);
    }

    function morpho_setFeeRecipient_clamped(address _newFeeRecipient)
        public
        trackOp(SelectorStorage.MORPHO_SET_FEE_RECIPIENT)
        asAdmin
    {
        // Skip if same as current fee recipient
        if (_newFeeRecipient == morpho.feeRecipient()) return;

        morpho.setFeeRecipient(_newFeeRecipient);
    }

    //**LOAN/SUPPLY MANAGEMENT */

    function morpho_supplyAssets_clamped(uint256 assets, uint8 onBehalfSeed, bytes memory data)
        public
        trackOp(SelectorStorage.MORPHO_SUPPLY)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];
        morpho.supply(marketParams, assets, 0, onBehalf, data);
    }

    function morpho_supplyShares_clamped(uint256 _shares, uint8 onBehalfSeed, bytes memory _data)
        public
        trackOp(SelectorStorage.MORPHO_SUPPLY)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];
        morpho.supply(marketParams, 0, _shares, onBehalf, _data);
    }

    //* idk if this one complicates the fuzzer
    function morpho_withdrawAssets_clamped(uint256 assets, uint8 onBehalfSeed, uint8 receiverSeed)
        public
        trackOp(SelectorStorage.MORPHO_WITHDRAW)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];
        address receiver = actors[receiverSeed % actors.length];

        // Skip if caller is not authorized by onBehalf
        address caller = _getActor();
        if (caller != onBehalf && !morpho.isAuthorized(onBehalf, caller)) return;

        morpho.withdraw(marketParams, assets, 0, onBehalf, receiver);
    }

    function morpho_withdrawShares_clamped(uint256 shares, uint8 onBehalfSeed, uint8 receiverSeed)
        public
        trackOp(SelectorStorage.MORPHO_WITHDRAW)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];
        address receiver = actors[receiverSeed % actors.length];

        // Skip if caller is not authorized by onBehalf
        address caller = _getActor();
        if (caller != onBehalf && !morpho.isAuthorized(onBehalf, caller)) return;

        morpho.withdraw(marketParams, 0, shares, onBehalf, receiver);
    }

    //* BORROW MANAGEMENT */

    function morpho_borrowAssets_clamped(uint256 assets, uint8 onBehalfSeed, uint8 receiverSeed)
        public
        trackOp(SelectorStorage.MORPHO_BORROW)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];
        address receiver = actors[receiverSeed % actors.length];

        // Skip if caller is not authorized by onBehalf
        address caller = _getActor();
        if (caller != onBehalf && !morpho.isAuthorized(onBehalf, caller)) return;

        morpho.borrow(marketParams, assets, 0, onBehalf, receiver);
    }

    function morpho_borrowShares_clamped(uint256 shares, uint8 onBehalfSeed, uint8 receiverSeed)
        public
        trackOp(SelectorStorage.MORPHO_BORROW)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];
        address receiver = actors[receiverSeed % actors.length];

        // Skip if caller is not authorized by onBehalf
        address caller = _getActor();
        if (caller != onBehalf && !morpho.isAuthorized(onBehalf, caller)) return;

        morpho.borrow(marketParams, 0, shares, onBehalf, receiver);
    }

    function morpho_repayAssets_clamped(uint256 assets, uint8 onBehalfSeed, bytes memory data)
        public
        trackOp(SelectorStorage.MORPHO_REPAY)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];

        // Skip if caller is not authorized by onBehalf
        address caller = _getActor();
        if (caller != onBehalf && !morpho.isAuthorized(onBehalf, caller)) return;

        morpho.repay(marketParams, assets, 0, onBehalf, data);
    }

    function morpho_repayShares_clamped(uint256 shares, uint8 onBehalfSeed, bytes memory data)
        public
        trackOp(SelectorStorage.MORPHO_REPAY)
        asActor
    {
        address[] memory actors = _getActors();
        address onBehalf = actors[onBehalfSeed % actors.length];

        // Skip if caller is not authorized by onBehalf
        address caller = _getActor();
        if (caller != onBehalf && !morpho.isAuthorized(onBehalf, caller)) return;

        morpho.repay(marketParams, 0, shares, onBehalf, data);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function morpho_accrueInterest(MarketParams memory marketParams)
        public
        trackOp(SelectorStorage.MORPHO_ACCRUE_INTEREST)
        asActor
    {
        morpho.accrueInterest(marketParams);
    }

    function morpho_borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) public trackOp(SelectorStorage.MORPHO_BORROW) asActor {
        morpho.borrow(marketParams, assets, shares, onBehalf, receiver);
    }

    function morpho_createMarket() public trackOp(SelectorStorage.MORPHO_CREATE_MARKET) asActor {
        morpho.createMarket(marketParams);
    }

    function morpho_enableIrm(address irm) public trackOp(SelectorStorage.MORPHO_ENABLE_IRM) asActor {
        morpho.enableIrm(irm);
    }

    function morpho_enableLltv(uint256 lltv) public trackOp(SelectorStorage.MORPHO_ENABLE_LLTV) asActor {
        morpho.enableLltv(lltv);
    }

    function morpho_flashLoan(address token, uint256 assets, bytes memory data)
        public
        trackOp(SelectorStorage.MORPHO_FLASH_LOAN)
        asActor
    {
        morpho.flashLoan(token, assets, data);
    }

    function morpho_liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes memory data
    ) public trackOp(SelectorStorage.MORPHO_LIQUIDATE) asActor {
        morpho.liquidate(marketParams, borrower, seizedAssets, repaidShares, data);
    }

    function morpho_repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) public trackOp(SelectorStorage.MORPHO_REPAY) asActor {
        morpho.repay(marketParams, assets, shares, onBehalf, data);
    }

    function morpho_setAuthorization(address authorized, bool newIsAuthorized)
        public
        trackOp(SelectorStorage.MORPHO_SET_AUTHORIZATION)
        asActor
    {
        morpho.setAuthorization(authorized, newIsAuthorized);
    }

    function morpho_setAuthorizationWithSig(Authorization memory authorization, Signature memory signature)
        public
        trackOp(SelectorStorage.MORPHO_SET_AUTHORIZATION_WITH_SIG)
        asActor
    {
        morpho.setAuthorizationWithSig(authorization, signature);
    }

    function morpho_setFee(MarketParams memory marketParams, uint256 newFee)
        public
        trackOp(SelectorStorage.MORPHO_SET_FEE)
        asActor
    {
        morpho.setFee(marketParams, newFee);
    }

    function morpho_setFeeRecipient(address newFeeRecipient)
        public
        trackOp(SelectorStorage.MORPHO_SET_FEE_RECIPIENT)
        asActor
    {
        morpho.setFeeRecipient(newFeeRecipient);
    }

    function morpho_setOwner(address newOwner) public trackOp(SelectorStorage.MORPHO_SET_OWNER) asActor {
        morpho.setOwner(newOwner);
    }

    function morpho_supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) public trackOp(SelectorStorage.MORPHO_SUPPLY) asActor {
        morpho.supply(marketParams, assets, shares, onBehalf, data);
    }

    function morpho_supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes memory data
    ) public trackOp(SelectorStorage.MORPHO_SUPPLY_COLLATERAL) asActor {
        morpho.supplyCollateral(marketParams, assets, onBehalf, data);
    }

    function morpho_withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) public trackOp(SelectorStorage.MORPHO_WITHDRAW) asActor {
        morpho.withdraw(marketParams, assets, shares, onBehalf, receiver);
    }

    function morpho_withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) public trackOp(SelectorStorage.MORPHO_WITHDRAW_COLLATERAL) asActor {
        morpho.withdrawCollateral(marketParams, assets, onBehalf, receiver);
    }
}

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

abstract contract MorphoTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function morpho_accrueInterest(MarketParams memory marketParams) public trackOp(SelectorStorage.MORPHO_ACCRUE_INTEREST) asActor {
        morpho.accrueInterest(marketParams);
    }

    function morpho_borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) public trackOp(SelectorStorage.MORPHO_BORROW) asActor {
        morpho.borrow(marketParams, assets, shares, onBehalf, receiver);
    }

    function morpho_createMarket(MarketParams memory marketParams) public trackOp(SelectorStorage.MORPHO_CREATE_MARKET) asActor {
        morpho.createMarket(marketParams);
    }

    function morpho_enableIrm(address irm) public trackOp(SelectorStorage.MORPHO_ENABLE_IRM) asActor {
        morpho.enableIrm(irm);
    }

    function morpho_enableLltv(uint256 lltv) public trackOp(SelectorStorage.MORPHO_ENABLE_LLTV) asActor {
        morpho.enableLltv(lltv);
    }

    function morpho_flashLoan(address token, uint256 assets, bytes memory data) public trackOp(SelectorStorage.MORPHO_FLASH_LOAN) asActor {
        morpho.flashLoan(token, assets, data);
    }

    function morpho_liquidate(MarketParams memory marketParams, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes memory data) public trackOp(SelectorStorage.MORPHO_LIQUIDATE) asActor {
        morpho.liquidate(marketParams, borrower, seizedAssets, repaidShares, data);
    }

    function morpho_repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) public trackOp(SelectorStorage.MORPHO_REPAY) asActor {
        morpho.repay(marketParams, assets, shares, onBehalf, data);
    }

    function morpho_setAuthorization(address authorized, bool newIsAuthorized) public trackOp(SelectorStorage.MORPHO_SET_AUTHORIZATION) asActor {
        morpho.setAuthorization(authorized, newIsAuthorized);
    }

    function morpho_setAuthorizationWithSig(Authorization memory authorization, Signature memory signature) public trackOp(SelectorStorage.MORPHO_SET_AUTHORIZATION_WITH_SIG) asActor {
        morpho.setAuthorizationWithSig(authorization, signature);
    }

    function morpho_setFee(MarketParams memory marketParams, uint256 newFee) public trackOp(SelectorStorage.MORPHO_SET_FEE) asActor {
        morpho.setFee(marketParams, newFee);
    }

    function morpho_setFeeRecipient(address newFeeRecipient) public trackOp(SelectorStorage.MORPHO_SET_FEE_RECIPIENT) asActor {
        morpho.setFeeRecipient(newFeeRecipient);
    }

    function morpho_setOwner(address newOwner) public trackOp(SelectorStorage.MORPHO_SET_OWNER) asActor {
        morpho.setOwner(newOwner);
    }

    function morpho_supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) public trackOp(SelectorStorage.MORPHO_SUPPLY) asActor {
        morpho.supply(marketParams, assets, shares, onBehalf, data);
    }

    function morpho_supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data) public trackOp(SelectorStorage.MORPHO_SUPPLY_COLLATERAL) asActor {
        morpho.supplyCollateral(marketParams, assets, onBehalf, data);
    }

    function morpho_withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) public trackOp(SelectorStorage.MORPHO_WITHDRAW) asActor {
        morpho.withdraw(marketParams, assets, shares, onBehalf, receiver);
    }

    function morpho_withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) public trackOp(SelectorStorage.MORPHO_WITHDRAW_COLLATERAL) asActor {
        morpho.withdrawCollateral(marketParams, assets, onBehalf, receiver);
    }
}
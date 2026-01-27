// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

/// @notice Auto-generated selector constants for operation tracking
library SelectorStorage {
    bytes4 constant MORPHO_ACCRUE_INTEREST = bytes4(keccak256("accrueInterest(tuple)"));
    bytes4 constant MORPHO_BORROW = bytes4(keccak256("borrow(tuple,uint256,uint256,address,address)"));
    bytes4 constant MORPHO_CREATE_MARKET = bytes4(keccak256("createMarket(tuple)"));
    bytes4 constant MORPHO_ENABLE_IRM = bytes4(keccak256("enableIrm(address)"));
    bytes4 constant MORPHO_ENABLE_LLTV = bytes4(keccak256("enableLltv(uint256)"));
    bytes4 constant MORPHO_FLASH_LOAN = bytes4(keccak256("flashLoan(address,uint256,bytes)"));
    bytes4 constant MORPHO_LIQUIDATE = bytes4(keccak256("liquidate(tuple,address,uint256,uint256,bytes)"));
    bytes4 constant MORPHO_REPAY = bytes4(keccak256("repay(tuple,uint256,uint256,address,bytes)"));
    bytes4 constant MORPHO_SET_AUTHORIZATION = bytes4(keccak256("setAuthorization(address,bool)"));
    bytes4 constant MORPHO_SET_AUTHORIZATION_WITH_SIG = bytes4(keccak256("setAuthorizationWithSig(tuple,tuple)"));
    bytes4 constant MORPHO_SET_FEE = bytes4(keccak256("setFee(tuple,uint256)"));
    bytes4 constant MORPHO_SET_FEE_RECIPIENT = bytes4(keccak256("setFeeRecipient(address)"));
    bytes4 constant MORPHO_SET_OWNER = bytes4(keccak256("setOwner(address)"));
    bytes4 constant MORPHO_SUPPLY = bytes4(keccak256("supply(tuple,uint256,uint256,address,bytes)"));
    bytes4 constant MORPHO_SUPPLY_COLLATERAL = bytes4(keccak256("supplyCollateral(tuple,uint256,address,bytes)"));
    bytes4 constant MORPHO_WITHDRAW = bytes4(keccak256("withdraw(tuple,uint256,uint256,address,address)"));
    bytes4 constant MORPHO_WITHDRAW_COLLATERAL = bytes4(keccak256("withdrawCollateral(tuple,uint256,address,address)"));
}

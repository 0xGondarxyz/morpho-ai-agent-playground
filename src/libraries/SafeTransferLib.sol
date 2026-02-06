// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "../interfaces/IERC20.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";

interface IERC20Internal {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title SafeTransferLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library to manage transfers of tokens, even if calls to the transfer or transferFrom functions are not
/// returning a boolean.
/// @dev SECURITY: Handles non-standard ERC20 tokens that don't return bool from transfer/transferFrom.
/// @dev SECURITY: Examples: USDT (no return), BNB (no return on some chains).
/// @dev SECURITY: Validates: (1) token has code, (2) call succeeded, (3) return is empty or true.
/// @dev WARNING: Does NOT support fee-on-transfer tokens - actual received amount may differ from `value`.
/// @dev WARNING: Does NOT support rebasing tokens - balance may change unexpectedly.
library SafeTransferLib {
    /// @dev EXTERNAL: Safely transfers ERC20 tokens from this contract to `to`.
    /// @dev VALIDATION: Requires token address has deployed code (not EOA/empty).
    /// @dev VALIDATION: Requires low-level call succeeds (no revert).
    /// @dev VALIDATION: Requires return data is empty OR decodes to true.
    /// @dev SECURITY: Three-check pattern handles all ERC20 variants.
    /// @dev SECURITY: Check 1: code.length > 0 prevents calls to EOA (which always succeed).
    /// @dev SECURITY: Check 2: success ensures the call didn't revert.
    /// @dev SECURITY: Check 3: returndata check handles both standard and non-returning tokens.
    /// @dev WARNING: Fee-on-transfer tokens will cause accounting mismatches.
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(address(token).code.length > 0, ErrorsLib.NO_CODE);

        (bool success, bytes memory returndata) =
            address(token).call(abi.encodeCall(IERC20Internal.transfer, (to, value)));
        require(success, ErrorsLib.TRANSFER_REVERTED);
        require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_RETURNED_FALSE);
    }

    /// @dev EXTERNAL: Safely transfers ERC20 tokens from `from` to `to` (requires approval).
    /// @dev VALIDATION: Same three-check pattern as safeTransfer.
    /// @dev VALIDATION: Requires token address has deployed code (not EOA/empty).
    /// @dev VALIDATION: Requires low-level call succeeds (no revert).
    /// @dev VALIDATION: Requires return data is empty OR decodes to true.
    /// @dev SECURITY: Caller must have sufficient allowance from `from`.
    /// @dev SECURITY: If allowance insufficient, call will revert (token-dependent error).
    /// @dev SECURITY: If balance insufficient, call will revert (token-dependent error).
    /// @dev SECURITY: Used for: supply (user -> Morpho), repay (user -> Morpho), flash loan repay.
    /// @dev WARNING: Fee-on-transfer tokens will cause accounting mismatches.
    /// @dev WARNING: Some tokens (e.g., USDT) require setting allowance to 0 before non-zero.
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(address(token).code.length > 0, ErrorsLib.NO_CODE);

        (bool success, bytes memory returndata) =
            address(token).call(abi.encodeCall(IERC20Internal.transferFrom, (from, to, value)));
        require(success, ErrorsLib.TRANSFER_FROM_REVERTED);
        require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_FROM_RETURNED_FALSE);
    }
}

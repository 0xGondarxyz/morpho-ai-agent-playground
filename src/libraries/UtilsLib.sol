// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";

/// @title UtilsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing helpers.
/// @dev SECURITY: Uses assembly for gas efficiency on frequently-called functions.
/// @dev Inspired by https://github.com/morpho-org/morpho-utils.
library UtilsLib {
    /// @dev VALIDATION: Returns true if exactly one of `x` and `y` is zero.
    /// @dev VALIDATION: Used to enforce that user specifies EITHER assets OR shares, not both or neither.
    /// @dev VALIDATION: supply(100, 0, ...) = valid. supply(0, 100, ...) = valid.
    /// @dev VALIDATION: supply(100, 100, ...) = invalid. supply(0, 0, ...) = invalid.
    /// @dev MATH: Assembly: xor(iszero(x), iszero(y)) returns 1 iff exactly one is zero.
    /// @dev MATH: Truth table: (0,0)->0, (0,n)->1, (n,0)->1, (n,n)->0.
    /// @dev OPTIMIZATION: Assembly is more gas-efficient than (x==0) != (y==0).
    function exactlyOneZero(uint256 x, uint256 y) internal pure returns (bool z) {
        assembly {
            z := xor(iszero(x), iszero(y))
        }
    }

    /// @dev MATH: Returns the minimum of `x` and `y`.
    /// @dev MATH: Assembly: z = x ^ ((x ^ y) * (y < x)).
    /// @dev MATH: If y < x: z = x ^ (x ^ y) = y. If y >= x: z = x ^ 0 = x.
    /// @dev SECURITY: Used to cap values (e.g., badDebtAssets capped at totalBorrowAssets).
    /// @dev SECURITY: Used to calculate liquidation incentive factor capped at MAX_LIQUIDATION_INCENTIVE_FACTOR.
    /// @dev OPTIMIZATION: Branchless assembly is more gas-efficient than conditional.
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    /// @dev BOUNDS: Safely casts uint256 to uint128, reverting on overflow.
    /// @dev BOUNDS: max uint128 = 340,282,366,920,938,463,463,374,607,431,768,211,455 (~3.4e38).
    /// @dev BOUNDS: Sufficient for any realistic token amounts (18 decimals = max ~3.4e20 tokens).
    /// @dev SECURITY: All market totals (supply/borrow assets/shares) and positions use uint128.
    /// @dev SECURITY: This caps individual positions and market size, preventing overflow in math.
    /// @dev SECURITY: Reverts with "max uint128 exceeded" if value is too large.
    /// @dev NOTE: Using uint128 instead of uint256 halves storage costs for packed structs.
    function toUint128(uint256 x) internal pure returns (uint128) {
        require(x <= type(uint128).max, ErrorsLib.MAX_UINT128_EXCEEDED);
        return uint128(x);
    }

    /// @dev MATH: Returns max(0, x - y) without underflow.
    /// @dev MATH: Assembly: z = (x > y) * (x - y). If x <= y, returns 0.
    /// @dev EDGE CASE: Handles rounding edge cases in repay() and liquidate().
    /// @dev EDGE CASE: repaidAssets may exceed totalBorrowAssets by 1 due to rounding.
    /// @dev EDGE CASE: Without zeroFloorSub, subtracting repaidAssets would underflow.
    /// @dev EXAMPLE: totalBorrowAssets=100, repaidAssets=101 (due to rounding) -> returns 0, not underflow.
    /// @dev SECURITY: Prevents revert on edge case, allowing full debt repayment.
    /// @dev OPTIMIZATION: Branchless assembly is more gas-efficient than conditional.
    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }
}

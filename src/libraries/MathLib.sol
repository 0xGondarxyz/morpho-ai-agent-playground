// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

uint256 constant WAD = 1e18;

/// @title MathLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library to manage fixed-point arithmetic.
/// @dev MATH: Uses WAD (1e18) as standard precision unit for fixed-point math.
/// @dev BOUNDS: All operations may overflow if inputs are too large - caller must validate.
/// @dev SECURITY: Rounding direction must be carefully chosen based on context (favor protocol).
library MathLib {
    /// @dev MATH: Returns (`x` * `y`) / `WAD` rounded down.
    /// @dev MATH: Used for WAD-scaled multiplication (e.g., applying interest rate to principal).
    /// @dev MATH: Example: wMulDown(100e18, 0.05e18) = 5e18 (5% of 100).
    /// @dev BOUNDS: Reverts on overflow if x * y > type(uint256).max.
    /// @dev SECURITY: Rounds DOWN - use when result should favor protocol (user receives less).
    function wMulDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD);
    }

    /// @dev MATH: Returns (`x` * `WAD`) / `y` rounded down.
    /// @dev MATH: Used for WAD-scaled division (e.g., calculating rate from amounts).
    /// @dev MATH: Example: wDivDown(5e18, 100e18) = 0.05e18 (5/100 = 5%).
    /// @dev BOUNDS: Reverts if y == 0 (division by zero).
    /// @dev BOUNDS: Reverts on overflow if x * WAD > type(uint256).max.
    /// @dev SECURITY: Rounds DOWN - use when result should favor protocol (user receives less).
    function wDivDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y);
    }

    /// @dev MATH: Returns (`x` * `WAD`) / `y` rounded up.
    /// @dev MATH: Used for WAD-scaled division when rounding up is needed.
    /// @dev MATH: Formula: (x * WAD + (y - 1)) / y ensures rounding up.
    /// @dev BOUNDS: Reverts if y == 0 (division by zero).
    /// @dev BOUNDS: Reverts on overflow if x * WAD > type(uint256).max.
    /// @dev SECURITY: Rounds UP - use when user should pay more (e.g., debt calculations).
    function wDivUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y);
    }

    /// @dev MATH: Returns (`x` * `y`) / `d` rounded down.
    /// @dev MATH: General-purpose multiply-then-divide operation.
    /// @dev MATH: Example: mulDivDown(100, 3, 4) = 75 (rounds down from 75.0).
    /// @dev BOUNDS: Reverts if d == 0 (division by zero).
    /// @dev BOUNDS: Reverts on overflow if x * y > type(uint256).max.
    /// @dev WARNING: Unlike OpenZeppelin's mulDiv, no phantom overflow protection.
    /// @dev SECURITY: Rounds DOWN - result is always <= true value.
    function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }

    /// @dev MATH: Returns (`x` * `y`) / `d` rounded up.
    /// @dev MATH: General-purpose multiply-then-divide with ceiling rounding.
    /// @dev MATH: Formula: (x * y + (d - 1)) / d ensures rounding up for non-zero results.
    /// @dev MATH: Example: mulDivUp(100, 3, 4) = 75, mulDivUp(101, 3, 4) = 76.
    /// @dev BOUNDS: Reverts if d == 0 (division by zero).
    /// @dev BOUNDS: Reverts on overflow if x * y + (d - 1) > type(uint256).max.
    /// @dev WARNING: If d == 1, (d - 1) = 0 and this becomes floor division.
    /// @dev SECURITY: Rounds UP - result is always >= true value.
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y + (d - 1)) / d;
    }

    /// @dev MATH: Returns the sum of the first three non-zero terms of a Taylor expansion of e^(nx) - 1.
    /// @dev MATH: Approximates continuous compound interest: e^(rate * time) - 1.
    /// @dev MATH: Taylor expansion: e^z - 1 = z + z^2/2! + z^3/3! + ... where z = x * n.
    /// @dev MATH: Uses only first 3 terms: xn + (xn)^2/2 + (xn)^3/6.
    /// @dev MATH: Example: For 5% APR over 1 year: x = 0.05e18/31536000 (per-second rate), n = 31536000.
    /// @dev MATH: Result is approximately 0.05127e18 (5.127% effective annual rate).
    /// @dev BOUNDS: Accurate for typical interest rates (< 100% APR) and reasonable time periods.
    /// @dev BOUNDS: May overflow if x * n is very large (extreme rates or time periods).
    /// @dev BOUNDS: Underestimates for very high rates (missing higher-order Taylor terms).
    /// @dev SECURITY: Used for interest accrual - slight underestimation favors borrowers marginally.
    /// @dev NOTE: For typical DeFi rates (< 50% APR) and block-by-block accrual, error is negligible.
    function wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256) {
        uint256 firstTerm = x * n;
        uint256 secondTerm = mulDivDown(firstTerm, firstTerm, 2 * WAD);
        uint256 thirdTerm = mulDivDown(secondTerm, firstTerm, 3 * WAD);

        return firstTerm + secondTerm + thirdTerm;
    }
}

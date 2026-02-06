// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {MathLib} from "./MathLib.sol";

/// @title SharesMathLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Shares management library.
/// @dev SECURITY: This implementation mitigates share price manipulations (inflation attacks).
/// @dev SECURITY: Uses OpenZeppelin's method of virtual shares: https://docs.openzeppelin.com/contracts/4.x/erc4626#inflation-attack.
/// @dev MATH: Virtual shares (1e6) and virtual assets (1) create a baseline conversion rate.
/// @dev MATH: This prevents first-depositor attacks where attacker can inflate share price via donation.
/// @dev INVARIANT: Conversion rate is always defined (never division by zero) due to virtual amounts.
library SharesMathLib {
    using MathLib for uint256;

    /// @dev MATH: Virtual shares added to totalShares in all calculations.
    /// @dev MATH: Value 1e6 chosen to balance precision vs overflow risk.
    /// @dev SECURITY: Prevents share inflation attack - first deposit gets ~1e6 shares per asset.
    /// @dev SECURITY: These virtual shares can never be redeemed (no holder).
    /// @dev WARNING: Virtual shares represent unrealizable assets - a small protocol "cost".
    /// @dev WARNING: For borrow shares, this represents unrealizable bad debt (~1e-6 assets).
    uint256 internal constant VIRTUAL_SHARES = 1e6;

    /// @dev MATH: Virtual assets added to totalAssets in all calculations.
    /// @dev MATH: Value 1 ensures conversion rate is defined even when market is empty.
    /// @dev SECURITY: Combined with VIRTUAL_SHARES, creates initial rate of 1e6 shares per asset.
    /// @dev EXAMPLE: Empty market: sharePrice = (0+1)/(0+1e6) = 1e-6 assets per share.
    uint256 internal constant VIRTUAL_ASSETS = 1;

    /// @dev MATH: Calculates the value of `assets` quoted in shares, rounding down.
    /// @dev MATH: Formula: shares = assets * (totalShares + 1e6) / (totalAssets + 1).
    /// @dev MATH: Example: 100 assets, totalAssets=900, totalShares=900e6 -> 100*(900e6+1e6)/(900+1) = ~100e6 shares.
    /// @dev SECURITY: Rounds DOWN - depositor receives FEWER shares (protocol favored).
    /// @dev SECURITY: Used in supply() when user specifies assets - user gets slightly less shares.
    /// @dev SECURITY: Used in repay() when user specifies assets - user repays slightly fewer debt shares.
    /// @dev BOUNDS: Cannot overflow for realistic totalAssets/totalShares (uint128 max ~3.4e38).
    function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return assets.mulDivDown(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
    }

    /// @dev MATH: Calculates the value of `shares` quoted in assets, rounding down.
    /// @dev MATH: Formula: assets = shares * (totalAssets + 1) / (totalShares + 1e6).
    /// @dev MATH: Example: 100e6 shares, totalAssets=900, totalShares=900e6 -> 100e6*(900+1)/(900e6+1e6) = ~99.9 assets.
    /// @dev SECURITY: Rounds DOWN - user receives FEWER assets (protocol favored).
    /// @dev SECURITY: Used in withdraw() when user specifies shares - user gets slightly less assets.
    /// @dev SECURITY: Used in borrow() when user specifies shares - user gets slightly less borrowed assets.
    /// @dev SECURITY: Used in liquidation when calculating seizedAssets from repaidShares.
    /// @dev BOUNDS: Cannot overflow for realistic totalAssets/totalShares (uint128 max ~3.4e38).
    function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return shares.mulDivDown(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
    }

    /// @dev MATH: Calculates the value of `assets` quoted in shares, rounding up.
    /// @dev MATH: Formula: shares = (assets * (totalShares + 1e6) + (totalAssets)) / (totalAssets + 1).
    /// @dev MATH: Uses mulDivUp which adds (denominator - 1) before division.
    /// @dev SECURITY: Rounds UP - user burns MORE shares or owes MORE debt shares (protocol favored).
    /// @dev SECURITY: Used in withdraw() when user specifies assets - user burns more shares.
    /// @dev SECURITY: Used in borrow() when user specifies assets - user owes more debt shares.
    /// @dev SECURITY: Used in liquidation when calculating repaidShares from seizedAssets.
    /// @dev BOUNDS: Cannot overflow for realistic totalAssets/totalShares (uint128 max ~3.4e38).
    function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return assets.mulDivUp(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
    }

    /// @dev MATH: Calculates the value of `shares` quoted in assets, rounding up.
    /// @dev MATH: Formula: assets = (shares * (totalAssets + 1) + (totalShares + 1e6 - 1)) / (totalShares + 1e6).
    /// @dev MATH: Uses mulDivUp which adds (denominator - 1) before division.
    /// @dev SECURITY: Rounds UP - user PAYS more assets or OWES more debt (protocol favored).
    /// @dev SECURITY: Used in supply() when user specifies shares - user pays more assets.
    /// @dev SECURITY: Used in repay() when user specifies shares - user repays more assets.
    /// @dev SECURITY: Used in health check to calculate borrowed assets - position appears to owe more.
    /// @dev SECURITY: Used in liquidation when calculating repaidAssets from repaidShares.
    /// @dev BOUNDS: Cannot overflow for realistic totalAssets/totalShares (uint128 max ~3.4e38).
    function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return shares.mulDivUp(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
    }
}

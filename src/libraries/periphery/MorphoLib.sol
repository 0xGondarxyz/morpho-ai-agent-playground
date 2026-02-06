// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IMorpho, Id} from "../../interfaces/IMorpho.sol";
import {MorphoStorageLib} from "./MorphoStorageLib.sol";

/// @title MorphoLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Helper library to access Morpho storage variables.
/// @dev EXTERNAL: Uses extSloads() to efficiently read Morpho storage slots.
/// @dev SECURITY: Read-only - cannot modify Morpho state.
/// @dev WARNING: Supply and borrow getters may return STALE values - they do NOT include accrued interest.
/// @dev WARNING: For accurate values, call accrueInterest() first OR use MorphoBalancesLib.expected* functions.
/// @dev NOTE: This library is for integrators who need raw storage access.
library MorphoLib {
    /// @dev STATE: Returns user's supply shares in a market.
    /// @dev WARNING: Does NOT include interest accrued since lastUpdate.
    /// @dev MATH: supplyShares stored as uint256 in Position struct.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function supplyShares(IMorpho morpho, Id id, address user) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.positionSupplySharesSlot(id, user));
        return uint256(morpho.extSloads(slot)[0]);
    }

    /// @dev STATE: Returns user's borrow shares in a market.
    /// @dev WARNING: Does NOT include interest accrued since lastUpdate.
    /// @dev MATH: borrowShares stored as uint128 in lower 128 bits of Position.borrowSharesAndCollateral slot.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function borrowShares(IMorpho morpho, Id id, address user) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.positionBorrowSharesAndCollateralSlot(id, user));
        return uint128(uint256(morpho.extSloads(slot)[0]));
    }

    /// @dev STATE: Returns user's collateral amount in a market.
    /// @dev NOTE: Collateral does NOT accrue interest - this value is always current.
    /// @dev MATH: collateral stored as uint128 in upper 128 bits of Position.borrowSharesAndCollateral slot.
    /// @dev MATH: Uses >> 128 to extract upper 128 bits.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function collateral(IMorpho morpho, Id id, address user) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.positionBorrowSharesAndCollateralSlot(id, user));
        return uint256(morpho.extSloads(slot)[0] >> 128);
    }

    /// @dev STATE: Returns total supply assets in a market.
    /// @dev WARNING: Does NOT include interest accrued since lastUpdate.
    /// @dev MATH: totalSupplyAssets stored as uint128 in lower 128 bits of Market slot.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function totalSupplyAssets(IMorpho morpho, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id));
        return uint128(uint256(morpho.extSloads(slot)[0]));
    }

    /// @dev STATE: Returns total supply shares in a market.
    /// @dev WARNING: Does NOT include fee shares accrued since lastUpdate.
    /// @dev MATH: totalSupplyShares stored as uint128 in upper 128 bits of Market slot.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function totalSupplyShares(IMorpho morpho, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id));
        return uint256(morpho.extSloads(slot)[0] >> 128);
    }

    /// @dev STATE: Returns total borrow assets in a market.
    /// @dev WARNING: Does NOT include interest accrued since lastUpdate.
    /// @dev MATH: totalBorrowAssets stored as uint128 in lower 128 bits of Market slot.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function totalBorrowAssets(IMorpho morpho, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id));
        return uint128(uint256(morpho.extSloads(slot)[0]));
    }

    /// @dev STATE: Returns total borrow shares in a market.
    /// @dev NOTE: Borrow shares do NOT change with interest accrual - this value is always current.
    /// @dev MATH: totalBorrowShares stored as uint128 in upper 128 bits of Market slot.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function totalBorrowShares(IMorpho morpho, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id));
        return uint256(morpho.extSloads(slot)[0] >> 128);
    }

    /// @dev STATE: Returns the timestamp of last interest accrual for a market.
    /// @dev NOTE: Used to calculate elapsed time since last accrual.
    /// @dev MATH: lastUpdate stored as uint128 in lower 128 bits of Market.lastUpdateAndFee slot.
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function lastUpdate(IMorpho morpho, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.marketLastUpdateAndFeeSlot(id));
        return uint128(uint256(morpho.extSloads(slot)[0]));
    }

    /// @dev STATE: Returns the protocol fee for a market.
    /// @dev MATH: fee stored as uint128 in upper 128 bits of Market.lastUpdateAndFee slot.
    /// @dev MATH: Fee is WAD-scaled percentage of interest (e.g., 0.1e18 = 10% fee).
    /// @dev EXTERNAL: Reads via extSloads for gas efficiency.
    function fee(IMorpho morpho, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(MorphoStorageLib.marketLastUpdateAndFeeSlot(id));
        return uint256(morpho.extSloads(slot)[0] >> 128);
    }

    /// @dev OPTIMIZATION: Helper to create single-element array for extSloads call.
    /// @dev NOTE: extSloads requires bytes32[] but we typically read one slot at a time.
    function _array(bytes32 x) private pure returns (bytes32[] memory) {
        bytes32[] memory res = new bytes32[](1);
        res[0] = x;
        return res;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id, MarketParams} from "../interfaces/IMorpho.sol";

/// @title MarketParamsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library to convert a market to its id.
/// @dev MATH: Market ID is deterministic hash of all market parameters.
/// @dev SECURITY: Same parameters always produce same ID - enables trustless market lookup.
/// @dev SECURITY: Different parameters produce different IDs (collision resistant).
library MarketParamsLib {
    /// @notice The length of the data used to compute the id of a market.
    /// @dev MATH: MarketParams has 5 fields, each 32 bytes (addresses are left-padded to 32 bytes in ABI encoding).
    /// @dev MATH: Fields: loanToken (32) + collateralToken (32) + oracle (32) + irm (32) + lltv (32) = 160 bytes.
    uint256 internal constant MARKET_PARAMS_BYTES_LENGTH = 5 * 32;

    /// @notice Returns the id of the market `marketParams`.
    /// @dev MATH: id = keccak256(abi.encode(loanToken, collateralToken, oracle, irm, lltv)).
    /// @dev MATH: ABI encoding ensures consistent byte representation across all calls.
    /// @dev SECURITY: Deterministic - same market params always produce same ID.
    /// @dev SECURITY: Collision resistant - different params produce different IDs.
    /// @dev OPTIMIZATION: Direct memory hash via assembly avoids abi.encode overhead.
    /// @dev OPTIMIZATION: "memory-safe" annotation allows compiler optimizations.
    /// @dev NOTE: MarketParams struct must be memory (not calldata/storage) for direct hashing.
    function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId) {
        assembly ("memory-safe") {
            marketParamsId := keccak256(marketParams, MARKET_PARAMS_BYTES_LENGTH)
        }
    }
}

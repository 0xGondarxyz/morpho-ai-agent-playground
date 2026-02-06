// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id, MarketParams, Market, IMorpho} from "../../interfaces/IMorpho.sol";
import {IIrm} from "../../interfaces/IIrm.sol";

import {MathLib} from "../MathLib.sol";
import {UtilsLib} from "../UtilsLib.sol";
import {MorphoLib} from "./MorphoLib.sol";
import {SharesMathLib} from "../SharesMathLib.sol";
import {MarketParamsLib} from "../MarketParamsLib.sol";

/// @title MorphoBalancesLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Helper library exposing getters with the expected value after interest accrual.
/// @dev SECURITY: View-only simulation of interest accrual - does NOT modify Morpho state.
/// @dev SECURITY: Calls IRM.borrowRateView() (view function) instead of borrowRate() (may modify state).
/// @dev NOTE: This library is NOT used in Morpho itself - intended for integrators needing accurate values.
/// @dev NOTE: totalBorrowShares is not exposed because it doesn't change with interest accrual.
/// @dev MATH: Simulates the exact same interest calculation as Morpho._accrueInterest().
library MorphoBalancesLib {
    using MathLib for uint256;
    using MathLib for uint128;
    using UtilsLib for uint256;
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

    /// @notice Returns the expected market balances of a market after having accrued interest.
    /// @dev MATH: Simulates interest accrual without modifying state.
    /// @dev MATH: Uses same Taylor expansion as Morpho: e^(rt) - 1 approx rt + (rt)^2/2 + (rt)^3/6.
    /// @dev EXTERNAL: Calls IRM.borrowRateView() - view-only rate query.
    /// @dev OPTIMIZATION: Skips calculation if elapsed=0, totalBorrowAssets=0, or irm=address(0).
    /// @return The expected total supply assets (includes accrued interest).
    /// @return The expected total supply shares (includes fee shares if fee > 0).
    /// @return The expected total borrow assets (includes accrued interest).
    /// @return The expected total borrow shares (unchanged - shares don't accrue).
    function expectedMarketBalances(IMorpho morpho, MarketParams memory marketParams)
        internal
        view
        returns (uint256, uint256, uint256, uint256)
    {
        Id id = marketParams.id();
        Market memory market = morpho.market(id);

        uint256 elapsed = block.timestamp - market.lastUpdate;

        // OPTIMIZATION: Skip if no interest would accrue
        // - elapsed == 0: same block, no time passed
        // - totalBorrowAssets == 0: no debt to accrue interest on
        // - irm == address(0): 0% APR market
        if (elapsed != 0 && market.totalBorrowAssets != 0 && marketParams.irm != address(0)) {
            uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
            uint256 interest = market.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
            market.totalBorrowAssets += interest.toUint128();
            market.totalSupplyAssets += interest.toUint128();

            if (market.fee != 0) {
                uint256 feeAmount = interest.wMulDown(market.fee);
                // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
                // that total supply is already updated.
                uint256 feeShares =
                    feeAmount.toSharesDown(market.totalSupplyAssets - feeAmount, market.totalSupplyShares);
                market.totalSupplyShares += feeShares.toUint128();
            }
        }

        return (market.totalSupplyAssets, market.totalSupplyShares, market.totalBorrowAssets, market.totalBorrowShares);
    }

    /// @notice Returns the expected total supply assets of a market after having accrued interest.
    function expectedTotalSupplyAssets(IMorpho morpho, MarketParams memory marketParams)
        internal
        view
        returns (uint256 totalSupplyAssets)
    {
        (totalSupplyAssets,,,) = expectedMarketBalances(morpho, marketParams);
    }

    /// @notice Returns the expected total borrow assets of a market after having accrued interest.
    function expectedTotalBorrowAssets(IMorpho morpho, MarketParams memory marketParams)
        internal
        view
        returns (uint256 totalBorrowAssets)
    {
        (,, totalBorrowAssets,) = expectedMarketBalances(morpho, marketParams);
    }

    /// @notice Returns the expected total supply shares of a market after having accrued interest.
    function expectedTotalSupplyShares(IMorpho morpho, MarketParams memory marketParams)
        internal
        view
        returns (uint256 totalSupplyShares)
    {
        (, totalSupplyShares,,) = expectedMarketBalances(morpho, marketParams);
    }

    /// @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
    /// @dev MATH: assets = supplyShares * expectedTotalAssets / expectedTotalShares.
    /// @dev MATH: Rounds DOWN - user's actual redeemable amount is never overestimated.
    /// @dev WARNING: INCORRECT for `feeRecipient` - their share increase from fees is not included.
    /// @dev WARNING: For feeRecipient, actual assets would be higher than this returns.
    /// @dev NOTE: For non-feeRecipient users, this is accurate.
    function expectedSupplyAssets(IMorpho morpho, MarketParams memory marketParams, address user)
        internal
        view
        returns (uint256)
    {
        Id id = marketParams.id();
        uint256 supplyShares = morpho.supplyShares(id, user);
        (uint256 totalSupplyAssets, uint256 totalSupplyShares,,) = expectedMarketBalances(morpho, marketParams);

        return supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);
    }

    /// @notice Returns the expected borrow assets balance of `user` on a market after having accrued interest.
    /// @dev MATH: assets = borrowShares * expectedTotalBorrowAssets / expectedTotalBorrowShares.
    /// @dev MATH: Rounds UP - user's actual debt is never underestimated.
    /// @dev SECURITY: Rounding UP ensures displayed debt is always >= actual debt.
    /// @dev WARNING: Due to rounding UP, sum of all user debts may exceed totalBorrowAssets.
    /// @dev WARNING: This is expected behavior - individual debts are conservative estimates.
    function expectedBorrowAssets(IMorpho morpho, MarketParams memory marketParams, address user)
        internal
        view
        returns (uint256)
    {
        Id id = marketParams.id();
        uint256 borrowShares = morpho.borrowShares(id, user);
        (,, uint256 totalBorrowAssets, uint256 totalBorrowShares) = expectedMarketBalances(morpho, marketParams);

        return borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);
    }
}

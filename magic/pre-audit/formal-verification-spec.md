# Morpho Blue -- Formal Verification Specification

> Partial FV specification targeting key libraries and pure functions.
> Goal: formally verify foundational building blocks so auditors can trust them and focus on stateful protocol logic.

---

## Executive Summary

### Existing Verification Coverage

Morpho Blue already has **extensive formal verification** via Certora (13 spec files) and **fuzzing infrastructure** via Echidna/Medusa (Chimera-based recon harness). This existing coverage is among the most thorough in DeFi.

**Certora specs cover (protocol-level):**
- Reentrancy safety (`Reentrancy.spec`)
- Exchange rate monotonicity (`ExchangeRate.spec`)
- Share accounting consistency (`ConsistentState.spec`)
- Asset accounting / no-profit extraction (`AssetsAccounting.spec`, `ExactMath.spec`)
- Interest accrual commutativity and idempotency (`AccrueInterest.spec`)
- Health check and liquidation correctness (`Health.spec`, `StayHealthy.spec`, `LiquidateBuffer.spec`)
- Liveness -- always able to exit (`Liveness.spec`)
- Transfer correctness (`Transfer.spec`)
- Input validation / reverts (`Reverts.spec`)
- Library summary correctness (`LibSummary.spec`)

**Certora specs cover (library-level, via LibSummary.spec):**
- `mulDivUp` rounds up: `result * d >= x * y`
- `mulDivDown` rounds down: `result * d <= x * y`
- `MarketParamsLib.id` matches reference implementation `keccak256(abi.encode(marketParams))`
- `UtilsLib.min` matches reference `x < y ? x : y`

**Fuzzing infrastructure (Echidna/Medusa):**
- Chimera-based recon harness with clamped target functions for all core operations
- Actor-based testing with 3 actors, market setup, oracle/IRM mocks
- No explicit property assertions found yet (harness appears under development)

### What This Spec Adds

Despite the excellent Certora coverage, the existing verification **does not directly prove isolated library function properties**. The Certora specs use **overapproximative summaries** for `mulDivUp`, `mulDivDown`, and `wTaylorCompounded` (modeled as `NONDET` or abstract ghost functions). This means:

1. **MathLib properties are assumed, not proven at the Solidity level** -- Certora's `LibSummary.spec` verifies summaries match but does not verify the Solidity implementation against overflow/underflow edge cases or boundary behavior.
2. **SharesMathLib roundtrip properties are not explicitly verified** -- the protocol-level specs prove supply/withdraw can't extract value, but don't independently verify the share conversion math.
3. **wTaylorCompounded is treated as NONDET** -- its mathematical properties (monotonicity, boundedness, approximation accuracy) are not verified.
4. **UtilsLib assembly functions** -- `exactlyOneZero`, `zeroFloorSub` use inline assembly and are not independently verified against reference implementations.

**This spec targets these gaps with Halmos (preferred) and supplementary Certora rules.**

### Audit Scope Reduction

If all properties in this spec are verified:
- Auditors can **skip manual review of MathLib arithmetic correctness** (rounding direction, overflow conditions) -- estimated 2-4 hours saved
- Auditors can **trust SharesMathLib conversion correctness** (roundtrip, monotonicity, virtual share protection) -- estimated 2-3 hours saved
- Auditors can **trust UtilsLib assembly implementations** match their documented behavior -- estimated 1-2 hours saved
- Auditors can **trust wTaylorCompounded bounds** for typical interest rate parameters -- estimated 1-2 hours saved
- **Total estimated audit time saved: 6-11 hours**

---

## Existing Verification Analysis

### Certora Prover (13 spec files)

| Spec File | What It Verifies | Library Coverage |
|-----------|-----------------|-----------------|
| `LibSummary.spec` | `mulDivUp` rounds up, `mulDivDown` rounds down, `id()` matches reference, `min` matches reference | Partial: direction-only proofs, not overflow/boundary |
| `ExchangeRate.spec` | Supply/borrow exchange rate monotonicity | Uses **summaries** for mulDivUp/Down (not actual code) |
| `ExactMath.spec` | No profit from supply+withdraw or borrow+repay in same block | Uses actual mulDiv implementations |
| `ConsistentState.spec` | Share sums, borrow <= supply, market parameter immutability, authorization safety | N/A (protocol-level) |
| `AssetsAccounting.spec` | Supply/withdraw/borrow/repay asset accounting | Uses mulDiv summaries |
| `AccrueInterest.spec` | Interest accrual idempotency and commutativity | wTaylorCompounded treated as **ghost** (NONDET) |
| `Health.spec` | Collateralization invariant, healthy users can't lose collateral | Uses min summary |
| `StayHealthy.spec` | Functions don't make positions unhealthy | N/A (protocol-level) |
| `LiquidateBuffer.spec` | Liquidation buffer before insolvency | N/A (protocol-level) |
| `Liveness.spec` | Always possible to exit positions | Uses id summary |
| `Reentrancy.spec` | No storage-call-storage reentrancy pattern | N/A (protocol-level) |
| `Transfer.spec` | Safe transfer summary correctness | N/A (transfer summary) |
| `Reverts.spec` | Input validation, revert conditions | N/A (protocol-level) |

### Fuzzing (Echidna/Medusa)

| Component | Status |
|-----------|--------|
| Echidna config | Present (`echidna.yaml`), assertion mode, 100k shrink limit |
| Medusa config | Present (`medusa.json`), 16 workers, assertion mode |
| Chimera harness | Present (`test/recon/`), with `MorphoTargets.sol` for all core functions |
| Property assertions | **Not yet implemented** (README shows examples but no actual `echidna_` or `property_` functions found in code) |
| Coverage | Harness covers all external functions with clamped and unclamped variants |

### Gap Analysis

| Library/Function | Certora Coverage | Halmos Coverage | Fuzzing Coverage | Gap |
|-----------------|-----------------|-----------------|-----------------|-----|
| `MathLib.mulDivDown` | Direction only (result*d <= x*y) | None | None | **Overflow bounds, identity cases, zero behavior** |
| `MathLib.mulDivUp` | Direction only (result*d >= x*y) | None | None | **Overflow bounds, ceil vs floor relationship, zero behavior** |
| `MathLib.wMulDown/wDivDown/wDivUp` | Indirectly via mulDiv | None | None | **WAD-specific properties** |
| `MathLib.wTaylorCompounded` | Treated as NONDET | None | None | **Monotonicity, bounds, approximation accuracy** |
| `SharesMathLib.toSharesDown/Up` | Protocol-level (no profit) | None | None | **Roundtrip, monotonicity, virtual share behavior** |
| `SharesMathLib.toAssetsDown/Up` | Protocol-level (no profit) | None | None | **Roundtrip, monotonicity, virtual share behavior** |
| `UtilsLib.exactlyOneZero` | Used in Reverts.spec | None | None | **Exhaustive truth table verification** |
| `UtilsLib.min` | Reference match in LibSummary | None | None | **Already covered** |
| `UtilsLib.toUint128` | Implicitly covered | None | None | **Boundary behavior** |
| `UtilsLib.zeroFloorSub` | Not independently verified | None | None | **Reference match, boundary** |
| `MarketParamsLib.id` | Reference match in LibSummary | None | None | **Already covered** |
| `SafeTransferLib` | Summary in Transfer.spec | None | None | **External call interaction -- hard to FV** |

---

## Verification Properties

### Group 1: MathLib (CRITICAL)

#### Property 1.1: mulDivDown Correctness

| Field | Value |
|-------|-------|
| **Name** | `mulDivDown_correctness` |
| **Target** | `src/libraries/MathLib.sol :: mulDivDown(uint256 x, uint256 y, uint256 d)` |
| **Property Type** | Equivalence |
| **Priority** | CRITICAL |
| **Existing Coverage** | Certora LibSummary: direction only (`result * d <= x * y`). Does NOT verify Solidity implementation directly. |
| **Estimated Effort** | Small (<1hr) -- pure function, single operation |
| **Recommended Tool** | Halmos (pure function, single call, Foundry project) |

**Property (English):** `mulDivDown(x, y, d)` returns `(x * y) / d` rounded down for all valid inputs, and reverts only when `d == 0` or when `x * y` overflows `uint256`.

**Property (Formal):**
- For all `x, y, d` where `d > 0` and `x * y <= type(uint256).max`:
  - `mulDivDown(x, y, d) == (x * y) / d`
- For `d == 0`: reverts
- For `x * y > type(uint256).max`: reverts

**Why it matters:** mulDivDown is the foundational arithmetic primitive used in every share conversion, interest calculation, and health check. If it ever returns an incorrect result, the entire protocol's accounting breaks.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {MathLib} from "src/libraries/MathLib.sol";

    contract MathLibMulDivDownTest is Test {
        using MathLib for uint256;

        /// @notice mulDivDown returns floor(x*y/d) when no overflow
        function check_mulDivDown_correctness(uint256 x, uint256 y, uint256 d) public pure {
            // Precondition: d != 0 and no overflow in x*y
            vm.assume(d > 0);
            vm.assume(y == 0 || x <= type(uint256).max / y);

            uint256 result = MathLib.mulDivDown(x, y, d);
            assert(result == (x * y) / d);
        }

        /// @notice mulDivDown reverts when d == 0
        function check_mulDivDown_reverts_on_zero_divisor(uint256 x, uint256 y) public {
            try this.callMulDivDown(x, y, 0) returns (uint256) {
                assert(false); // should not reach here
            } catch {
                // expected revert
            }
        }

        /// @notice mulDivDown result <= x when y <= d (scaling down property)
        function check_mulDivDown_scaling(uint256 x, uint256 y, uint256 d) public pure {
            vm.assume(d > 0);
            vm.assume(y <= d);
            vm.assume(y == 0 || x <= type(uint256).max / y);

            uint256 result = MathLib.mulDivDown(x, y, d);
            assert(result <= x);
        }

        /// @notice mulDivDown is zero when x or y is zero
        function check_mulDivDown_zero_input(uint256 x, uint256 d) public pure {
            vm.assume(d > 0);
            assert(MathLib.mulDivDown(x, 0, d) == 0);
            assert(MathLib.mulDivDown(0, x, d) == 0);
        }

        function callMulDivDown(uint256 x, uint256 y, uint256 d) external pure returns (uint256) {
            return MathLib.mulDivDown(x, y, d);
        }
    }

**Handoff Prompt:**
> Verify MathLib.mulDivDown using Halmos. The function at src/libraries/MathLib.sol line 50-52 computes `(x * y) / d`. Write Halmos tests that prove: (1) correctness for all non-overflowing inputs, (2) revert on d==0, (3) zero-input identity, (4) scaling property (result <= x when y <= d). Use the test template in magic/pre-audit/formal-verification-spec.md Property 1.1.

---

#### Property 1.2: mulDivUp Correctness and Relationship to mulDivDown

| Field | Value |
|-------|-------|
| **Name** | `mulDivUp_correctness` |
| **Target** | `src/libraries/MathLib.sol :: mulDivUp(uint256 x, uint256 y, uint256 d)` |
| **Property Type** | Equivalence + Bounds |
| **Priority** | CRITICAL |
| **Existing Coverage** | Certora LibSummary: direction only (`result * d >= x * y`) |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):** `mulDivUp(x, y, d)` returns `ceil((x * y) / d)` for all valid inputs, is always >= `mulDivDown(x, y, d)`, and the difference is at most 1 when `(x * y) % d != 0`.

**Property (Formal):**
- For all valid `x, y, d`: `mulDivUp(x, y, d) >= mulDivDown(x, y, d)`
- For all valid `x, y, d`: `mulDivUp(x, y, d) - mulDivDown(x, y, d) <= 1`
- For all valid `x, y, d` where `(x*y) % d == 0`: `mulDivUp(x, y, d) == mulDivDown(x, y, d)`
- For all valid `x, y, d` where `(x*y) % d != 0`: `mulDivUp(x, y, d) == mulDivDown(x, y, d) + 1`

**Why it matters:** mulDivUp is used for all "unfavorable to user" rounding in the protocol (borrow shares, withdrawal amounts). If the ceiling is wrong by even 1 wei in the wrong direction, users could extract value.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {MathLib} from "src/libraries/MathLib.sol";

    contract MathLibMulDivUpTest is Test {
        using MathLib for uint256;

        /// @notice mulDivUp >= mulDivDown always
        function check_mulDivUp_geq_mulDivDown(uint256 x, uint256 y, uint256 d) public pure {
            vm.assume(d > 0);
            vm.assume(y == 0 || x <= type(uint256).max / y);
            // Also guard against overflow in (x*y + d - 1)
            vm.assume(x * y <= type(uint256).max - (d - 1));

            uint256 up = MathLib.mulDivUp(x, y, d);
            uint256 down = MathLib.mulDivDown(x, y, d);
            assert(up >= down);
        }

        /// @notice Difference between up and down is at most 1
        function check_mulDivUp_minus_down_leq_1(uint256 x, uint256 y, uint256 d) public pure {
            vm.assume(d > 0);
            vm.assume(y == 0 || x <= type(uint256).max / y);
            vm.assume(x * y <= type(uint256).max - (d - 1));

            uint256 up = MathLib.mulDivUp(x, y, d);
            uint256 down = MathLib.mulDivDown(x, y, d);
            assert(up - down <= 1);
        }

        /// @notice When exactly divisible, up == down
        function check_mulDivUp_exact_division(uint256 x, uint256 y, uint256 d) public pure {
            vm.assume(d > 0);
            vm.assume(y == 0 || x <= type(uint256).max / y);
            vm.assume((x * y) % d == 0);

            uint256 up = MathLib.mulDivUp(x, y, d);
            uint256 down = MathLib.mulDivDown(x, y, d);
            assert(up == down);
        }

        /// @notice mulDivUp correctness: result == ceil(x*y/d)
        function check_mulDivUp_correctness(uint256 x, uint256 y, uint256 d) public pure {
            vm.assume(d > 0);
            vm.assume(y == 0 || x <= type(uint256).max / y);
            vm.assume(x * y <= type(uint256).max - (d - 1));

            uint256 result = MathLib.mulDivUp(x, y, d);
            uint256 product = x * y;
            uint256 expected = product / d + (product % d == 0 ? 0 : 1);
            assert(result == expected);
        }
    }

**Handoff Prompt:**
> Verify MathLib.mulDivUp using Halmos. Prove: (1) always >= mulDivDown, (2) difference is at most 1, (3) equals mulDivDown when exactly divisible, (4) matches ceil(x*y/d) reference. Use the template in formal-verification-spec.md Property 1.2.

---

#### Property 1.3: wMulDown / wDivDown / wDivUp WAD Consistency

| Field | Value |
|-------|-------|
| **Name** | `wad_operations_consistency` |
| **Target** | `src/libraries/MathLib.sol :: wMulDown, wDivDown, wDivUp` |
| **Property Type** | Equivalence + Identity |
| **Priority** | HIGH |
| **Existing Coverage** | None directly. Covered indirectly through mulDiv summaries. |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):**
- `wMulDown(x, y) == mulDivDown(x, y, WAD)` (delegation correctness)
- `wDivDown(x, y) == mulDivDown(x, WAD, y)` (delegation correctness)
- `wDivUp(x, y) == mulDivUp(x, WAD, y)` (delegation correctness)
- `wMulDown(x, WAD) == x` (identity: multiplying by 1.0 is identity)
- `wDivDown(x, WAD) == x` (identity: dividing by 1.0 is identity, when no overflow)
- `wMulDown(WAD, WAD) == WAD` (WAD is multiplicative identity)
- Roundtrip: `wDivDown(wMulDown(x, y), y) <= x` for valid inputs (no value creation)

**Why it matters:** WAD operations are the primary interface the protocol uses. If they don't correctly delegate to mulDiv with WAD=1e18, all interest rates and fee calculations break.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {MathLib, WAD} from "src/libraries/MathLib.sol";

    contract MathLibWadTest is Test {
        using MathLib for uint256;

        function check_wMulDown_delegates(uint256 x, uint256 y) public pure {
            vm.assume(y == 0 || x <= type(uint256).max / y);
            assert(x.wMulDown(y) == MathLib.mulDivDown(x, y, WAD));
        }

        function check_wDivDown_delegates(uint256 x, uint256 y) public pure {
            vm.assume(y > 0);
            vm.assume(x <= type(uint256).max / WAD);
            assert(x.wDivDown(y) == MathLib.mulDivDown(x, WAD, y));
        }

        function check_wDivUp_delegates(uint256 x, uint256 y) public pure {
            vm.assume(y > 0);
            vm.assume(x <= type(uint256).max / WAD);
            vm.assume(x * WAD <= type(uint256).max - (y - 1));
            assert(x.wDivUp(y) == MathLib.mulDivUp(x, WAD, y));
        }

        function check_wMulDown_identity(uint256 x) public pure {
            vm.assume(x <= type(uint256).max / WAD);
            assert(x.wMulDown(WAD) == x);
        }

        function check_wDivDown_identity(uint256 x) public pure {
            vm.assume(x <= type(uint256).max / WAD);
            assert(x.wDivDown(WAD) == x);
        }

        function check_wad_squared_is_wad() public pure {
            assert(WAD.wMulDown(WAD) == WAD);
        }

        /// @notice Roundtrip: dividing after multiplying cannot create value
        function check_wMulDown_wDivDown_roundtrip(uint256 x, uint256 y) public pure {
            vm.assume(y > 0);
            vm.assume(y <= type(uint256).max / WAD);
            vm.assume(y == 0 || x <= type(uint256).max / y);
            uint256 product = x.wMulDown(y);
            vm.assume(product <= type(uint256).max / WAD);
            uint256 result = product.wDivDown(y);
            assert(result <= x);
        }
    }

**Handoff Prompt:**
> Verify MathLib WAD operations using Halmos. Prove delegation correctness (wMulDown/wDivDown/wDivUp delegate to mulDiv with WAD), identity (WAD is multiplicative identity), and roundtrip safety (multiply-then-divide doesn't create value). Use template in formal-verification-spec.md Property 1.3.

---

#### Property 1.4: wTaylorCompounded Monotonicity and Bounds

| Field | Value |
|-------|-------|
| **Name** | `wTaylorCompounded_properties` |
| **Target** | `src/libraries/MathLib.sol :: wTaylorCompounded(uint256 x, uint256 n)` |
| **Property Type** | Monotonicity + Bounds |
| **Priority** | HIGH |
| **Existing Coverage** | **None** -- Certora treats this as `NONDET` (ghost function) |
| **Estimated Effort** | Medium (1-4hr) -- complex math, overflow edge cases |
| **Recommended Tool** | Halmos for properties; fuzzing as stepping stone |

**Property (English):**
- Monotonic in `x`: for fixed `n`, if `x1 <= x2` then `wTaylorCompounded(x1, n) <= wTaylorCompounded(x2, n)` (higher rate = more interest)
- Monotonic in `n`: for fixed `x`, if `n1 <= n2` then `wTaylorCompounded(x1, n1) <= wTaylorCompounded(x, n2)` (more time = more interest)
- Lower bound: `wTaylorCompounded(x, n) >= x * n` (at least linear interest)
- Zero cases: `wTaylorCompounded(0, n) == 0` and `wTaylorCompounded(x, 0) == 0`
- Practical bound: for `x * n <= WAD` (rate*time <= 100%): `wTaylorCompounded(x, n) <= 2 * x * n` (at most double linear for reasonable rates)

**Why it matters:** wTaylorCompounded determines ALL interest accrual in the protocol. Certora explicitly treats it as NONDET, meaning its mathematical properties are **completely unverified**. A bug here could cause interest to decrease over time or overflow.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {MathLib, WAD} from "src/libraries/MathLib.sol";

    contract WTaylorCompoundedTest is Test {
        using MathLib for uint256;

        /// @notice Zero rate or zero time = zero interest
        function check_wTaylor_zero_cases(uint256 x, uint256 n) public pure {
            assert(MathLib.wTaylorCompounded(0, n) == 0);
            assert(MathLib.wTaylorCompounded(x, 0) == 0);
        }

        /// @notice Monotonic in rate: higher rate => more interest
        function check_wTaylor_monotonic_x(uint256 x1, uint256 x2, uint256 n) public pure {
            vm.assume(x1 <= x2);
            // Bound to avoid overflow: x*n must not overflow, and squared terms must fit
            vm.assume(n > 0);
            vm.assume(x2 <= type(uint128).max);
            vm.assume(n <= type(uint128).max);
            vm.assume(x2 * n <= type(uint256).max / (x2 * n / WAD + 1));

            // Guard against overflow in the function itself
            uint256 firstTerm2 = x2 * n;
            vm.assume(firstTerm2 <= type(uint128).max); // keep secondTerm computable

            uint256 result1 = MathLib.wTaylorCompounded(x1, n);
            uint256 result2 = MathLib.wTaylorCompounded(x2, n);
            assert(result1 <= result2);
        }

        /// @notice Monotonic in time: more time => more interest
        function check_wTaylor_monotonic_n(uint256 x, uint256 n1, uint256 n2) public pure {
            vm.assume(n1 <= n2);
            vm.assume(x > 0);
            vm.assume(x <= type(uint128).max);
            vm.assume(n2 <= type(uint128).max);

            uint256 firstTerm2 = x * n2;
            vm.assume(firstTerm2 <= type(uint128).max);

            uint256 result1 = MathLib.wTaylorCompounded(x, n1);
            uint256 result2 = MathLib.wTaylorCompounded(x, n2);
            assert(result1 <= result2);
        }

        /// @notice Result >= linear term (x*n), i.e., compound >= simple interest
        function check_wTaylor_lower_bound(uint256 x, uint256 n) public pure {
            vm.assume(x > 0 && n > 0);
            vm.assume(x <= type(uint128).max);
            vm.assume(n <= type(uint128).max);
            uint256 firstTerm = x * n;
            vm.assume(firstTerm <= type(uint128).max);

            uint256 result = MathLib.wTaylorCompounded(x, n);
            assert(result >= firstTerm);
        }
    }

**Handoff Prompt:**
> Verify MathLib.wTaylorCompounded using Halmos. This is the MOST important gap in existing verification -- Certora treats it as NONDET. Prove: (1) zero cases, (2) monotonicity in rate, (3) monotonicity in time, (4) result >= linear term (x*n). Be careful with overflow bounds -- the function uses unchecked multiplications. Use template in formal-verification-spec.md Property 1.4.

---

### Group 2: SharesMathLib (CRITICAL)

#### Property 2.1: toSharesDown / toAssetsDown Roundtrip Safety

| Field | Value |
|-------|-------|
| **Name** | `shares_roundtrip_no_value_creation` |
| **Target** | `src/libraries/SharesMathLib.sol :: toSharesDown, toAssetsDown` |
| **Property Type** | Roundtrip |
| **Priority** | CRITICAL |
| **Existing Coverage** | Protocol-level (ExactMath.spec: supplyWithdraw, borrowRepay). Not isolated library verification. |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):**
- Converting assets to shares (down) and back to assets (down) never creates value: `toAssetsDown(toSharesDown(assets, tA, tS), tA, tS) <= assets`
- Converting shares to assets (down) and back to shares (down) never creates value: `toSharesDown(toAssetsDown(shares, tA, tS), tA, tS) <= shares`
- Converting assets to shares (up) and back to assets (up) never loses more than 1: `toAssetsUp(toSharesUp(assets, tA, tS), tA, tS) >= assets`

**Why it matters:** This is the core property preventing value extraction. If a roundtrip creates value, attackers can drain the protocol by repeatedly converting between shares and assets.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {SharesMathLib} from "src/libraries/SharesMathLib.sol";
    import {MathLib} from "src/libraries/MathLib.sol";

    contract SharesMathRoundtripTest is Test {
        using SharesMathLib for uint256;

        /// @notice assets -> sharesDown -> assetsDown never creates value
        function check_roundtrip_down_no_value_creation(
            uint256 assets, uint256 totalAssets, uint256 totalShares
        ) public pure {
            // Bound to uint128 to match protocol constraints
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(assets <= type(uint128).max);

            uint256 shares = assets.toSharesDown(totalAssets, totalShares);
            uint256 assetsBack = shares.toAssetsDown(totalAssets, totalShares);
            assert(assetsBack <= assets);
        }

        /// @notice shares -> assetsDown -> sharesDown never creates value
        function check_roundtrip_shares_down_no_value_creation(
            uint256 shares, uint256 totalAssets, uint256 totalShares
        ) public pure {
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(shares <= type(uint128).max);

            uint256 assets = shares.toAssetsDown(totalAssets, totalShares);
            uint256 sharesBack = assets.toSharesDown(totalAssets, totalShares);
            assert(sharesBack <= shares);
        }

        /// @notice assets -> sharesUp -> assetsUp is >= original (conservative rounding)
        function check_roundtrip_up_conservative(
            uint256 assets, uint256 totalAssets, uint256 totalShares
        ) public pure {
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(assets <= type(uint128).max);
            // Guard overflow in mulDivUp
            vm.assume(totalAssets + 1 > 0); // always true but explicit
            vm.assume(totalShares + 1e6 > 0); // always true

            uint256 shares = assets.toSharesUp(totalAssets, totalShares);
            // Guard overflow for second conversion
            vm.assume(shares <= type(uint128).max);

            uint256 assetsBack = shares.toAssetsUp(totalAssets, totalShares);
            assert(assetsBack >= assets);
        }
    }

**Handoff Prompt:**
> Verify SharesMathLib roundtrip properties using Halmos. Prove: (1) assets->sharesDown->assetsDown <= original, (2) shares->assetsDown->sharesDown <= original, (3) assets->sharesUp->assetsUp >= original. These are the core no-value-extraction properties. Use template in formal-verification-spec.md Property 2.1.

---

#### Property 2.2: SharesMathLib Monotonicity

| Field | Value |
|-------|-------|
| **Name** | `shares_monotonicity` |
| **Target** | `src/libraries/SharesMathLib.sol :: all four functions` |
| **Property Type** | Monotonicity |
| **Priority** | HIGH |
| **Existing Coverage** | None directly |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):**
- `toSharesDown` is monotonically non-decreasing in `assets`: more assets = more shares
- `toAssetsDown` is monotonically non-decreasing in `shares`: more shares = more assets
- `toSharesDown(assets, tA, tS) <= toSharesUp(assets, tA, tS)`: up rounding >= down rounding
- `toAssetsDown(shares, tA, tS) <= toAssetsUp(shares, tA, tS)`: up rounding >= down rounding

**Why it matters:** If converting more assets somehow yields fewer shares, the protocol's incentive structure breaks. Suppliers who deposit more should always get at least as many shares.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {SharesMathLib} from "src/libraries/SharesMathLib.sol";
    import {MathLib} from "src/libraries/MathLib.sol";

    contract SharesMathMonotonicityTest is Test {
        using SharesMathLib for uint256;

        /// @notice More assets => more shares (toSharesDown)
        function check_toSharesDown_monotonic(
            uint256 assets1, uint256 assets2, uint256 totalAssets, uint256 totalShares
        ) public pure {
            vm.assume(assets1 <= assets2);
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(assets2 <= type(uint128).max);

            uint256 shares1 = assets1.toSharesDown(totalAssets, totalShares);
            uint256 shares2 = assets2.toSharesDown(totalAssets, totalShares);
            assert(shares1 <= shares2);
        }

        /// @notice More shares => more assets (toAssetsDown)
        function check_toAssetsDown_monotonic(
            uint256 shares1, uint256 shares2, uint256 totalAssets, uint256 totalShares
        ) public pure {
            vm.assume(shares1 <= shares2);
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(shares2 <= type(uint128).max);

            uint256 assets1 = shares1.toAssetsDown(totalAssets, totalShares);
            uint256 assets2 = shares2.toAssetsDown(totalAssets, totalShares);
            assert(assets1 <= assets2);
        }

        /// @notice toSharesUp >= toSharesDown for same inputs
        function check_toSharesUp_geq_toSharesDown(
            uint256 assets, uint256 totalAssets, uint256 totalShares
        ) public pure {
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(assets <= type(uint128).max);

            uint256 sharesDown = assets.toSharesDown(totalAssets, totalShares);
            uint256 sharesUp = assets.toSharesUp(totalAssets, totalShares);
            assert(sharesUp >= sharesDown);
        }

        /// @notice toAssetsUp >= toAssetsDown for same inputs
        function check_toAssetsUp_geq_toAssetsDown(
            uint256 shares, uint256 totalAssets, uint256 totalShares
        ) public pure {
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(shares <= type(uint128).max);

            uint256 assetsDown = shares.toAssetsDown(totalAssets, totalShares);
            uint256 assetsUp = shares.toAssetsUp(totalAssets, totalShares);
            assert(assetsUp >= assetsDown);
        }
    }

**Handoff Prompt:**
> Verify SharesMathLib monotonicity using Halmos. Prove: (1) toSharesDown monotonic in assets, (2) toAssetsDown monotonic in shares, (3) Up rounding >= Down rounding for both. Use template in formal-verification-spec.md Property 2.2.

---

#### Property 2.3: SharesMathLib Virtual Shares Protection

| Field | Value |
|-------|-------|
| **Name** | `virtual_shares_prevent_zero_division` |
| **Target** | `src/libraries/SharesMathLib.sol :: all four functions` |
| **Property Type** | Bounds / Identity |
| **Priority** | HIGH |
| **Existing Coverage** | Implied by protocol-level specs but not independently verified |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):**
- No division by zero is possible: virtual shares (1e6) and virtual assets (1) ensure denominators are always > 0
- Empty market behaves correctly: `toSharesDown(assets, 0, 0)` returns `assets * 1e6 / 1` = `assets * 1e6`
- First depositor gets proportional shares

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {SharesMathLib} from "src/libraries/SharesMathLib.sol";

    contract SharesMathVirtualTest is Test {
        using SharesMathLib for uint256;

        /// @notice Empty market: first deposit gets assets * VIRTUAL_SHARES / VIRTUAL_ASSETS
        function check_empty_market_shares(uint256 assets) public pure {
            vm.assume(assets <= type(uint128).max);
            vm.assume(assets <= type(uint256).max / 1e6); // prevent overflow

            uint256 shares = assets.toSharesDown(0, 0);
            // Expected: assets * (0 + 1e6) / (0 + 1) = assets * 1e6
            assert(shares == assets * 1e6);
        }

        /// @notice Empty market (reverse): shares convert back to roughly same assets
        function check_empty_market_assets(uint256 shares) public pure {
            vm.assume(shares <= type(uint128).max);

            uint256 assets = shares.toAssetsDown(0, 0);
            // Expected: shares * (0 + 1) / (0 + 1e6) = shares / 1e6
            assert(assets == shares / 1e6);
        }

        /// @notice Functions never revert (no division by zero) for valid inputs
        function check_no_revert(uint256 x, uint256 totalAssets, uint256 totalShares) public pure {
            vm.assume(totalAssets <= type(uint128).max);
            vm.assume(totalShares <= type(uint128).max);
            vm.assume(x <= type(uint128).max);

            // These should all succeed without revert
            x.toSharesDown(totalAssets, totalShares);
            x.toAssetsDown(totalAssets, totalShares);
            x.toSharesUp(totalAssets, totalShares);
            x.toAssetsUp(totalAssets, totalShares);
        }
    }

**Handoff Prompt:**
> Verify SharesMathLib virtual share protection using Halmos. Prove: (1) empty market gives assets*1e6 shares, (2) reverse conversion is consistent, (3) no function can revert due to division by zero. Use template in formal-verification-spec.md Property 2.3.

---

### Group 3: UtilsLib (HIGH)

#### Property 3.1: exactlyOneZero Truth Table

| Field | Value |
|-------|-------|
| **Name** | `exactlyOneZero_truth_table` |
| **Target** | `src/libraries/UtilsLib.sol :: exactlyOneZero(uint256 x, uint256 y)` |
| **Property Type** | Equivalence |
| **Priority** | HIGH |
| **Existing Coverage** | Used in Reverts.spec but not independently verified against reference |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):** The assembly implementation matches the reference: returns `true` iff exactly one of `x` and `y` is zero.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {UtilsLib} from "src/libraries/UtilsLib.sol";

    contract ExactlyOneZeroTest is Test {

        /// @notice Assembly matches reference implementation
        function check_exactlyOneZero_matches_reference(uint256 x, uint256 y) public pure {
            bool result = UtilsLib.exactlyOneZero(x, y);
            bool expected = (x == 0) != (y == 0);
            assert(result == expected);
        }
    }

**Handoff Prompt:**
> Verify UtilsLib.exactlyOneZero using Halmos. Prove the assembly implementation matches `(x == 0) != (y == 0)` for all uint256 inputs. Single test function, should be very fast. Use template in formal-verification-spec.md Property 3.1.

---

#### Property 3.2: zeroFloorSub Reference Match

| Field | Value |
|-------|-------|
| **Name** | `zeroFloorSub_reference_match` |
| **Target** | `src/libraries/UtilsLib.sol :: zeroFloorSub(uint256 x, uint256 y)` |
| **Property Type** | Equivalence |
| **Priority** | HIGH |
| **Existing Coverage** | Not independently verified |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):** The assembly implementation returns `max(0, x - y)` for all inputs.

**Halmos Test Template:**

    // SPDX-License-Identifier: GPL-2.0-or-later
    pragma solidity ^0.8.0;

    import {Test} from "forge-std/Test.sol";
    import {UtilsLib} from "src/libraries/UtilsLib.sol";

    contract ZeroFloorSubTest is Test {

        /// @notice Assembly matches reference: max(0, x - y)
        function check_zeroFloorSub_reference(uint256 x, uint256 y) public pure {
            uint256 result = UtilsLib.zeroFloorSub(x, y);
            uint256 expected = x > y ? x - y : 0;
            assert(result == expected);
        }

        /// @notice Result is always <= x
        function check_zeroFloorSub_bounded(uint256 x, uint256 y) public pure {
            uint256 result = UtilsLib.zeroFloorSub(x, y);
            assert(result <= x);
        }

        /// @notice When y == 0, result == x
        function check_zeroFloorSub_identity(uint256 x) public pure {
            assert(UtilsLib.zeroFloorSub(x, 0) == x);
        }

        /// @notice When x <= y, result == 0
        function check_zeroFloorSub_zero_floor(uint256 x, uint256 y) public pure {
            vm.assume(x <= y);
            assert(UtilsLib.zeroFloorSub(x, y) == 0);
        }
    }

**Handoff Prompt:**
> Verify UtilsLib.zeroFloorSub using Halmos. Prove: (1) matches max(0, x-y) reference, (2) result <= x, (3) identity when y=0, (4) returns 0 when x<=y. Use template in formal-verification-spec.md Property 3.2.

---

#### Property 3.3: min Reference Match

| Field | Value |
|-------|-------|
| **Name** | `min_reference_match` |
| **Target** | `src/libraries/UtilsLib.sol :: min(uint256 x, uint256 y)` |
| **Property Type** | Equivalence |
| **Priority** | MEDIUM |
| **Existing Coverage** | **Already verified** in Certora LibSummary.spec (checkSummaryMin) |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos (supplementary to existing Certora proof) |

**Property:** Assembly `min(x,y)` matches reference `x < y ? x : y`.

**Note:** Already covered by Certora. Include in Halmos suite for defense-in-depth.

**Halmos Test Template:**

    function check_min_reference(uint256 x, uint256 y) public pure {
        uint256 result = UtilsLib.min(x, y);
        uint256 expected = x < y ? x : y;
        assert(result == expected);
    }

---

#### Property 3.4: toUint128 Boundary Behavior

| Field | Value |
|-------|-------|
| **Name** | `toUint128_boundary` |
| **Target** | `src/libraries/UtilsLib.sol :: toUint128(uint256 x)` |
| **Property Type** | Revert + Equivalence |
| **Priority** | MEDIUM |
| **Existing Coverage** | Implicitly covered by protocol-level specs |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos |

**Property (English):**
- For `x <= type(uint128).max`: returns `uint128(x)` (lossless cast)
- For `x > type(uint128).max`: reverts

**Halmos Test Template:**

    function check_toUint128_lossless(uint256 x) public pure {
        vm.assume(x <= type(uint128).max);
        uint128 result = UtilsLib.toUint128(x);
        assert(uint256(result) == x);
    }

    function check_toUint128_reverts_on_overflow(uint256 x) public {
        vm.assume(x > type(uint128).max);
        try this.callToUint128(x) returns (uint128) {
            assert(false);
        } catch {
            // expected
        }
    }

    function callToUint128(uint256 x) external pure returns (uint128) {
        return UtilsLib.toUint128(x);
    }

---

### Group 4: MarketParamsLib (MEDIUM)

#### Property 4.1: id() Determinism and Collision Resistance

| Field | Value |
|-------|-------|
| **Name** | `id_determinism_collision_resistance` |
| **Target** | `src/libraries/MarketParamsLib.sol :: id(MarketParams memory)` |
| **Property Type** | Equivalence + Identity |
| **Priority** | MEDIUM |
| **Existing Coverage** | **Already verified** in Certora LibSummary.spec and ConsistentState.spec (libIdUnique) |
| **Estimated Effort** | Small (<1hr) |
| **Recommended Tool** | Halmos (supplementary) |

**Property:** `id(marketParams)` equals `keccak256(abi.encode(marketParams))`. Different params produce different IDs (collision resistance is inherent to keccak256 and verified by Certora's `libIdUnique` rule).

**Note:** Already well-covered by Certora. Low priority for Halmos.

---

## Verification Plan

### Phase 1: Quick Wins (Estimated: 2-4 hours total)

These are pure functions with simple implementations. Halmos should prove them instantly.

| # | Property | Library | Priority | Effort | Existing? |
|---|----------|---------|----------|--------|-----------|
| 1 | `exactlyOneZero` truth table (3.1) | UtilsLib | HIGH | <30min | No |
| 2 | `zeroFloorSub` reference match (3.2) | UtilsLib | HIGH | <30min | No |
| 3 | `min` reference match (3.3) | UtilsLib | MEDIUM | <30min | Yes (Certora) |
| 4 | `toUint128` boundary (3.4) | UtilsLib | MEDIUM | <30min | Implicit |
| 5 | `mulDivDown` correctness (1.1) | MathLib | CRITICAL | <1hr | Partial (Certora direction-only) |
| 6 | `mulDivUp` correctness + relationship (1.2) | MathLib | CRITICAL | <1hr | Partial (Certora direction-only) |

**Expected outcome:** All 6 properties verified. UtilsLib and MathLib core arithmetic fully trusted.

### Phase 2: Medium Effort (Estimated: 3-5 hours total)

Share conversion math requires careful overflow guards.

| # | Property | Library | Priority | Effort | Existing? |
|---|----------|---------|----------|--------|-----------|
| 7 | WAD operations consistency (1.3) | MathLib | HIGH | 1hr | No |
| 8 | SharesMath roundtrip safety (2.1) | SharesMathLib | CRITICAL | 1-2hr | Protocol-level only |
| 9 | SharesMath monotonicity (2.2) | SharesMathLib | HIGH | 1hr | No |
| 10 | SharesMath virtual shares (2.3) | SharesMathLib | HIGH | <1hr | No |

**Expected outcome:** Share conversion math fully trusted. Auditors can skip manual review of share inflation attack protection.

### Phase 3: Larger Effort (Estimated: 2-4 hours)

wTaylorCompounded has complex overflow behavior.

| # | Property | Library | Priority | Effort | Existing? |
|---|----------|---------|----------|--------|-----------|
| 11 | wTaylorCompounded properties (1.4) | MathLib | HIGH | 2-4hr | **None** (NONDET in Certora) |

**Expected outcome:** Interest accrual math trusted. This is the biggest verification gap -- Certora completely abstracted this function.

### Phase 4: Defense-in-Depth (Optional, 1-2 hours)

| # | Property | Library | Priority | Effort | Existing? |
|---|----------|---------|----------|--------|-----------|
| 12 | MarketParamsLib.id determinism (4.1) | MarketParamsLib | MEDIUM | <30min | Yes (Certora) |

---

## Setup Instructions

### Halmos Setup

    # Install Halmos (requires Python 3.11+)
    pip install halmos

    # Run all check_ prefixed tests
    halmos --root /home/sirius/coding/recon/morpho-blue --contract MathLibMulDivDownTest

    # Run specific test
    halmos --root /home/sirius/coding/recon/morpho-blue --function check_mulDivDown_correctness

    # With timeout (some properties may need more time)
    halmos --root /home/sirius/coding/recon/morpho-blue --solver-timeout-assertion 300000

    # With loop unrolling for wTaylorCompounded
    halmos --root /home/sirius/coding/recon/morpho-blue --loop 4

**Recommended test file location:** `test/halmos/` directory (create if needed)

**File structure:**

    test/halmos/
    +-- MathLibMulDivDownTest.sol    (Property 1.1)
    +-- MathLibMulDivUpTest.sol      (Property 1.2)
    +-- MathLibWadTest.sol           (Property 1.3)
    +-- WTaylorCompoundedTest.sol    (Property 1.4)
    +-- SharesMathRoundtripTest.sol  (Property 2.1)
    +-- SharesMathMonotonicityTest.sol (Property 2.2)
    +-- SharesMathVirtualTest.sol    (Property 2.3)
    +-- UtilsLibTest.sol             (Properties 3.1-3.4)

### Certora Setup (Existing)

    # Install Certora CLI
    pip install certora-cli

    # Set API key
    export CERTORAKEY=<your-key>

    # Run existing specs (from project root)
    certoraRun certora/confs/LibSummary.conf
    certoraRun certora/confs/ExactMath.conf
    certoraRun certora/confs/ExchangeRate.conf

    # Run specific rule
    certoraRun certora/confs/LibSummary.conf --rule checkSummaryMulDivDown

### Echidna/Medusa Setup (Existing)

    # Echidna
    echidna . --config echidna.yaml --contract CryticTester

    # Medusa
    medusa fuzz --config medusa.json

**Note:** The fuzzing harness is set up but property assertions are not yet implemented. Properties from this spec could be adapted as fuzzing assertions as a stepping stone before formal verification.

---

## Appendix: Property Cross-Reference with Certora

This table maps each proposed Halmos property to its Certora equivalent (if any), explaining why both are valuable.

| Halmos Property | Certora Equivalent | Why Both Matter |
|----------------|-------------------|-----------------|
| 1.1 mulDivDown correctness | LibSummary: `checkSummaryMulDivDown` (direction only) | Certora proves `result*d <= x*y`. Halmos proves `result == (x*y)/d` exactly. Certora's proof is weaker. |
| 1.2 mulDivUp correctness | LibSummary: `checkSummaryMulDivUp` (direction only) | Same gap as above. |
| 1.3 WAD operations | None | Not covered at all. |
| 1.4 wTaylorCompounded | None (NONDET) | **Biggest gap.** Certora completely abstracts this. |
| 2.1 Share roundtrips | ExactMath: `supplyWithdraw`, `borrowRepay` (protocol-level) | Certora proves at protocol level with state. Halmos proves at library level, more isolated. |
| 2.2 Share monotonicity | None | Not covered. |
| 2.3 Virtual shares | None | Not covered. |
| 3.1 exactlyOneZero | Used in Reverts.spec (not independently verified) | Certora trusts it; Halmos proves it. |
| 3.2 zeroFloorSub | None | Not covered. |
| 3.3 min | LibSummary: `checkSummaryMin` | Already covered. Defense-in-depth. |
| 3.4 toUint128 | Implicit | Not independently verified. |
| 4.1 id() | LibSummary: `checkSummaryId` + ConsistentState: `libIdUnique` | Already well covered. |

# KB Generation Prompts

Each step below is **completely independent** but optimized for sequential execution.

---

## Source Directory Detection

Before reading source files, detect the source directory:

1. Check common directories: `src/`, `contracts/`, `source/`, root `.sol` files
2. Check config files: `foundry.toml` → `src = "..."`, `hardhat.config.*` → `sources`
3. Use whichever exists. If multiple, check all.

---

## Prompt for Step 1: Information Gathering (Cache for All Steps)

**Goal:** Create kb/1-informationNeededForSteps.md - A cache of ALL raw data needed by ALL subsequent steps (2-7).

**Execution:**
1. Detect project type (Foundry/Hardhat)
2. Detect source directory
3. Glob ALL .sol files in {src} (exclude lib/, node_modules/)
4. Glob ALL test files in test/, tests/
5. For EACH .sol file in {src}, extract and store:
   - File path
   - Contract/interface/library name
   - NatSpec description (first @notice or @title)
   - All `import` statements
   - Inheritance (`contract X is Y, Z`)
   - Library usage (`using X for Y`)
   - Constructor signature and parameters
   - Immutable variables
   - All modifiers defined (with their logic)
   - All state variables
   - Runtime external calls (interface invocations)
   - **For EACH function (including internal/private for Step 6):**
     - Full signature (name, params, visibility, modifiers, returns)
     - NatSpec (@notice, @param, @return)
     - All require/revert conditions
     - State variables read
     - State variables written
     - Events emitted
     - Internal functions called
     - External calls made
6. For EACH test file, extract:
   - setUp() function content
7. Read README.md if exists

**Output format (optimized for AI parsing, not human reading):**

    ---
    META
    project_type: Foundry
    source_dir: src/
    test_dir: test/
    ---

    FILE: src/Contract.sol
    TYPE: contract
    NAME: Contract
    DESC: Main protocol contract
    IMPORTS:
    - ./interfaces/IFoo.sol
    - ./libraries/Bar.sol
    INHERITS: IFoo, Base
    USES:
    - MathLib for uint256
    - SafeTransferLib for IERC20
    CONSTRUCTOR: (address owner, address oracle)
    IMMUTABLES:
    - DOMAIN_SEPARATOR: bytes32
    MODIFIERS:
    - onlyOwner: require(msg.sender == owner, "not owner")
    STATE:
    - owner: address
    - balances: mapping(address => uint256)
    - totalSupply: uint256

    FUNC: supply
    SIG: function supply(MarketParams memory params, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256, uint256)
    VISIBILITY: external
    MODIFIERS: none
    NATSPEC: @notice Supplies assets to a market
    REQUIRES:
    - require(market[id].lastUpdate != 0, "market not created")
    - require(exactlyOneZero(assets, shares), "inconsistent input")
    - require(onBehalf != address(0), "zero address")
    READS: market[id], position[id][onBehalf]
    WRITES: position[id][onBehalf].supplyShares, market[id].totalSupplyShares, market[id].totalSupplyAssets
    EVENTS: EventsLib.Supply(id, msg.sender, onBehalf, assets, shares)
    INTERNAL_CALLS: _accrueInterest(params, id)
    EXTERNAL_CALLS: IERC20(params.loanToken).safeTransferFrom(), IMorphoSupplyCallback(msg.sender).onMorphoSupply()
    ---

    FUNC: _accrueInterest
    SIG: function _accrueInterest(MarketParams memory params, Id id) internal
    VISIBILITY: internal
    ...
    ---

    FILE: src/interfaces/IFoo.sol
    TYPE: interface
    NAME: IFoo
    DESC: Interface for Foo
    FUNC: price
    SIG: function price() external view returns (uint256)
    ...
    ---

    FILE: test/Contract.t.sol
    SETUP:
    ```
    function setUp() public {
        token = new ERC20Mock();
        oracle = new OracleMock();
        contract = new Contract(address(this), address(oracle));
        contract.enableFeature(true);
    }
    ```
    ---

    README:
    [First 500 lines or full content if shorter]
    ---

---

## Prompt for Step 2: Contract Discovery

**Goal:** Create kb/2-contractsList.md

**Required data from cache:** META (project_type, source_dir), FILE sections (paths, TYPE, NAME, DESC)

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if it contains META section with project_type and source_dir
        3. Check if it contains at least one FILE section with TYPE, NAME, DESC
        IF all checks pass:
            Parse and use cached data
            Categorize by TYPE and path patterns
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect project type: check for foundry.toml or hardhat.config.*
        2. Detect source directory
        3. Glob for all .sol files in {src}
        4. EXCLUDE: mocks/, lib/, node_modules/
        5. Read each file to get NatSpec description
        6. Categorize: Core, Interfaces, Libraries, Periphery

**Output format:**

    # Protocol Contracts

    ## Project Type
    [Foundry/Hardhat]

    ## Source Directory
    [detected source dir]

    ## Core Contracts
    - `path/to/Contract.sol` - [1-line description]

    ## Interfaces
    - `path/to/IContract.sol` - [description]

    ## Libraries
    - `path/to/Lib.sol` - [description]

    ## Periphery
    - `path/to/Helper.sol` - [description]

    ---
    Total: X contracts

---

## Prompt for Step 3: Dependencies & Deployment Pattern

**Goal:** Create kb/3a-dependencyList.md and kb/3b-deploymentPattern.md

### Part A: Dependency Analysis (3a-dependencyList.md)

**Required data from cache:** FILE sections with IMPORTS, INHERITS, USES, EXTERNAL_CALLS, CONSTRUCTOR

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if FILE sections contain IMPORTS, INHERITS, USES, CONSTRUCTOR
        3. Check if at least one FILE has FUNC sections with EXTERNAL_CALLS
        IF all checks pass:
            Parse and use cached data
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect source directory
        2. Glob for .sol files in {src}
        3. For each file, extract:
           - `import` statements
           - `contract X is Y` inheritance
           - `using X for Y` library usage
           - Runtime interface calls
           - Constructor parameters

Build dependency table and mermaid graph.

**Output format:**

    # Dependency Analysis

    ## Contract: ContractName
    **File:** `path/to/Contract.sol`

    | Type | Dependency | Purpose |
    |------|------------|---------|
    | Import | LibName | Math operations |
    | Inherits | IContract | Interface |
    | Uses | LibX for TypeY | Extensions |
    | Calls | IOracle | Runtime call |
    | Constructor | address param | Deploy param |

    ## Dependency Graph

    ```mermaid
    graph TD
        Contract --> Library1
        Contract --> Interface1
    ```

### Part B: Deployment Pattern (3b-deploymentPattern.md)

**Required data from cache:** FILE sections with CONSTRUCTOR, IMMUTABLES, MODIFIERS, FUNC sections with VISIBILITY=external; SETUP sections from test files

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if FILE sections contain CONSTRUCTOR and FUNC sections
        3. Check if at least one SETUP section exists (test file)
        IF all checks pass:
            Parse CONSTRUCTOR, IMMUTABLES, MODIFIERS
            Parse FUNC sections for external functions with admin modifiers
            Parse SETUP sections for deployment order
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect source directory
        2. Glob for .sol files in {src}
        3. ALSO glob test/, tests/ for setUp() functions
        4. Find deployable contracts (not interfaces/libraries)
        5. Extract: constructor, immutables, onlyOwner functions, initialize
        6. Read test setUp() to see deployment order

**Output format:**

    # Deployment Pattern

    ## Deployment Order

    ### Phase 1: External Dependencies
    - [External contracts needed]

    ### Phase 2: Protocol Contracts
    - `Contract` - [what it needs]

    ## Constructor Parameters

    ### ContractName
    | Parameter | Type | Source |
    |-----------|------|--------|
    | owner | address | Deployer |

    ## Post-Deployment Setup
    | Contract | Function | Purpose |
    |----------|----------|---------|
    | Contract | setupFunc() | Configure X |

    ## Deployment Diagram

    ```mermaid
    graph LR
        External --> Protocol
    ```

---

## Prompt for Step 4: Charts & Flows

**Goal:** Create kb/4a-setupCharts.md, kb/4b-roleCharts.md, and kb/4c-usageFlows.md

### Part A: Setup Charts (4a-setupCharts.md)

**Required data from cache:** CONSTRUCTOR, FUNC sections (filter by MODIFIERS containing onlyOwner), SETUP sections

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if FILE sections contain CONSTRUCTOR and FUNC sections
        3. Check if SETUP sections exist
        IF all checks pass:
            Parse CONSTRUCTOR
            Parse FUNC sections, filter for admin/setup functions
            Parse SETUP sections
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect source directory
        2. Glob for main contract files in {src}
        3. ALSO read test setUp() functions
        4. Read constructor and find setup/config functions

Map: deployment → configuration → operational states.

**Output format:**

    # Setup Charts

    ## Deployment Sequence

    ```mermaid
    sequenceDiagram
        participant Deployer
        participant Contract
        Deployer->>Contract: constructor(params)
        Deployer->>Contract: setupFunction()
    ```

    ## Configuration State Machine

    ```mermaid
    stateDiagram-v2
        [*] --> Deployed
        Deployed --> Configured: setup calls
        Configured --> Active: create market
    ```

    ## Market/Pool Creation Flow

    ```mermaid
    flowchart TD
        A[createMarket] --> B{Precondition?}
        B -->|No| C[Revert]
        B -->|Yes| D[Create]
    ```

### Part B: Role Charts (4b-roleCharts.md)

**Required data from cache:** MODIFIERS, FUNC sections (with MODIFIERS field showing access control)

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if FILE sections contain MODIFIERS
        3. Check if FUNC sections have MODIFIERS field
        IF all checks pass:
            Parse MODIFIERS definitions
            Parse FUNC sections, group by MODIFIERS
            Extract role patterns
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect source directory
        2. Glob for .sol files in {src}
        3. Grep for: `modifier`, `onlyOwner`, `require(msg.sender`, `isAuthorized`
        4. Read each contract, list all external functions
        5. Map each function to required role

**Output format:**

    # Role Charts

    ## Roles Identified

    | Role | Description | How Assigned |
    |------|-------------|--------------|
    | Owner | Admin | constructor/setOwner |
    | Authorized | Delegated | setAuthorization |
    | Anyone | Permissionless | - |

    ## Permission Matrix

    | Function | Owner | Authorized | Anyone |
    |----------|-------|------------|--------|
    | adminFunc | ✅ | ❌ | ❌ |
    | userFunc | ❌ | ✅ | ✅ |

    ## Role Hierarchy

    ```mermaid
    graph TD
        Owner --> Authorized
        Authorized --> Anyone
    ```

### Part C: Usage Flows (4c-usageFlows.md)

**Required data from cache:** FUNC sections (VISIBILITY=external, with INTERNAL_CALLS, EXTERNAL_CALLS, EVENTS), SETUP; NOTE: detailed flow logic may require source

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if FUNC sections contain EXTERNAL_CALLS, INTERNAL_CALLS, EVENTS
        IF checks pass:
            Parse FUNC sections for user-facing operations
            Use EXTERNAL_CALLS for token transfers, callbacks
            Use INTERNAL_CALLS for flow tracing
            Parse SETUP for usage examples
            NOTE: If flow details insufficient, read source for specific functions
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect source directory
        2. Glob for main contract files in {src}
        3. ALSO read test files for usage patterns
        4. List all external/public non-view functions
        5. Trace: internal calls, token transfers, events, callbacks

**Output format:**

    # Usage Flows

    ## Overview

    | Operation | Function | Actors | Callback |
    |-----------|----------|--------|----------|
    | Supply | supply() | User | Optional |
    | Borrow | borrow() | Borrower | No |

    ## Supply Flow

    ```mermaid
    sequenceDiagram
        participant User
        participant Contract
        participant Token

        User->>Contract: supply(amount)
        Contract->>Contract: accrueInterest
        alt callback data
            Contract->>User: onCallback()
        end
        Contract->>Token: transferFrom()
    ```

    ## Borrow Flow
    [sequence diagram]

    ## Liquidation Flow
    [sequence diagram]

    ## State Changes Summary

    | Operation | User State | Global State |
    |-----------|------------|--------------|
    | supply | +shares | +totalSupply |

---

## Prompt for Step 5: System Overview (Auditor Digest)

**Goal:** Create kb/5-overview.md - A single-page security-focused digest for auditors.

**Required data from cache:** META, README, FILE sections (STATE, MODIFIERS, CONSTRUCTOR), FUNC sections (EXTERNAL_CALLS, REQUIRES); NOTE: invariants/edge cases may require source

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if META section exists
        3. Check if FILE sections contain STATE, MODIFIERS, CONSTRUCTOR
        4. Check if FUNC sections contain REQUIRES and EXTERNAL_CALLS
        IF checks pass:
            Parse META for project info
            Parse README section for description
            Parse FILE sections for main contracts, STATE, MODIFIERS
            Parse FUNC sections for entry points, external dependencies
            NOTE: If invariants/edge cases needed, read source for specific logic
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect source directory
        2. Read main contract(s) in {src}
        3. Read README.md, docs/ if exists
        4. Analyze for security-relevant info

**Output format:**

    # System Overview

    ## What is [Protocol Name]?
    [1-2 sentence description]

    ## Core Mechanics
    - **Mechanism 1**: How X works
    - **Mechanism 2**: How Y works

    ## Architecture

    ```mermaid
    graph TD
        User --> MainContract
        MainContract --> Oracle
    ```

    ## Entry Points

    | Function | Purpose | Risk Level |
    |----------|---------|------------|
    | supply() | Deposit | Low |
    | liquidate() | Liquidate | High |

    ## Trust Assumptions

    | Trust | Who/What | Impact if Malicious |
    |-------|----------|---------------------|
    | Owner | Admin | Can set fees |
    | Oracle | Price feed | Bad debt |

    ## External Dependencies

    | Dependency | Type | Risk |
    |------------|------|------|
    | Chainlink | Oracle | Price manipulation |

    ## Critical State Variables

    | Variable | Location | Controls |
    |----------|----------|----------|
    | totalSupply | Market | Total deposited |

    ## Value Flows

    ```mermaid
    flowchart LR
        Supplier -->|token| Protocol
        Protocol -->|token| Borrower
    ```

    ## Privileged Roles

    | Role | Powers | Risk |
    |------|--------|------|
    | Owner | Enable IRM | Medium |

    ## Key Invariants

    1. `totalBorrow <= totalSupply`
    2. `collateral * price * LLTV >= debt`

    ## Attack Surface

    | Area | Concern | Mitigation |
    |------|---------|------------|
    | Flash loans | Price manipulation | TWAP |
    | Callbacks | Reentrancy | CEI pattern |

    ## Known Edge Cases

    - [Edge case and handling]

    ## Quick Reference

    | Metric | Value |
    |--------|-------|
    | Max Fee | 25% |

---

## Prompt for Step 6: Code Documentation (Deep Audit Reference)

**Goal:** Create kb/6-codeDocumentation.md - Comprehensive function-by-function documentation for auditors who need deep understanding.

**Required data from cache:** All FUNC sections with full details (SIG, VISIBILITY, MODIFIERS, NATSPEC, REQUIRES, READS, WRITES, EVENTS, INTERNAL_CALLS, EXTERNAL_CALLS)

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if FUNC sections exist with:
           - SIG (signature)
           - REQUIRES (validation logic)
           - READS and WRITES (state access)
           - EVENTS
           - INTERNAL_CALLS and EXTERNAL_CALLS
        IF all checks pass:
            Parse all FUNC sections
            Group by contract
            Document each function with full detail
        ELSE:
            Fall through to source reading

    FALLBACK to source:
        1. Detect source directory
        2. Glob for .sol files in {src}
        3. For EACH contract, for EACH function:
           - Extract full signature
           - Extract all require/revert statements
           - Identify state reads and writes
           - Identify events emitted
           - Trace internal calls
           - Identify external calls
           - Note any reentrancy patterns (external call before state update)
           - Extract NatSpec documentation

**Output format:**

    # Code Documentation

    ## Contract: ContractName
    **File:** `path/to/Contract.sol`
    **Inherits:** IFoo, Base
    **Description:** [from NatSpec]

    ### State Variables

    | Variable | Type | Visibility | Purpose |
    |----------|------|------------|---------|
    | owner | address | public | Protocol admin |
    | totalSupply | uint256 | internal | Total assets |

    ### Modifiers

    #### `onlyOwner`
    **Logic:** `require(msg.sender == owner, "not owner")`
    **Purpose:** Restricts to protocol admin

    ---

    ### Functions

    #### `supply`

    ```solidity
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256)
    ```

    **Purpose:** Supplies assets to a market on behalf of a user

    **Parameters:**
    | Param | Type | Description |
    |-------|------|-------------|
    | marketParams | MarketParams | Market identifier |
    | assets | uint256 | Amount to supply (or 0) |
    | shares | uint256 | Shares to mint (or 0) |
    | onBehalf | address | Position owner |
    | data | bytes | Callback data |

    **Returns:**
    | Type | Description |
    |------|-------------|
    | uint256 | Actual assets supplied |
    | uint256 | Shares minted |

    **Access Control:** None (permissionless)

    **Validation:**
    1. `require(market[id].lastUpdate != 0)` - Market must exist
    2. `require(exactlyOneZero(assets, shares))` - Exactly one of assets/shares must be 0
    3. `require(onBehalf != address(0))` - Valid recipient

    **State Changes:**
    | Variable | Change |
    |----------|--------|
    | position[id][onBehalf].supplyShares | += shares |
    | market[id].totalSupplyShares | += shares |
    | market[id].totalSupplyAssets | += assets |

    **Internal Calls:**
    - `_accrueInterest(marketParams, id)` - Updates interest before operation

    **External Calls:**
    1. `IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data)` - If data.length > 0
    2. `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)`

    **Events:**
    - `EventsLib.Supply(id, msg.sender, onBehalf, assets, shares)`

    **Security Notes:**
    - Callback happens BEFORE token transfer (check-effects-interactions pattern)
    - Caller must have approved contract for loanToken
    - Interest accrued before position update

    ---

    #### `_accrueInterest` (internal)

    ```solidity
    function _accrueInterest(MarketParams memory marketParams, Id id) internal
    ```

    **Purpose:** Accrues interest for a market

    **Visibility:** internal (called by supply, withdraw, borrow, repay, liquidate)

    **State Changes:**
    | Variable | Change |
    |----------|--------|
    | market[id].totalBorrowAssets | += interest |
    | market[id].totalSupplyAssets | += interest |
    | market[id].lastUpdate | = block.timestamp |
    | position[id][feeRecipient].supplyShares | += feeShares (if fee > 0) |

    **External Calls:**
    - `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` - Gets current rate

    **Security Notes:**
    - Skipped if elapsed == 0 (same block)
    - Skipped if totalBorrowAssets == 0 (no interest to accrue)
    - Uses Taylor expansion for continuous compounding approximation

    ---

    [Continue for ALL functions...]

    ---

    ## Contract: Library
    [Same format for libraries]

    ---

    ## Security Summary

    ### Reentrancy Vectors
    | Function | External Call | State After | Risk |
    |----------|---------------|-------------|------|
    | supply | onMorphoSupply callback | Before transfer | Low - state updated first |
    | liquidate | onMorphoLiquidate callback | Before repay transfer | Low - state updated first |

    ### Privileged Functions
    | Function | Role | Impact |
    |----------|------|--------|
    | setOwner | Owner | Transfer admin control |
    | enableIrm | Owner | Whitelist interest model |
    | setFee | Owner | Set market fee (max 25%) |

    ### Critical Invariants Checked
    | Invariant | Where Checked |
    |-----------|---------------|
    | totalBorrow <= totalSupply | withdraw(), borrow() |
    | position health | borrow(), withdrawCollateral() |

---

## Prompt for Step 7: Inline Code Documentation (Source Modification)

**Goal:** Add inline documentation directly to source files - documenting difficult parts with explicit bounds to save auditor time.

**⚠️ WARNING:** This step MODIFIES actual source code files. It adds comments only - no logic changes.

**Required data from cache:** FUNC sections with REQUIRES, READS, WRITES, bounds info; or read source directly

**Execution:**

    TRY cache:
        1. Check if kb/1-informationNeededForSteps.md exists
        2. Check if FUNC sections contain REQUIRES, READS, WRITES
        IF checks pass:
            Use cached data to understand function logic
            Still need to read source files to add inline comments
        ELSE:
            Read source files directly

    ALWAYS (regardless of cache):
        1. Detect source directory
        2. For EACH .sol file in {src} (core contracts, not interfaces/libraries unless complex):
           - Read the file
           - For EACH function, add inline comments for:
             a. Bounds and limits (min/max values, overflow considerations)
             b. Complex arithmetic (explain the math)
             c. State transition logic (what changes and why)
             d. Security-critical sections (reentrancy points, access control)
             e. Edge cases (zero values, max values, empty states)
             f. External call risks (what could go wrong)
             g. Invariants maintained by this function
           - Write the modified file back

**What to document inline:**

1. **Bounds/Limits:**
   - Parameter bounds (min, max, cannot be zero)
   - Return value ranges
   - Overflow/underflow considerations
   - Array length limits

2. **Complex Logic:**
   - Mathematical formulas with explanation
   - Rounding direction and why
   - Bit manipulation
   - Assembly blocks

3. **Security Notes:**
   - Reentrancy considerations
   - Access control rationale
   - Why checks are ordered this way
   - Trust assumptions

4. **State Transitions:**
   - What state changes occur
   - Order of operations matters because...
   - Invariants preserved

**Comment Format (use existing NatSpec style if present, else use ///):**

```solidity
/// @notice Supplies assets to a market
/// @dev BOUNDS: assets or shares must be non-zero (exactly one must be 0)
/// @dev BOUNDS: onBehalf cannot be address(0)
/// @dev STATE: Updates position.supplyShares, market.totalSupplyShares, market.totalSupplyAssets
/// @dev SECURITY: Callback executes BEFORE token transfer - state already updated, safe from reentrancy
/// @dev MATH: shares = assets * (totalShares + 1) / (totalAssets + 1), rounded down
function supply(...) external returns (uint256, uint256) {
    // --- VALIDATION BOUNDS ---
    // Market must exist (lastUpdate set on creation)
    require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);

    // Exactly one of assets/shares must be 0 - prevents ambiguous input
    // If both provided, unclear which to use; if neither, nothing to supply
    require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);

    // --- INTEREST ACCRUAL ---
    // Must accrue before any position changes to ensure accurate share pricing
    _accrueInterest(marketParams, id);

    // --- SHARE CALCULATION ---
    // MATH: Converting assets to shares using virtual shares to prevent inflation attack
    // Rounding DOWN protects protocol - user gets slightly fewer shares
    if (assets > 0) shares = assets.toSharesDown(market[id].totalSupplyAssets, market[id].totalSupplyShares);
    // MATH: Converting shares to assets, rounding UP - user pays slightly more
    else assets = shares.toAssetsUp(market[id].totalSupplyAssets, market[id].totalSupplyShares);

    // --- STATE UPDATES (before external calls) ---
    // SECURITY: All state updates happen before external calls (CEI pattern)
    position[id][onBehalf].supplyShares += shares;
    market[id].totalSupplyShares += shares.toUint128();
    market[id].totalSupplyAssets += assets.toUint128();
    // BOUNDS: toUint128() reverts if value > type(uint128).max

    // --- CALLBACK (optional) ---
    // SECURITY: Callback after state update but before transfer
    // Caller can use callback to source funds (e.g., flash loan pattern)
    if (data.length > 0) IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data);

    // --- TOKEN TRANSFER ---
    // SECURITY: Transfer last - if it fails, all state changes revert
    IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets);

    return (assets, shares);
}
```

**Output:** Modified source files in {src}/ with inline documentation added.

**Files modified:** All core contract .sol files (list them in output summary)

**Summary format (print after completion):**

    # Step 7: Inline Documentation Complete

    ## Files Modified:
    - src/Contract.sol - 15 functions documented
    - src/AnotherContract.sol - 8 functions documented

    ## Documentation Added:
    - Bounds annotations: X
    - Math explanations: Y
    - Security notes: Z
    - State transition docs: W

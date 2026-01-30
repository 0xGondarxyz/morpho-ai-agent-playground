# Setup Charts

This document provides visual diagrams for the Morpho Blue protocol's deployment, configuration, and market creation phases.

---

## Deployment Sequence

The Morpho protocol deployment follows a phased approach: external dependencies must exist first, then the singleton contract is deployed, followed by owner configuration, and finally permissionless market creation.

```mermaid
sequenceDiagram
    participant Deployer
    participant Morpho
    participant Owner
    participant Anyone
    participant IRM as IRM Contract
    participant Oracle as Oracle Contract

    Note over Deployer: External Dependencies (Pre-existing)
    Note over IRM,Oracle: ERC20 Tokens, Oracles, IRMs must exist

    rect rgb(200, 230, 201)
        Note over Deployer,Morpho: Phase 1: Protocol Deployment
        Deployer->>Morpho: new Morpho(ownerAddress)
        Morpho->>Morpho: require(newOwner != address(0))
        Morpho->>Morpho: owner = newOwner
        Morpho->>Morpho: DOMAIN_SEPARATOR = keccak256(...)
        Morpho-->>Deployer: emit SetOwner(newOwner)
    end

    rect rgb(255, 249, 196)
        Note over Owner,Morpho: Phase 2: Owner Configuration
        Owner->>Morpho: enableIrm(irmAddress)
        Morpho->>Morpho: require(!isIrmEnabled[irm])
        Morpho->>Morpho: isIrmEnabled[irm] = true
        Morpho-->>Owner: emit EnableIrm(irm)

        Owner->>Morpho: enableLltv(lltvValue)
        Morpho->>Morpho: require(!isLltvEnabled[lltv])
        Morpho->>Morpho: require(lltv < WAD)
        Morpho->>Morpho: isLltvEnabled[lltv] = true
        Morpho-->>Owner: emit EnableLltv(lltv)

        Owner->>Morpho: setFeeRecipient(feeAddress)
        Morpho->>Morpho: require(newFeeRecipient != feeRecipient)
        Morpho->>Morpho: feeRecipient = newFeeRecipient
        Morpho-->>Owner: emit SetFeeRecipient(newFeeRecipient)
    end

    rect rgb(243, 229, 245)
        Note over Anyone,Morpho: Phase 3: Market Creation (Permissionless)
        Anyone->>Morpho: createMarket(marketParams)
        Morpho->>Morpho: id = keccak256(marketParams)
        Morpho->>Morpho: require(isIrmEnabled[irm])
        Morpho->>Morpho: require(isLltvEnabled[lltv])
        Morpho->>Morpho: require(market[id].lastUpdate == 0)
        Morpho->>IRM: borrowRate(marketParams, market)
        IRM-->>Morpho: rate (initializes stateful IRMs)
        Morpho->>Morpho: market[id].lastUpdate = block.timestamp
        Morpho->>Morpho: idToMarketParams[id] = marketParams
        Morpho-->>Anyone: emit CreateMarket(id, marketParams)
    end

    rect rgb(225, 245, 254)
        Note over Owner,Morpho: Phase 4: Optional Market Configuration
        Owner->>Morpho: setFee(marketParams, newFee)
        Morpho->>Morpho: require(market[id].lastUpdate != 0)
        Morpho->>Morpho: require(newFee <= MAX_FEE)
        Morpho->>Morpho: _accrueInterest(marketParams, id)
        Morpho->>Morpho: market[id].fee = newFee
        Morpho-->>Owner: emit SetFee(id, newFee)
    end
```

---

## Configuration State Machine

The Morpho protocol transitions through distinct states from deployment to full operation. Once IRMs and LLTVs are enabled, they cannot be disabled.

```mermaid
stateDiagram-v2
    [*] --> Deployed: constructor(owner)

    state Deployed {
        [*] --> NoIRMs
        NoIRMs: No IRMs enabled
        NoIRMs: No LLTVs enabled
        NoIRMs: No markets possible
    }

    Deployed --> PartiallyConfigured: enableIrm(irm)
    Deployed --> PartiallyConfigured: enableLltv(lltv)

    state PartiallyConfigured {
        [*] --> NeedsBoth
        NeedsBoth: Has IRM OR LLTV
        NeedsBoth: Not both
    }

    PartiallyConfigured --> ReadyForMarkets: enableLltv(lltv)
    PartiallyConfigured --> ReadyForMarkets: enableIrm(irm)

    state ReadyForMarkets {
        [*] --> CanCreate
        CanCreate: Has enabled IRM(s)
        CanCreate: Has enabled LLTV(s)
        CanCreate: Markets can be created
    }

    ReadyForMarkets --> ReadyForMarkets: enableIrm(additionalIrm)
    ReadyForMarkets --> ReadyForMarkets: enableLltv(additionalLltv)

    ReadyForMarkets --> Active: createMarket(params)

    state Active {
        [*] --> Operating
        Operating: Markets exist
        Operating: Users can supply/borrow
        Operating: Interest accrues
    }

    Active --> Active: createMarket(newParams)
    Active --> Active: setFee(params, fee)
    Active --> Active: setFeeRecipient(addr)
    Active --> Active: setOwner(newOwner)

    Active --> Renounced: setOwner(address(0))

    state Renounced {
        [*] --> Immutable
        Immutable: No new IRMs
        Immutable: No new LLTVs
        Immutable: No fee changes
        Immutable: Protocol continues operating
    }

    Renounced --> [*]: Protocol runs indefinitely
```

---

## Owner Admin Functions State Diagram

Shows the state transitions enabled by owner-only administrative functions.

```mermaid
stateDiagram-v2
    direction LR

    state "Owner Functions" as OwnerFns {
        [*] --> IRMManagement
        [*] --> LLTVManagement
        [*] --> FeeManagement
        [*] --> OwnershipManagement

        state IRMManagement {
            IRMDisabled --> IRMEnabled: enableIrm(irm)
            note right of IRMEnabled: Cannot disable
        }

        state LLTVManagement {
            LLTVDisabled --> LLTVEnabled: enableLltv(lltv)
            note right of LLTVEnabled: Cannot disable
        }

        state FeeManagement {
            NoFeeRecipient --> HasFeeRecipient: setFeeRecipient(addr)
            HasFeeRecipient --> NoFeeRecipient: setFeeRecipient(0)
            HasFeeRecipient --> HasFeeRecipient: setFeeRecipient(newAddr)

            MarketNoFee --> MarketHasFee: setFee(params, fee)
            MarketHasFee --> MarketNoFee: setFee(params, 0)
            MarketHasFee --> MarketHasFee: setFee(params, newFee)
        }

        state OwnershipManagement {
            HasOwner --> NewOwner: setOwner(newOwner)
            HasOwner --> NoOwner: setOwner(address(0))
            note right of NoOwner: Irreversible
        }
    }
```

---

## Market Creation Flow

Detailed flowchart showing the createMarket function's preconditions, execution, and outcomes.

```mermaid
flowchart TD
    A[createMarket called<br/>MarketParams: loanToken, collateralToken,<br/>oracle, irm, lltv] --> B{Is IRM enabled?}

    B -->|No| C[REVERT<br/>IRM_NOT_ENABLED]
    B -->|Yes| D{Is LLTV enabled?}

    D -->|No| E[REVERT<br/>LLTV_NOT_ENABLED]
    D -->|Yes| F[Compute Market ID<br/>id = keccak256 abi.encode params]

    F --> G{market id .lastUpdate == 0?}

    G -->|No| H[REVERT<br/>MARKET_ALREADY_CREATED]
    G -->|Yes| I{irm != address 0?}

    I -->|Yes| J[Call IRM.borrowRate<br/>Initialize stateful IRM]
    I -->|No| K[Skip IRM call<br/>0% APR market]

    J --> L[Set market.lastUpdate<br/>= block.timestamp]
    K --> L

    L --> M[Store idToMarketParams id<br/>= marketParams]

    M --> N[Emit CreateMarket<br/>id, marketParams]

    N --> O[SUCCESS<br/>Market ready for use]

    subgraph Preconditions
        B
        D
        G
    end

    subgraph "State Changes"
        L
        M
    end

    subgraph "External Calls"
        J
    end

    style C fill:#ffcdd2
    style E fill:#ffcdd2
    style H fill:#ffcdd2
    style O fill:#c8e6c9
```

---

## Market Parameters Validation

Shows what makes a valid market configuration and the relationship between components.

```mermaid
flowchart LR
    subgraph MarketParams
        LT[loanToken<br/>address]
        CT[collateralToken<br/>address]
        OR[oracle<br/>address]
        IRM[irm<br/>address]
        LLTV[lltv<br/>uint256]
    end

    subgraph Validation
        V1{IRM Enabled?}
        V2{LLTV Enabled?}
        V3{LLTV < WAD?}
        V4{Market Unique?}
    end

    subgraph "External Dependencies"
        E1[ERC20 Token<br/>No fee-on-transfer<br/>No rebasing]
        E2[IOracle.price<br/>Returns price * 1e36]
        E3[IIrm.borrowRate<br/>Returns rate per second]
    end

    LT --> E1
    CT --> E1
    OR --> E2
    IRM --> E3
    IRM --> V1
    LLTV --> V2
    LLTV --> V3

    V1 -->|Pass| V4
    V2 -->|Pass| V4
    V3 -->|Pass| V4
    V4 -->|Pass| SUCCESS[Market Created]

    V1 -->|Fail| FAIL1[IRM_NOT_ENABLED]
    V2 -->|Fail| FAIL2[LLTV_NOT_ENABLED]
    V3 -->|Fail| FAIL3[MAX_LLTV_EXCEEDED]
    V4 -->|Fail| FAIL4[MARKET_ALREADY_CREATED]

    style SUCCESS fill:#c8e6c9
    style FAIL1 fill:#ffcdd2
    style FAIL2 fill:#ffcdd2
    style FAIL3 fill:#ffcdd2
    style FAIL4 fill:#ffcdd2
```

---

## Protocol Initialization Checklist

Visual representation of the complete setup process with dependencies.

```mermaid
flowchart TD
    subgraph "Phase 0: External Dependencies"
        EXT1[Deploy/Verify ERC20 Tokens]
        EXT2[Deploy Oracle Contracts]
        EXT3[Deploy IRM Contracts]
    end

    subgraph "Phase 1: Contract Deployment"
        DEP1[Deploy Morpho<br/>constructor newOwner]
    end

    subgraph "Phase 2: Owner Configuration"
        CFG1[enableIrm - address 0<br/>For 0% APR markets]
        CFG2[enableIrm - adaptive IRM<br/>For dynamic rates]
        CFG3[enableLltv - 0.8e18<br/>80% standard]
        CFG4[enableLltv - 0.945e18<br/>94.5% stablecoins]
        CFG5[setFeeRecipient<br/>Protocol treasury]
    end

    subgraph "Phase 3: Market Creation"
        MKT1[createMarket<br/>WETH/USDC 80%]
        MKT2[createMarket<br/>USDC/DAI 94.5%]
    end

    subgraph "Phase 4: Market Fees"
        FEE1[setFee - 10%<br/>WETH/USDC market]
    end

    EXT1 --> MKT1
    EXT1 --> MKT2
    EXT2 --> MKT1
    EXT2 --> MKT2
    EXT3 --> CFG1
    EXT3 --> CFG2

    DEP1 --> CFG1
    DEP1 --> CFG2
    DEP1 --> CFG3
    DEP1 --> CFG4
    DEP1 --> CFG5

    CFG1 --> MKT1
    CFG2 --> MKT1
    CFG2 --> MKT2
    CFG3 --> MKT1
    CFG4 --> MKT2

    MKT1 --> FEE1

    style DEP1 fill:#c8e6c9
    style CFG1 fill:#fff9c4
    style CFG2 fill:#fff9c4
    style CFG3 fill:#fff9c4
    style CFG4 fill:#fff9c4
    style CFG5 fill:#fff9c4
    style MKT1 fill:#e1bee7
    style MKT2 fill:#e1bee7
    style FEE1 fill:#bbdefb
```

---

## Error Cases Summary

All revert conditions during setup and configuration.

| Function | Error | Condition |
|----------|-------|-----------|
| `constructor` | `ZERO_ADDRESS` | `newOwner == address(0)` |
| `setOwner` | `NOT_OWNER` | `msg.sender != owner` |
| `setOwner` | `ALREADY_SET` | `newOwner == owner` |
| `enableIrm` | `NOT_OWNER` | `msg.sender != owner` |
| `enableIrm` | `ALREADY_SET` | `isIrmEnabled[irm] == true` |
| `enableLltv` | `NOT_OWNER` | `msg.sender != owner` |
| `enableLltv` | `ALREADY_SET` | `isLltvEnabled[lltv] == true` |
| `enableLltv` | `MAX_LLTV_EXCEEDED` | `lltv >= WAD` |
| `setFeeRecipient` | `NOT_OWNER` | `msg.sender != owner` |
| `setFeeRecipient` | `ALREADY_SET` | `newFeeRecipient == feeRecipient` |
| `createMarket` | `IRM_NOT_ENABLED` | `isIrmEnabled[irm] == false` |
| `createMarket` | `LLTV_NOT_ENABLED` | `isLltvEnabled[lltv] == false` |
| `createMarket` | `MARKET_ALREADY_CREATED` | `market[id].lastUpdate != 0` |
| `setFee` | `NOT_OWNER` | `msg.sender != owner` |
| `setFee` | `MARKET_NOT_CREATED` | `market[id].lastUpdate == 0` |
| `setFee` | `ALREADY_SET` | `newFee == market[id].fee` |
| `setFee` | `MAX_FEE_EXCEEDED` | `newFee > MAX_FEE (0.25e18)` |

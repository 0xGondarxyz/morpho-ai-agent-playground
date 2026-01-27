# Authorization Flow

## Direct Authorization

```mermaid
sequenceDiagram
    actor User
    actor Operator
    participant Morpho

    Note over User,Morpho: Grant Authorization
    User->>Morpho: setAuthorization(operator, true)
    Morpho->>Morpho: require(newIsAuthorized != isAuthorized[user][operator])
    Morpho->>Morpho: isAuthorized[user][operator] = true
    Morpho-->>User: emit SetAuthorization(user, user, operator, true)

    Note over Operator,Morpho: Use Authorization
    Operator->>Morpho: withdraw(params, assets, 0, user, receiver)
    Morpho->>Morpho: _isSenderAuthorized(user)
    Morpho->>Morpho: msg.sender == user? NO
    Morpho->>Morpho: isAuthorized[user][msg.sender]? YES
    Morpho->>Morpho: execute withdrawal
    Morpho-->>Operator: (assets, shares)

    Note over User,Morpho: Revoke Authorization
    User->>Morpho: setAuthorization(operator, false)
    Morpho->>Morpho: isAuthorized[user][operator] = false
    Morpho-->>User: emit SetAuthorization(user, user, operator, false)
```

## Signature-Based Authorization (EIP-712)

```mermaid
sequenceDiagram
    actor User
    actor Relayer
    participant Morpho

    Note over User,Relayer: Off-chain Signing
    User->>User: Create Authorization struct
    Note right of User: authorizer: user<br/>authorized: operator<br/>isAuthorized: true<br/>nonce: morpho.nonce(user)<br/>deadline: timestamp
    User->>User: Sign EIP-712 message
    User->>Relayer: Send signature + authorization

    Note over Relayer,Morpho: On-chain Submission
    Relayer->>Morpho: setAuthorizationWithSig(authorization, signature)
    Morpho->>Morpho: require(block.timestamp <= deadline)
    Morpho->>Morpho: require(nonce == nonce[authorizer]++)
    Morpho->>Morpho: Verify EIP-712 signature
    Morpho->>Morpho: require(signatory == authorizer)
    Morpho->>Morpho: isAuthorized[authorizer][authorized] = isAuthorized
    Morpho-->>Relayer: emit IncrementNonce + SetAuthorization
```

## Authorization Check Flow

```mermaid
flowchart TD
    A[Function Call with onBehalf] --> B{msg.sender == onBehalf?}
    B -->|Yes| C[Authorized - Proceed]
    B -->|No| D{isAuthorized[onBehalf][msg.sender]?}
    D -->|Yes| C
    D -->|No| E[Revert: UNAUTHORIZED]
```

## EIP-712 Domain and Types

```mermaid
graph LR
    subgraph Domain["EIP-712 Domain"]
        D1["name: (implicit)"]
        D2["chainId: block.chainid"]
        D3["verifyingContract: morpho address"]
    end

    subgraph Authorization["Authorization Struct"]
        A1["authorizer: address"]
        A2["authorized: address"]
        A3["isAuthorized: bool"]
        A4["nonce: uint256"]
        A5["deadline: uint256"]
    end

    subgraph Signature["Signature"]
        S1["v: uint8"]
        S2["r: bytes32"]
        S3["s: bytes32"]
    end

    Authorization --> Hash["keccak256(abi.encode(<br/>AUTHORIZATION_TYPEHASH,<br/>authorization))"]
    Domain --> DomainSep["DOMAIN_SEPARATOR"]
    Hash --> Digest
    DomainSep --> Digest["keccak256(0x1901 || DOMAIN_SEPARATOR || hashStruct)"]
    Digest --> Recover["ecrecover(digest, v, r, s)"]
    Signature --> Recover
    Recover --> Verify["signatory == authorizer?"]
```

## Use Cases

```mermaid
graph TD
    subgraph UseCases["Authorization Use Cases"]
        UC1["Smart Contract Wallet"]
        UC2["Meta-Transaction Relayer"]
        UC3["Bundler Contract"]
        UC4["Vault/Strategy"]
    end

    subgraph Operations["Enabled Operations"]
        O1["withdraw"]
        O2["borrow"]
        O3["withdrawCollateral"]
    end

    UC1 --> O1
    UC1 --> O2
    UC1 --> O3

    UC2 --> O1
    UC2 --> O2

    UC3 --> O1
    UC3 --> O2
    UC3 --> O3

    UC4 --> O1
    UC4 --> O3
```

## Nonce Management

```mermaid
sequenceDiagram
    participant User
    participant Morpho

    User->>Morpho: nonce(user)
    Morpho-->>User: 0

    User->>Morpho: setAuthorizationWithSig(auth{nonce:0}, sig)
    Morpho->>Morpho: nonce[user]++ (now 1)
    Morpho-->>User: success

    User->>Morpho: nonce(user)
    Morpho-->>User: 1

    Note over User,Morpho: Replay with nonce 0 fails
    User->>Morpho: setAuthorizationWithSig(auth{nonce:0}, sig)
    Morpho-->>User: revert INVALID_NONCE
```

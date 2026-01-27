# Parameter Classification

## Morpho Constructor

| Parameter | Type | Classification | Resolves To |
|-----------|------|----------------|-------------|
| newOwner | address | Admin address | Deployer sets (protocol owner) |

## FlashBorrowerMock Constructor (Testing)

| Parameter | Type | Classification | Resolves To |
|-----------|------|----------------|-------------|
| newMorpho | IMorpho | Internal dependency | Morpho.sol address |

## Market Creation Parameters

When creating a market via `createMarket(MarketParams)`, the following parameters are required:

| Parameter | Type | Classification | Resolves To |
|-----------|------|----------------|-------------|
| loanToken | address | External address | ERC20 token contract |
| collateralToken | address | External address | ERC20 token contract |
| oracle | address | External address | IOracle implementation |
| irm | address | External address | IIrm implementation (or address(0)) |
| lltv | uint256 | Config value | Must be in enabled LLTVs set |

## Post-Deployment Configuration Parameters

### enableIrm(address irm)
| Parameter | Type | Classification |
|-----------|------|----------------|
| irm | address | External address (IRM contract) |

### enableLltv(uint256 lltv)
| Parameter | Type | Classification |
|-----------|------|----------------|
| lltv | uint256 | Config value (< WAD) |

### setFee(MarketParams, uint256 newFee)
| Parameter | Type | Classification |
|-----------|------|----------------|
| marketParams | MarketParams | Market identifier |
| newFee | uint256 | Config value (<= MAX_FEE) |

### setFeeRecipient(address newFeeRecipient)
| Parameter | Type | Classification |
|-----------|------|----------------|
| newFeeRecipient | address | Admin address (fee recipient) |

### setOwner(address newOwner)
| Parameter | Type | Classification |
|-----------|------|----------------|
| newOwner | address | Admin address (new owner) |

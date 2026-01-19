# 🏢 Real Estate Staking Platform — Solidity + Foundry

A complete **real estate staking platform** built in Solidity and fully tested with Foundry.  
This project includes:

- A custom ERC‑20 token (RET)
- A simulated USDC ERC‑20 token for rewards
- A Staking contract featuring:
  - Token deposits
  - Withdrawals with a dynamic 30% limit
  - Period‑based reward distribution
  - Configurable property reward rates
  - Owner‑controlled property lifecycle
- A comprehensive test suite with full coverage

---

## 📂 Project Structure

/src 

  ├── RealEstateToken.sol 
  
  └── StakingApp.sol

/test 

  ├── TestRealEstateToken.t.sol 
  
  └── TestStakingApp.t.sol
  
foundry.toml 

README.md

---

# 🏗️ Smart Contracts

## 🪙 RealEstateToken.sol

A simple ERC‑20 token with minting restricted to the contract owner.

### Features

| Function | Description |
|---------|-------------|
| `constructor(name, symbol, owner)` | Initializes the token |
| `mint(amount)` | Only the owner can mint new tokens |

---

## 🏦 StakingApp.sol

The main staking contract of the platform.

### ✔ Properties
Each property contains:
- `exists`
- `successful`
- `rewardRateBps` (basis points)

### ✔ Staking Logic
- Unlimited deposits
- Withdrawals limited to **30% of the current stake**
- Staking period resets on additional deposits and partial withdrawals
- Full withdrawals reset the entire stake state

### ✔ Rewards
Rewards are only available when:
- The property is marked as `successful`
- At least one full staking period has passed

Reward formula:
reward = (stake.amount * rewardRateBps / 10000) * periods

### ✔ Security
- `nonReentrant` protection
- Strict validation checks
- Owner‑only administrative functions

---

# 🧪 Testing (Foundry)

This project includes a complete test suite covering all scenarios.

## 🔹 TestRealEstateToken.t.sol
- Owner can mint tokens
- Non‑owners cannot mint
- totalSupply increases correctly
- Constructor initializes correctly

## 🔹 TestStakingApp.t.sol
Covers all staking, reward, and property logic:

### Property Management
- Add property
- Update property
- Reject invalid reward rates
- Reject non‑existent properties

### Deposits
- Initial deposit
- Multiple deposits
- Reject deposits into non‑existent properties

### Withdrawals
- Valid withdrawals
- Partial withdrawals
- Full withdrawals
- Reverts:
  - Property does not exist
  - Amount = 0
  - Insufficient balance
  - Staking period not completed
  - Exceeds 30% withdrawal limit

### Rewards
- Valid reward claims
- Multiple‑period reward claims
- No‑reward scenarios
- Claim without stake
- Claim without enough USDC in contract
- Claim on non‑successful property
- Claim on non‑existent property

---

# 📈 Coverage

This project achieves **100% real coverage**, including:

- All conditional branches  
- All revert paths  
- All events  
- All edge‑case scenarios  

# 🚀 How to Run the Project

1. Install Foundry
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies
```
forge install
```

3. Run tests
```
forge test --match-test "test name" -vvvv
```

5. Run coverage
```
forge coverage
```


# 📜 License
MIT License.

# 🙌 Author
Developed by Alexka, with a focus on:
- Clean architecture
- Security
- Transparency
- User‑friendly logic
- Audit‑ready smart contracts


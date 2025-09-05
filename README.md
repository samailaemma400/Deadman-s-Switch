# ⚰️ Deadman's Switch Smart Contract

> 🔒 **A Stacks blockchain smart contract that automatically transfers assets if you become inactive**

## 🎯 Overview

The Deadman's Switch contract allows users to create a "liveness detection" system where assets are automatically transferred to a designated beneficiary if the owner doesn't check in within a specified timeframe. Perfect for digital inheritance, emergency asset recovery, or any scenario requiring proof of life.

## ✨ Features

- 🛡️ **Create Switches**: Set up your deadman's switch with a beneficiary and timeout period
- 💰 **Asset Management**: Deposit and withdraw STX tokens
- ⏰ **Liveness Proof**: Regular check-ins to prove you're still active
- 👨‍👩‍👧‍👦 **Inheritance Claims**: Beneficiaries can claim assets after timeout expires
- 🔧 **Flexible Updates**: Change beneficiaries and timeout periods
- 🚨 **Emergency Withdrawal**: Complete asset recovery and switch deletion
- 📊 **Status Monitoring**: Real-time switch status and analytics

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Stacks blockchain

### Installation

```bash
git clone <your-repo-url>
cd deadman-s-switch
clarinet console
```

## 📋 Usage Instructions

### 1. 🏗️ Creating a Switch

```clarity
(contract-call? .deadmans-switch create-switch 'ST1BENEFICIARY... u1000)
```

- **beneficiary**: Principal address who will inherit the assets
- **timeout-blocks**: Number of blocks before switch expires (144-52560)

### 2. 💳 Depositing Assets

```clarity
(contract-call? .deadmans-switch deposit u1000000)
```

Deposits STX tokens (in microSTX) into your switch.

### 3. 💓 Checking In (Staying Alive)

```clarity
(contract-call? .deadmans-switch checkin)
```

Updates your last activity timestamp to prevent inheritance claims.

### 4. 💸 Withdrawing Assets

```clarity
(contract-call? .deadmans-switch withdraw u500000)
```

Withdraw a specific amount from your switch balance.

### 5. 👑 Claiming Inheritance

```clarity
(contract-call? .deadmans-switch claim-inheritance 'ST1OWNER...)
```

Beneficiaries can claim assets after the timeout period expires.

### 6. 🔄 Updating Your Switch

#### Change Beneficiary
```clarity
(contract-call? .deadmans-switch update-beneficiary 'ST1NEWBENEFICIARY...)
```

#### Update Timeout Period
```clarity
(contract-call? .deadmans-switch update-timeout u2000)
```

### 7. 🆘 Emergency Withdrawal

```clarity
(contract-call? .deadmans-switch emergency-withdraw)
```

Completely withdraws all assets and deletes your switch.

## 🔍 Read-Only Functions

### Get Switch Details
```clarity
(contract-call? .deadmans-switch get-switch 'ST1OWNER...)
```

### Check Switch Status
```clarity
(contract-call? .deadmans-switch get-switch-status 'ST1OWNER...)
```
Returns active status, blocks until expiry, and claim eligibility.

### Verify Inheritance Readiness
```clarity
(contract-call? .deadmans-switch check-inheritance-ready 'ST1OWNER...)
```

### Contract Statistics
```clarity
(contract-call? .deadmans-switch get-contract-info)
```

## ⚙️ Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| `MIN_TIMEOUT_BLOCKS` | 144 | Minimum timeout (~1 day) |
| `MAX_TIMEOUT_BLOCKS` | 52,560 | Maximum timeout (~1 year) |

## 🔒 Security Features

- ✅ Owner validation for all operations
- ✅ Beneficiary cannot be the same as owner
- ✅ Timeout bounds enforcement
- ✅ Balance validation before transfers
- ✅ Activity-based liveness detection

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

## 📊 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Unauthorized operation |
| `u101` | Switch not found |
| `u102` | Switch already exists |
| `u103` | Insufficient balance |
| `u104` | Switch still active |
| `u105` | Invalid timeout period |
| `u106` | Invalid amount |

## 🎓 Learning Outcomes

This contract teaches:

- **Liveness Detection**: How to verify ongoing user activity
- **Time-based Logic**: Using block heights for timing mechanisms  
- **Asset Management**: Safe STX token handling patterns
- **State Management**: Complex data structure management in Clarity
- **Access Control**: Multi-party authorization patterns

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

MIT License - see LICENSE file for details

## ⚠️ Disclaimer

This contract is for educational purposes. Always audit smart contracts before using them with real assets in production.

---

Built with ❤️ for the Stacks ecosystem 🥞

# Token Vesting Vault

## 1. Project Overview

Token Vesting Vault is a Solidity smart contract that distributes ERC-20 tokens to beneficiaries according to predefined vesting schedules.

The contract supports a cliff period, linear token unlocking, token releases, schedule revocation, and beneficiary transfers.

The project uses Solidity 0.8.20, OpenZeppelin contracts, and Foundry for automated testing.

## 2. How Vesting Works

Vesting means that tokens become available gradually instead of being distributed all at once.

For example, a company may allocate 1,000 tokens to an employee with a 12-month cliff and a total vesting duration of 48 months.

| Time | Vested tokens |
|---|---:|
| Before 12 months | 0 |
| At 12 months | 250 |
| At 24 months | 500 |
| At 36 months | 750 |
| At 48 months | 1,000 |

The cliff is part of the total vesting duration. At the cliff, the accumulated vested amount becomes available.

## 3. Main Features

- Create vesting schedules for beneficiaries.
- Lock tokens during the cliff period.
- Calculate vested amounts using linear vesting.
- Release available tokens to beneficiaries.
- Revoke revocable schedules.
- Return unvested tokens to the owner after revocation.
- Withdraw tokens that are not allocated to schedules.
- Transfer a schedule to another beneficiary.
- View schedules belonging to a beneficiary.

## 4. Project Structure

```text
token-vesting-vault/
├── src/
│   └── VestingVault.sol
├── test/
│   └── VestingVault.t.sol
├── foundry.toml
└── README.md
```

Foundry dependencies are installed in the `lib/` directory.

## 5. Installation and Testing

Install Foundry and clone the repository:

```bash
git clone https://github.com/FrauMeka/token-vesting-vault.git
cd token-vesting-vault
```

Install the dependencies:

```bash
forge install foundry-rs/forge-std --no-git
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-git
```

Run the automated tests:

```bash
forge test -vv
```

Check code coverage:

```bash
forge coverage
```

## 6. Testing Results

The project contains 17 automated test functions.

The tests cover:

- Vesting before the start date.
- Vesting during the cliff period.
- Vesting exactly at the cliff.
- Vesting halfway through the schedule.
- Vesting at and after the end.
- Multiple token releases.
- Revocation before the cliff, halfway, and after the end.
- Releasing vested tokens after revocation.
- Prevention of over-allocation.
- Owner access restrictions.
- Correct beneficiary payments.
- Fuzz testing of vesting calculations.

**Foundry test results:**

| Result | Value |
|---|---:|
| Tests passed | 17 |
| Tests failed | 0 |
| Tests skipped | 0 |
| Fuzz runs | 256 |

**VestingVault.sol coverage:**

| Metric | Coverage |
|---|---:|
| Lines | 68.92% (51/74) |
| Statements | 69.62% (55/79) |
| Branches | 42.86% (18/42) |
| Functions | 80.00% (8/10) |

These results were obtained using `forge test -vv` and `forge coverage`.

## 7. Security Model

The contract uses OpenZeppelin's Ownable, SafeERC20, and ReentrancyGuard.

The owner can create vesting schedules, revoke schedules marked as revocable, and withdraw tokens that are not allocated.

Beneficiaries can transfer their own schedules to another address.

The `release` function can be called by anyone, but the released tokens are always sent to the schedule's current beneficiary.

### Risks Addressed

- **Unauthorized administration:** owner-only functions restrict sensitive operations.
- **Reentrancy:** token transfer functions use ReentrancyGuard.
- **Over-allocation:** the contract checks available token balances before creating schedules.
- **Repeated withdrawals:** released amounts are recorded to prevent claiming the same tokens twice.

### Remaining Risks

- **Owner key compromise:** an attacker controlling the owner's private key could create schedules, revoke revocable schedules, or withdraw unallocated tokens.
- **Revocation trust:** beneficiaries of revocable schedules depend on the owner not cancelling future vesting.
- **Token compatibility:** unusual ERC-20 token behavior may affect the contract.

The owner cannot normally withdraw tokens reserved for active vesting schedules through `withdrawUnallocated`.

## 8. Limitations

- The contract is designed for standard ERC-20 tokens.
- Fee-on-transfer and rebasing tokens are not explicitly supported.
- Vesting is calculated using block timestamps.
- Integer division may cause small rounding differences during intermediate calculations.
- Transferring a schedule changes its beneficiary but does not change its vesting conditions.
- The project has been tested locally and has not undergone an independent security audit.

## 9. Conclusion

This project demonstrates how ERC-20 tokens can be distributed over time using cliff periods and linear vesting.

Foundry tests verify the main vesting, release, revocation, and access-control scenarios. Additional tests would be useful to improve branch coverage and validate more edge cases.
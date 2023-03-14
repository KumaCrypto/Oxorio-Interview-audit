# Marketplace Security Audit Report

## INTRODUCTION

### Disclaimer

The audit makes no statements or warranties about utility of the code, safety of the code, suitability of the business model, investment advice, endorsement of the platform or its products, regulatory regime for the business model, or any other statements about fitness of the contracts to purpose, or their bug free status. The audit documentation is for discussion purposes only. The information presented in this report is confidential and privileged. If you are reading this report, you agree to keep it confidential, not to copy, disclose or disseminate without the agreement of Client. If you are not the intended recipient(s) of this document, please note that any disclosure, copying or dissemination of its content is strictly forbidden.

---

### Project Overview

There is Marketplace contract which allows to buy and sell NFTs exchanging them for `PAYMENT_TOKEN`'s. After the sale the funds remain on the balance of contract until claimed by seller. When claiming seller additionally gets a random reward in `REWARD_TOKEN` which amount depends on sale price and number of days passed from sale.

---

## Finding Severity breakdown

---

All vulnerabilities discovered during the audit are classified based on their potential severity and have the following classification:

| Severity | Description                                                                                                                              |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Critical | Bugs leading to assets theft, fund access locking, or any other loss of funds.                                                           |
| High     | Bugs that can trigger a contract failure. Further recovery is possible only by manual modification of the contract state or replacement. |
| Medium   | Bugs that can break the intended contract logic or expose it to DoS attacks, but do not cause direct loss funds.                         |
| Low      | Bugs that do not have a significant immediate impact and could be easily fixed.                                                          |

---

#### Project Summary

| Title              | Description                   |
| ------------------ | ----------------------------- |
| Client             | Marketplace                   |
| Project name       | Marketplace                   |
| Timeline           | March 12 2023 - March 13 2023 |
| Number of Auditors | 1                             |

---

#### Project Scope

The audit covered the following files:

| File name   | Link                |
| ----------- | ------------------- |
| Marketplace | src/Marketplace.sol |

---

### Summary of findings

| Severity | # of Findings |
| -------- | ------------- |
| CRITICAL | 9             |
| HIGH     | 1             |
| MEDIUM   | 6             |
| LOW      | 14            |

---

## FINDINGS REPORT

### 1.1 Critical

#### 1. Loss of access to NFT due to use of `transferFrom`

##### Description

Line: 141

Buy (call the `buy` function) NFT can make not only EOA account, in this case when transferring token with `transferFrom` there is no check if CA supports acceptance of ERC-721 tokens. If there is no function in the smart-contract to interact with the NFT smart-contract, the token will be lost.

##### Recommendation

Use the `safeTransferFrom` function instead of `transferFrom`

---

#### 2. Not provided logic: tokens with commission

##### Description

Line: 73-74

A transferable token can include a commission, examples of such tokens are USDT. This leads to the fact that the actual amount received will not correspond to the amount recorded in the `_rewardsAmount` variable.

The result may be that the user who later tries to withdraw funds may face a shortage of money on the contract, as the recorded amount is greater than the actual amount received, making it impossible to withdraw them.

```Solidity
        PAYMENT_TOKEN.transferFrom(payer, address(this), amount);
        _rewardsAmount += amount;
```

##### Recommendation

Check the obtained token value.

---

#### 3. Changing the length of the array in the loop.

##### Description

Line: 46, 66

Changing the length of an array when iterating over it can lead to unacceptable smart contract behavior.

##### Recommendation

Do not change the length of the array while iterating over it.

---

#### 4. Unable to withdraw funds due to an error with the length of the array

##### Description

Line: 43 - 46

Due to the fact that the length of the array is taken before the iteration in the loop and in the process changes a critical error is made.

For example, a user with one reward tries to withdraw it:

`length = 1`
`i = 0`

```Solidity
    Reward storage reward = _rewards[user][length - i]; // Must be _rewards[user][0] for correct work, but actual result is error : _rewards[user][1].
```

The result is an error: `Index out of bounds`, because the `_rewards` array has an element only under index 0, but not 1.

[Test case](https://github.com/KumaCrypto/Oxorio-Interview-audit/blob/6eccd8290053f5b44f7b1943e0ceb9f0c46f8556/test/Marketplace.t.sol#L160-L173)

##### Recommendation

Rework the logic of rewarding users

---

#### 5. Unchecked ERC-20 `transferFrom`

##### Description

Line: 73

The return value of an external transferFrom call is not checked. Several tokens do not revert in case of failure and return false.

Assumed scenario:
The user buys an NFT, after which tokens must be transferred from his balance to the `Marketplace` balance for further withdrawal by the seller. But at the moment of transfer, an error occurs which is not tracked and the transfer did not actually happen, but the `_rewardsAmount` variable is increased and an opportunity is created for the seller to withdraw if someone else's tokens are on the `Marketplace` balance and he withdraws someone else's funds or faces the problem of insufficient balance.

##### Recommendation

Use SafeERC20, or ensure that the `transferFrom` return value is checked.

---

#### 6. Unchecked ERC-20 `transfer`

##### Description

Line: 69

The return value of an external transfer call is not checked. Several tokens do not revert in case of failure and return false.

Assumed scenario:
The user is trying to withdraw funds.
First the information that the user is to be paid is removed and the `transfer` function is called, which finishes unsuccessfully, but `Marketplace` does not check this and considers that the transfer was successful and finishes its execution.

As a result, the user has not received their funds, and the balance `Marketplace` remained unchanged, which leads to irretrievable loss of funds.

##### Recommendation

Use SafeERC20, or ensure that the `transfer` return value is checked.

---

#### 7. Using a weak PRNG

##### Description

Line: 57

Using a weak random source. The initial values are known to everyone and everyone can calculate the result locally, waiting for the winning option.
The block creator can also influence to block.timestamp.

More: [SWC-120](https://swcregistry.io/docs/SWC-120)

##### Recommendation

Use more reliable sources of randomness, such as oracles.

---

#### 8. The attacker may not allow users to accumulate rewards

##### Description

Line: 42 - 54

If you call the `claim` function immediately after selling NFT, the result of calculating the reward amount will be 0, since the `daysDelta` variable in the `payRewards` function will be equal to 0.

An attacker can take advantage of this by tracking users who have just sold a NFT and calling the `claim` function with the victim's address as an argument. Thereby not allowing the user to accumulate a reward.

##### Recommendation

Allow the `claim` function to be called only for itself and remove the `user` argument.

---

#### 9. Possible transfer of NFT, without the consent of the owner.

##### Description

Line: 130 - 144

Such a situation may occur:

1. The token owner puts it up for sale for a low price.
2. Negotiates the sale of a token on another platform with a user who has `setApprovalForAll` or `Approve` for `Marketplace`.
3. Calls the `buy` function and takes the token back to itself.

[Test case](https://github.com/KumaCrypto/Oxorio-Interview-audit/blob/6eccd8290053f5b44f7b1943e0ceb9f0c46f8556/test/Marketplace.t.sol#L175-L197)

##### Recommendation

At the time of sale, transfer the token to the `Marketplace`.

---

### 1.2 High

#### 1. Overflow `ItemSale.startTime` variable

##### Description

Line: 124 - 127

The user can put the token for sale, then take advantage of the fact that the `postponeSale` function uses an assembly that does not check for variable overflow, to pass a value that will cause an overflow and further malfunction of the smart-contract.

[Test case](https://github.com/KumaCrypto/Oxorio-Interview-audit/blob/6eccd8290053f5b44f7b1943e0ceb9f0c46f8556/test/Marketplace.t.sol#L128-L158)

##### Recommendation

Do not use the assembly to change the value of a variable.

---

### 1.3 Medium

#### 1. Putting the same token on sale when it is already on sale

##### Description

Line: 106

In the function `setForSale` there is no check that the token is on sale and therefore the user, can re-call `setForSale` that will overwrite the data stored in `items`.

In `Marketplace` contract is an unused custom error: `AlreadyOnSale`, which logically should have been used in the check.

[Test case](https://github.com/KumaCrypto/Oxorio-Interview-audit/blob/6eccd8290053f5b44f7b1943e0ceb9f0c46f8556/test/Marketplace.t.sol#L72-L88)

##### Recommendation

Add a check that the token is already on sale.

---

#### 2. Prohibit the use of token for operator and approved user

##### Description

Line: 107, 115, 121

The `ERC-721` standard provides for the use of a particular token not only by the owner, but also for the operator and for the approved user.
Using the check on line 107 - prohibits authorized persons from using their right to the token.

##### Recommendation

Allow the operator and approved user to use the token in a smart-contract by adding additional checks.

---

#### 3. The price of the token on sale can be equal to zero

##### Description

Line: 106 - 112

The user can set the price of the token to zero, which makes the deal initially incorrect, because the buy function has a check for a price equal to 0.

The user's way:

1. Call the `setForSale` function with a price other than zero.
2. Call the `setForSale` function with a price equal to zero.

[Test case](https://github.com/KumaCrypto/Oxorio-Interview-audit/blob/6eccd8290053f5b44f7b1943e0ceb9f0c46f8556/test/Marketplace.t.sol#L90-L103)

##### Recommendation

Add a check that the selling price of the token is not 0.

---

#### 4. Ability to call `postponeSale` for a token that is not on sale.

##### Description

Line: 120 - 128

Inside the function, it only checks that the caller is the owner, but the token may not be on sale.

##### Recommendation

Add a check that the token for which the function is called is on sale.

Add a check that the selling price of the token is not 0.

[Test case](https://github.com/KumaCrypto/Oxorio-Interview-audit/blob/6eccd8290053f5b44f7b1943e0ceb9f0c46f8556/test/Marketplace.t.sol#L117-L126)

#### 5. Failure to buy if seller did not approve OR setApprovalForAll to marketplace

##### Description

Line: 130 - 144

The user can put the token up for sale, but not allow the marketplace to transfer the token from his balance.
In this case, no one will be able to buy the token, facing DoS.

##### Recommendation

When placing a token for sale, transfer it to the `Marketplace` and when selling it, transfer it to the user directly from the сontract.

---

#### 6. Divide before multiply

##### Description

Line: 59

Solidity's integer division truncates. Thus, performing division before multiplication can lead to precision loss.

##### Recommendation

Consider ordering multiplication before division.

---

### 1.4 Low

#### 1. Floating Pragma Vulnerability

##### Description

Line: 3

A floating version of the pragma is used. A version of the pragma with known vulnerabilities can be used to compile a smart-contract, resulting in an increased risk of hacking.

##### Recommendation

Using a fixed version of the pragma.
Preferably, the version should be neither too old nor too recent to have security bugs attached to them.

---

#### 2. Importing the interface of a smart contract that is not in use

##### Description

Line: 6

An interface `IERC20Metadata` that is not used in smart-contracts is imported into the file.

##### Recommendation

Delete `IERC20Metadata` interface import that are not in use.

---

#### 3. Importing and attaching a library to a data type that is not in use

##### Description

Line: 8, 17

The `SafeMath` library, which is not used in smart-сontacts, is imported and attached to uint256 type.

##### Recommendation

Delete `SafeMath` library import and attaching to `uint256` that are not in use.

---

#### 4. The `PAYMENT_TOKEN` variable can be marked as immutable

##### Description

Line: 29

The values for the `PAYMENT_TOKEN` variable are set once in the constructor. No single function can change the value, which leads to the conclusion that the variable can be marked as immutable.

This results in gas savings during smart-contract deployment and significantly reduces user interaction costs.

##### Recommendation

Mark `PAYMENT_TOKEN` as immutable.

---

#### 5. The `REWARD_TOKEN` variable can be marked as immutable

##### Description

Line: 30

The values for the `REWARD_TOKEN` variable are set once in the constructor. No single function can change the value, which leads to the conclusion that the variable can be marked as immutable.

This results in gas savings during smart-contract deployment and significantly reduces user interaction costs.

##### Recommendation

Mark `REWARD_TOKEN` as immutable.

---

#### 6. A misleading variable name: `_rewardsAmount`

##### Description

Line: 32

In the `buy` function where the NFT is paid for, the `depositForRewards` function is called, which sends tokens from the buyer's balance to the contract balance and adds the value to `_rewardsAmount`, effectively saying that the variable stores the amount received from the NFT sale, not the rewards that are also present in the smart contract.

##### Recommendation

Change the name of the `_rewardsAmount` variable to something more appropriate.

---

#### 7. Lack of zero address checks in constructors

##### Description

Line: 37-40, 98-103

Both contracts: `Rewardable` and `Marketplace` take addresses of other smart-contracts in the constructors, inadvertently the values can be equal to zero address (0x0), leading to invalid smart-contract state.

##### Recommendation

Add checks for equality of passed arguments to zero address.

---

#### 8. Unused custom error: `AlreadyOnSale`

##### Description

Line: 85

The `AlreadyOnSale` error is not used in the smart-contract and can be removed.

##### Recommendation

Remove the `AlreadyOnSale` error from the smart-contract.

---

#### 9. Reduce structure size by packing variables in `ItemSale`

##### Description

Line: 87

The structure `ItemSale` occupies 3 memory slots although the structure may only take up 2 storage slots.
This will give great savings in gas.

```solidity
    struct ItemSale {
        address seller; // `seller` takes 20 bytes, and 12 bytes are left free.
        uint256 price;
        uint256 startTime; // `startTime` takes 32 bytes (full slot) and can takes only 12 bytes.
    }
```

##### Recommendation

Change the type of variable `startTime` from uint256 to uint96, which takes 12 bytes and change the order of the variables in struct.

It is possible to pack `seller` and `startTime` variables into one slot, since `block.timestamp`, which is stored in the variable `startTime` will not come close to the maximum value of uint96 for the next few thousand years.

Suggested improvements:

```solidity
    struct ItemSale {
        address seller; // 20 bytes ----\
                                          1 slot
        uint96 startTime; // 12 bytes --/
        uint256 price;
    }
```

---

#### 10. No check for the upper limit of the `startTime` in `setForSale`

##### Description

Line: 106 - 112

The user can set an arbitrary `startTime` of the sale, which can violate the logic of the platform.

##### Recommendation

Add a check for the maximum delay in the start of sell.

---

#### 11. No events in smart-contracts

##### Description

There are no events in the smart-contract, which makes it impossible to track sales information.

##### Recommendation

Emit an event for critical parameter changes.

---

#### 12. The access check can be put in a modifier.

##### Description

Line: 107, 115, 121

The token ownership check is repeated in three functions. This part of the code can be put into a modifier.

```Solidity
    if (NFT_TOKEN.ownerOf(tokenId) != msg.sender) revert NotItemOwner();
```

##### Recommendation

Use a modifier to check token ownership.

---

#### 13. Excessive waste of gas by reading from storage

##### Description

Line: 130 - 144

The `buy` function reads information from the `items[tokenId]` structure 5 times, which is very expensive.

##### Recommendation

Save structure to a local variable stored in memory.

---

#### 14. Misleading returned error in `buy` function

##### Description

Line: 130 - 144

For the 4 different error scenarios, the same error is used, giving no context to the user as to why it occurred.

##### Recommendation

Create individual errors, describing the reason for their occurrence and use.

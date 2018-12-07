# CanSwap - WIP

## What is CanSwap?
CanSwap uses ethereum-based continuous liquidity pools to allow on-chain conversions of tokens and ether into and out of CAN. 
The continuous liquidity pools are permissionless; anyone can add or remove liquidity and anyone can use the pools to convert between assets. 
The pools rely on permissionless arbitrage to ensure correct market pricing of assets at any time. 


## Contract overview
  - `Solc` version `0.5.x`
  - OpenZeppelin contracts (and tests) for `Ownership`, `SafeMath`, `ERC20`

### Core functionality
__*minimum staking threshold*__ - This is a pool share percentage which any prospective staker must exceed in order for her stake to be accepted.  

__*pool share*__ - This is the value of a stake in respect to the total value in a pool. For example, a staker in pool with 1000 TKN1 and 500TKN2, who has staked 100 TKN1 and 250 TKN2 will have a 30% average pool share ((10% TKN1 + 50% TKN2) / 2).  

__*pool fees*__ - These are service fees collected during the `swap` function (when pool users change from 1 token to the other). These fees remain *unallocated* and tied to the pool until *allocateFees* is called  


#### createPoolForToken
  - Create a liquidity pool paired with CAN and perform initial stake.  
  - Calls `stakeInPool` so user __must pre approve the transfer of CAN and TKN__ that they wish to deposit (unless using ETH, in which case they should transfer ETH). 
  - This function creates a default `active` pool and sets the required `minimum staking threshold` to 10%.  


#### stakeInPool
  - Allows users to become a staker in a pool (or re-enter if they previously withdrew), provided they do not currently have a stake. `minimum staking threshold` is also applied here in order to limit the staker count.
  - They __must pre approve the transfer of CAN and TKN__ that they wish to deposit.
  - To provide a soft cap on the number of stakers in a pool, it is required to execute the `allocateFees` function upon deposit, to ensure that consequent executions of `allocateFees` do not exceed some maximum, un-executable limit. 
  - Transfers the stake to the contract and updates all the required mappings to keep track of staker and pool activity


#### addStakeInPool
  - Allows existing stakers to update their stake values

#### swap / swapAndSend
  - User of a pool can swap from one currency to the other, using the mathematics outlined in the [whitepaper](https://github.com/canyaio/canswap-contracts/blob/master/resources/Whitepaper.pdf)
  - The emitted tokens are then sent to the message sender, or, if specified - some recipient account

#### allocateFees
  - Cycles through all of the `active` stakers in a pool (those who actually have a stake), distributing the unallocated `poolFees` based on the stakers __current__ `pool share`
  - Specifically implemented so that it will remain at some constant gas cost (i.e. stakers withdrawing/updating/etc will not cause the cost of gas to fluctuate).. this is __important__ as it means that we can avoid having too many stakers and causing a locked pool as stakers are required to execute this function when they want to join/rejoin the pool

#### withdrawFromPool
  - Allows a staker to completely withdraw her stake && __allocated__ fees from the pool
  - It is advised to call `allocateFees` before doing so in order to get a share of the most recently collected fees

#### withdrawFees
  - Allows an __active__ staker to claim her fees from a particular pool



### Helper methods for client
  - `getAllocationReward` returns the rewardTKN and rewardCAN a staker will receive if they call the `allocateFees` function
  - `caculateSwapEmission` returns (tokensEmitted, feeSingleSwap, feeDoubleSwap): The prospective swap output that a user will receive, and any fees incurred along the process (first swap/second swap)
  - `getPoolMeta` returns (uri, api, active, minimumStake)
  - `getPoolMeta` returns (balTKN, balCAN, unallocated feeTKN, unallocated feeCAN)
  - `getStakersPools` returns (address[] pools)
  - `getStakersStake` returns (stakeTKN, stakeCAN, allocated rewardTKN, allocated rewardCAN)

## Test procedure
 - Unit tests do xxxxxxxxxxxx
 - Coverage provides xxxxxxxxxxx

### CI
 - Tests auto execute via Gitlab CI (`.gitlab-ci.yml`) using the following commands 

```json
"scripts": {
    "test": "truffle test",
    "coverage": "solidity-coverage",
    "lint": "solium -d ./contracts"
  }
```

## Limitations
 - Allocate fees must be called intermittently in order to optimise staker rewards
 - Upper limit on number of stakers allowed in each pool due to the gas usage involved in allocating fees

## Run locally
 - Migrations do xxxxxxxxxxxx

## Resources
:page_with_curl: [Whitepaper](https://github.com/canyaio/canswap-contracts/blob/master/resources/Whitepaper.pdf)


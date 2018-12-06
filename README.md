# CanSwap - WIP

## What is CanSwap?
CanSwap uses ethereum-based continuous liquidity pools to allow on-chain conversions of tokens and ether into and out of CAN. 
The continuous liquidity pools are permissionless; anyone can add or remove liquidity and anyone can use the pools to convert between assets. 
The pools rely on permissionless arbitrage to ensure correct market pricing of assets at any time. 


## Contract overview
 - `Solc` version `0.5.x`
 - OpenZeppelin contracts (and tests) for `Ownership`, `SafeMath`, `ERC20` etc 

## Test procedure
 - Tests auto execute via Gitlab CI (`.gitlab-ci.yml`) using the following commands 

```json
"scripts": {
    "test": "truffle test",
    "coverage": "solidity-coverage",
    "lint": "solium -d ./contracts"
  }
```
 - Unit tests do xxxxxxxxxxxx
 - Coverage provides xxxxxxxxxxx

## Limitations
 - Allocate fees must be called intermittently in order to optimise staker rewards
 - Upper limit on number of stakers allowed in each pool due to the gas usage involved in allocating fees
   - Work around solutions to limiting this number will have knock on effects throughout the contract

## Run locally
 - Migrations do xxxxxxxxxxxx

## Resources
:page_with_curl: [Whitepaper](https://github.com/canyaio/canswap-contracts/blob/master/resources/Whitepaper.pdf)


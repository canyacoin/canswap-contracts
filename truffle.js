/*
 * NB: since truffle-hdwallet-provider 0.0.5 you must wrap HDWallet providers in a 
 * function when declaring them. Failure to do so will cause commands to hang. ex:
 * ```
 * mainnet: {
 *     provider: function() { 
 *       return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/<infura-key>') 
 *     },
 *     network_id: '1',
 *     gas: 4500000,
 *     gasPrice: 10000000000,
 *   },
 */


const HDWalletProvider = require('truffle-hdwallet-provider');
const infuraKey = "xx";

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!

  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      gasPrice: 0x1,
      gas: 0x1fffffffffff,
      network_id: '*'
    },
    rinkeby: {
      provider: function() { 
        return new HDWalletProvider(process.env.WALLET_MNEMONIC, `https://rinkeby.infura.io/${infuraKey}`) 
      },
      network_id: 4,
      gasPrice: 10000000000, // 10 GWei
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  compilers: {
    solc: {
      version: "0.5.1"
    }
  }
};
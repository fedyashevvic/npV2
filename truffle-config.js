require('babel-register');
require('babel-polyfill');

const mnemonic = "expose bar release sibling deny mother donkey blue creek furnace employ fault";
const HDWalletProvider = require("truffle-hdwallet-provider");

module.exports = {
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    bscscan: 'F9Q22WM1GUFG6US2QPS4GTZDT8J2J82NVK'
  },
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
      gas: 10000000,
      gasPrice: 10000000000,  // Match any network id
    },
    testnet: {
      provider: function() { 
       return new HDWalletProvider(mnemonic, "https://data-seed-prebsc-1-s1.binance.org:8545/");
      },
      network_id: 97,
      gas: 10000000,
      gasPrice: 10000000000,
    }
  },
  contracts_directory: './src/contracts/',
  contracts_build_directory: './src/abis/',
  compilers: {
    solc: {
      version: "0.8.0",
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: "petersburg"
    }
  }
}
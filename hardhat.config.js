require('@nomiclabs/hardhat-ethers');
require('dotenv').config();
require('@typechain/hardhat');
require('@typechain/hardhat/dist/type-extensions');

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      hardfork: 'london',
      allowUnlimitedContractSize: true,
      gasPrice: 'auto',
      forking: {
        url: process.env['MAINNET_RPC'],
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.11',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"]
            },
          }
        },
      },
    ],
  },
  typechain: {
    outDir: 'typechained',
    target: 'ethers-v5',
  },
  paths: {
    sources: './solidity',
  },
};

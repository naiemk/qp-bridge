import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { ethers } from "ethers";
import "@nomicfoundation/hardhat-verify";
import "@nomicfoundation/hardhat-ignition-ethers";

require("dotenv").config({path: __dirname + '/localConfig/.env'});
console.log(__dirname + '/localConfig/.env');
const panick = (msg: string) => { throw new Error(msg) }

const accounts: any = process.env.TEST_ACCOUNT_PRIVATE_KEY ? [process.env.TEST_ACCOUNT_PRIVATE_KEY] :
  process.env.TEST_ACCOUNT_PRIVATE_KEY ? { mnemonic: process.env.TEST_MNEMONICS } : panick("TEST_ACCOUNT_PRIVATE_KEY or TEST_MNEMONICS is not set");

if (accounts?.mnemonic) {
    let mnemonicWallet = ethers.HDNodeWallet.fromPhrase(accounts.mnemonic);
    console.log('Test account used from MNEMONIC', mnemonicWallet.privateKey, mnemonicWallet.address);
} else {
  let wallet = new ethers.Wallet(accounts[0]);
  console.log('Single test account used:', wallet.address);
}
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      { version: "0.8.20", settings: { optimizer: { enabled: true, runs: 200 } } },
      { version: "0.8.22", settings: { optimizer: { enabled: true, runs: 200 } } },
      { version: "0.8.24", settings: { optimizer: { enabled: true, runs: 200 } } }
    ]
  },
  networks: {
    arbitrumOne: {
      chainId: 42161,
      url: process.env.ARBITRUM_RPC! || panick("ARBITRUM_RPC is not set. Set it in ./localConfig/.env"),
      accounts,
    },
    ferrum_mainnet: {
      chainId: 26100,
      url: "https://qpn.svcs.ferrumnetwork.io/",
      accounts,
      allowUnlimitedContractSize: true,
      //gas: 1000000, // this override is required for Substrate based evm chains
    },
  },
  
  etherscan: {
    // Your API key for Etherscan
    apiKey: {
      // bscTestnet: getEnv("BSCSCAN_API_KEY"),
      // polygonMumbai: getEnv("POLYGONSCAN_API_KEY"),
      // btfd_ghostnet: getEnv("POLYGONSCAN_API_KEY"),
      arbitrumOne: process.env.ARBISCAN_API_KEY!,
      base: process.env.BASESCAN_API_KEY!,
      bsc: process.env.BSCSCAN_API_KEY!,
      ferrum_testnet: 'empty',
      ferrum_mainnet: 'empty',
    },
      customChains: [
    {
      network: "ferrum_mainnet",
      chainId: 26100,
      urls: {
        apiURL: "https://explorer.ferrumnetwork.io/api",
        browserURL: "http://explorer.ferrumnetwork.io/"
      }
    }
  ]
  },
  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true
  },
  ignition: {
    requiredConfirmations: 1,
    strategyConfig: {
      create2: {
        // To learn more about salts, see the CreateX documentation
        // salt: "0x0000000000000000000000000000000000001000000000000000000000000002"
        salt: "0x46657272756D4E6574776F726B2D71706272696467653A30312E3030302E3030", // FerrumNetwork-mainnet:01.001.002
      },
    },
  },
};

export default config;

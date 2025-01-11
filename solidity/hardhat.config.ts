import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { ethers } from "ethers";
import "@nomicfoundation/hardhat-verify";

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
  solidity: "0.8.20",
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
      gas: 1000000, // this override is required for Substrate based evm chains
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
  }
};

export default config;

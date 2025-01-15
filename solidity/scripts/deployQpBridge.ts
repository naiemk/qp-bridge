import hre from "hardhat";
import { ethers } from "hardhat";
import { QpBridge, } from "../typechain-types";
import { CONFIG, panick } from "./bridge.config";

async function main() {
  // deploy qp bridge
  const deployer = (await hre.ethers.getSigners())[0];
  const owner = process.env.OWNER || deployer.address;
  console.log("Deployer:", deployer.address);

  const currentChainId = (await ethers.provider.getNetwork().then(network => network.chainId)).toString();
  console.log("Current chain id:", currentChainId);
  console.log("Owner:", owner);

  const config = CONFIG[currentChainId] || panick(`No config for chain id ${currentChainId}`);
  
  const factory = await ethers.getContractFactory("QpBridge");
  const qpBridge = config.bridge ? factory.attach(config.bridge) as QpBridge : await factory.deploy(owner) as QpBridge;
  console.log("QpBridge is at:", qpBridge.target);

  console.log('Calling swap...')
  const tx = await qpBridge.swap(42161, "0x0000000000000000000000000000000000000001",
   "1000000000000000000", "5880000000000000", {value: 5880000000000000n + 1000000000000000000n});
  console.log('Tx:', tx);
  await tx.wait();
  console.log('Swapped');

  return

  console.log('Updating dependencies...')
  const remoteChainIds = Object.keys(config.remotePeers);
  const remotePeers = Object.values(config.remotePeers);
  const missingIdx = remotePeers.findIndex(peer => !peer);
  if (missingIdx !== -1) {
    panick(`Missing peer for chain id ${remoteChainIds[missingIdx]}`);
  }
  // await qpBridge.updateRemotePeers(
  //   remoteChainIds.map(Number), remotePeers);
  console.log('Updating portal...')
  await qpBridge.updatePortal(config.portal);

  // console.log('Update tokens')
  // for (const chainId of Object.keys(config.remotePairs)) {
  //   console.log(`Updating tokens for chain ${chainId}`);
  //   for (const token of Object.keys(config.remotePairs[chainId])) {
  //     console.log(`Updating token ${token} for chain ${chainId}`);
  //     await qpBridge.updateRemotePair(chainId, token, config.remotePairs[chainId][token]);
  //   }
  // }
}

main().catch(error => {
    console.error(error);
    process.exit(1);
});

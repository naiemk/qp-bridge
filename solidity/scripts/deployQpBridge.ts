import { ethers } from "hardhat";
import { QpBridge, } from "../typechain-types";

interface Dependencies {
  bridge?: string;
  portal: string;
  remotePeers: {
    [chainId: string]: string;
  }
  remotePairs: {
    [chainId: string]: {
      [token: string]: string;
    }
  }
}

const DEPENDENCIES_ARBITRUM: Dependencies = {
  bridge: "",
  portal: "",
  remotePeers: {
    "26100": "",
  },
  remotePairs: {
    "26100": {
      "0x9f6abbf0ba6b5bfa27f4deb6597cc6ec20573fda": "0x0000000000000000000000000000000000000001",
    },
  }
}

const DEPENDENCIES_FERRUM: Dependencies = {
  bridge: "",
  portal: "",
  remotePeers: {
    "42161": "",
  },
  remotePairs: {
    "42161": {
      "0x0000000000000000000000000000000000000001": "0x9f6abbf0ba6b5bfa27f4deb6597cc6ec20573fda",
    },
  }
}

const CONFIG: { [chainId: string]: Dependencies } = {
  "42161": DEPENDENCIES_ARBITRUM,
  "26100": DEPENDENCIES_FERRUM,
}

const panick = (msg: string) => { throw new Error(msg) }

async function main() {
  // deploy qp bridge
  const owner = process.env.OWNER ?? panick("OWNER is not set");
  const currentChainId = (await ethers.provider.getNetwork().then(network => network.chainId)).toString();
  console.log("Current chain id:", currentChainId);
  console.log("Owner:", owner);

  const config = CONFIG[currentChainId] || panick(`No config for chain id ${currentChainId}`);
  
  const factory = await ethers.getContractFactory("QpBridge");
  const qpBridge = config.bridge ? factory.attach(config.bridge) as QpBridge : await factory.deploy(owner) as QpBridge;
  console.log("QpBridge is at:", qpBridge.target);

  console.log('Updating dependencies...')
  const remoteChainIds = Object.keys(config.remotePeers);
  const remotePeers = Object.values(config.remotePeers);
  const missingIdx = remotePeers.findIndex(peer => !peer);
  if (missingIdx !== -1) {
    panick(`Missing peer for chain id ${remoteChainIds[missingIdx]}`);
  }
  await qpBridge.updateRemotePeers(
    remoteChainIds.map(Number), remotePeers);
  await qpBridge.updatePortal(config.portal);

  console.log('Update tokens')
  for (const chainId in Object.keys(config.remotePairs)) {
    for (const token in Object.keys(config.remotePairs[chainId])) {
      await qpBridge.updateRemotePair(chainId, token, config.remotePairs[chainId][token]);
    }
  }
}

main().catch(error => {
    console.error(error);
    process.exit(1);
});

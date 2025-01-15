import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { CONFIG } from "../../scripts/bridge.config";

const deployModule = buildModule("UpdatePeers", (m) => {    
    const currentChainId = hre.network.config.chainId!;
    if (!currentChainId) {
        throw new Error("Chain ID not found. Configure it in hardhat.config.ts");
    }
    const config = CONFIG[currentChainId.toString()]
    if (!config) {
        throw new Error(`No config for chain id ${currentChainId}`);
    }

    const bridge = m.contractAt("QpBridgeUpgradeable", config.bridge!, { id: "bridge_at_01"})

    // Update remote peers
    const remoteChainIds = Object.keys(config.remotePeers);
    const remotePeers = Object.values(config.remotePeers);
    m.call(bridge, "updateRemotePeers", [remoteChainIds, remotePeers], { id: 'qp_update_peers_01'})

    return {bridge}
})

export default deployModule;


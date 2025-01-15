import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { CONFIG } from "../../scripts/bridge.config";

const deployModule = buildModule("DeployModule", (m) => {    
    const currentChainId = hre.network.config.chainId!;
    const owner = m.getAccount(0)
    if (!currentChainId) {
        throw new Error("Chain ID not found. Configure it in hardhat.config.ts");
    }
    const config = CONFIG[currentChainId.toString()]
    if (!config) {
        throw new Error(`No config for chain id ${currentChainId}`);
    }

    const bridgeImpl = m.contract("QpBridgeUpgradeable", [], { id: "bridge_impl_01"})
    const initializeCalldata = m.encodeFunctionCall(bridgeImpl, "initialize", [
        owner,
        config.portal
    ]);
    const bridgeProxy = m.contract("ERC1967Proxy", [bridgeImpl, initializeCalldata], { id: "bridge_proxy_01"})
    const bridge = m.contractAt("QpBridgeUpgradeable", bridgeProxy, { id: "bridge_01"})

    // Update remote peers
    const remoteChainIds = Object.keys(config.remotePeers);
    const remotePeers = Object.values(config.remotePeers);
    m.call(bridge, "updateRemotePeers", [remoteChainIds, remotePeers], { id: 'qp_update_peers_01'})

    // Update remote pairs
    const chains: string[] = [];
    const toks: string[] = [];
    const remToks: string[] = [];
    for (const chainId of Object.keys(config.remotePairs)) {
        const tokens = Object.keys(config.remotePairs[chainId]);
        for (const token of tokens) {
            const remoteToken = config.remotePairs[chainId][token];
            chains.push(chainId)
            toks.push(token);
            remToks.push(remoteToken);
        }
    }
    m.call(bridge, "updateRemotePairs", [chains, toks, remToks], { id: `qp_update_pairs_01`})

    return {bridge}
})

export default deployModule;

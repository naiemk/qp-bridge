import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { CONFIG } from "../../scripts/bridge.config";

const deployModule = buildModule("UpdatePortal", (m) => {    
    const currentChainId = hre.network.config.chainId!;
    if (!currentChainId) {
        throw new Error("Chain ID not found. Configure it in hardhat.config.ts");
    }
    const config = CONFIG[currentChainId.toString()]
    if (!config) {
        throw new Error(`No config for chain id ${currentChainId}`);
    }

    const bridge = m.contractAt("QpBridgeUpgradeable", config.bridge!, { id: "bridge"})

    // Update remote peers
    const portal = config.portal
    m.call(bridge, "updatePortal", [portal], { id: 'qp_update_portal'})

    return {bridge}
})

export default deployModule;


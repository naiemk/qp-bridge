import hre from "hardhat";
import { ethers } from "hardhat";
import { QPTest, } from "../typechain-types";
import { QpBridge } from "../typechain-types/contracts/qp-bridge.sol/QpBridge";

async function main() {
  const deployer = (await hre.ethers.getSigners())[0];
  console.log("Deployer:", deployer.address);

  const bridge = '0xCB5C2bf299981207928404D42E03044b8ae0CEfe'

  const fac = await hre.ethers.getContractFactory('QpBridgeUpgradeable')
  // const test = await fac.deploy(portal) as QPTest
  const test = fac.attach(bridge) as QpBridge
  console.log('Test bridge deployed to:', test.target)
  await test.sweepNativeTokens('', {gasLimit: 1000000})
}

main()

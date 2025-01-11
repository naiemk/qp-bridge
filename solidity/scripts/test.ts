import hre from "hardhat";
import { ethers } from "hardhat";
import { QPTest, } from "../typechain-types";

async function main() {
  // deploy qp bridge
  const deployer = (await hre.ethers.getSigners())[0];
  console.log("Deployer:", deployer.address);

  const portal = '0xa45baceeb0c6b072b17ef6483e4fb50a49dc5f4b'
  // const QPTest = '0x17BD7CF9d29Da148B52a3075a8f7916ee950f4Df'
  const QPTest = '0x63e6275e457d6508ABCe0C4d146EC04bc5f3BA58'


  const fac = await hre.ethers.getContractFactory('QPTest')
  // const test = await fac.deploy(portal) as QPTest
  const test = fac.attach(QPTest) as QPTest
  console.log('Test deployed to:', test.target)

  const gas = 5880000000000000n

  // console.log('Calling justDoStuff...')
  // const tx0 = await test.justDoStuff({gasLimit: 1000000, value: gas})
  // console.log('Tx:', tx0)
  // await tx0.wait()
  // console.log('Ran justDoStuff')

  // console.log('FUNDING')
  // const wfrm = '0xE500820e95fD701f475fa3C0b5F1aE73e7bf1eD6'
  // const token = await hre.ethers.getContractAt('IERC20', wfrm) as any
  // let toktx = await token.transfer(test.target, hre.ethers.parseEther('1'))
  // console.log('Tx:', toktx)
  // await toktx.wait()


  // console.log('Calling runErc...')
  // const tx = await test.runErc(gas, {gasLimit: 1000000})
  // console.log('Tx:', tx)
  // await tx.wait()
  // console.log('Ran runErc')

  console.log('Running runNative...')
  const nativeTx = await test.runNative({value: gas * 2n, gasLimit: 1000000})
  console.log('Tx:', nativeTx)
  await nativeTx.wait()
  console.log('Ran runNative')

  console.log('Running runDoubleNative...')
  const doubleNativeTx = await test.runDoubleNative({value: gas * 2n, gasLimit: 1000000})
  console.log('Tx:', doubleNativeTx)
  await doubleNativeTx.wait()
  console.log('Ran runDoubleNative')
}

main()

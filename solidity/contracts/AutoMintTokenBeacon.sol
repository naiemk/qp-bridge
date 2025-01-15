// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AutoMintTokenBeacon is UpgradeableBeacon {
    constructor(address initialImplementation, address bridge) UpgradeableBeacon(initialImplementation, bridge) {
    }
}

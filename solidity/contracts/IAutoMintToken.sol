// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IAutoMintToken {
    function burnFromBridge(address from, uint256 amount) external;
    function mintFromBridge(address to, uint256 amount) external;
    function initialize(uint64 sourceChainId, address sourceToken, bytes memory extraData) external;
}

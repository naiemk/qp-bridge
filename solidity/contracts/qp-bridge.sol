// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/WithQp.sol";
import "./interfaces/WithRemotePeers.sol";
import "foundry-contracts/contracts/contracts/common/SafeAmount.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract QpBridge is ReentrancyGuard, WithQp, WithRemotePeers {
    using SafeERC20 for IERC20;
    event SwapRegistered(uint swapId, uint chainId, address token, uint256 amount, address recipient, uint256 nativeGas);
    event SwapProcessedNotPaid(uint swapId, uint chainId, address token, uint256 amount, address recipient);
    event SwapProcessed(uint swapId, uint chainId, address token, uint256 amount, address recipient);
    event SwapRetried(uint swapId, uint chainId, address token, uint256 amount, address recipient, uint256 nativeGas);
    event PendingSwapWithdrawn(address token, uint256 amount, address recipient);

    address public constant NATIVE_TOKEN = address(0x0000000000000000000000000000000000000001);
    struct Swap {
        address token;
        uint256 amount;
        address recipient;
    }

    constructor(address admin) 
        Ownable(admin)
    {}

    receive() external payable {}

    mapping(address => mapping(uint256 => address)) public remotePairs;
    mapping(address => Swap[]) public pendingSwaps;
    mapping(uint => Swap) public registeredSwaps;
    mapping(uint => bool) public processedSwaps;
    uint public swapIdCounter = 0;

    function updateRemotePair(uint256 remoteChainId, address token, address remoteToken) external onlyOwner {
        if (remoteToken == address(0)) {
            delete remotePairs[token][remoteChainId];
        } else {
            remotePairs[token][remoteChainId] = remoteToken;
        }
    }

    function getSwapKey(uint chainId, uint swapId) external pure returns (uint) {
        return swapKey(chainId, swapId);
    }

    function pendingSwapsLength(address user) external view returns (uint256) {
        return pendingSwaps[user].length;
    }

    function swap(uint remoteChainId, address token, uint256 amount, uint256 nativeGas) external payable nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(token != address(0), "Token address cannot be 0");
        address remotePair = remotePairs[token][remoteChainId];
        require(remotePair != address(0), "Remote pair not found");

        if (token == NATIVE_TOKEN) {
            require(msg.value >= amount + nativeGas, "Insufficient native token balance");
        } else {
            require(msg.value >= nativeGas, "Native token balance should be enough for gas");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        uint key = swapKey(remoteChainId, swapIdCounter);
        registeredSwaps[key] = Swap({
            token: remotePair,
            amount: amount,
            recipient: msg.sender
        });
        emit SwapRegistered(swapIdCounter, remoteChainId, token, amount, msg.sender, nativeGas);
        swapIdCounter++;
        _swap(key, remoteChainId, remotePair, amount, msg.sender, nativeGas);
    }

    function retrySwap(uint chainId, uint swapId) external payable nonReentrant {
        uint skey = swapKey(chainId, swapId);
        Swap memory s = registeredSwaps[skey];
        require(s.token != address(0), "Swap not found");
        emit SwapRetried(swapId, chainId, s.token, s.amount, s.recipient, msg.value);
        _swap(skey, chainId, s.token, s.amount, s.recipient, msg.value);
    }

    function _swap(uint key, uint remoteChainId, address remotePair, uint256 amount, address recipient, uint256 nativeGas) internal {
        bytes memory encodedCall = abi.encodeWithSelector(
            this.remoteSwap.selector,
            key,
            remotePair,
            amount,
            recipient
        );
        portal.runNativeFee{value: nativeGas}(uint64(remoteChainId), remotePeers[remoteChainId], address(this), encodedCall);
    }

    function remoteSwap(uint key, address token, uint256 amount, address recipient) external {
        (uint256 sourceNetwork, address sourceMsgSender,) = portal.msgSender();
        require(sourceMsgSender == remotePeers[sourceNetwork], "Call not allowed");
        console.log("sourceNetwork", sourceNetwork);
        require(!processedSwaps[key], "Swap already processed");
        processedSwaps[key] = true;
        console.log("key", key);
        console.log("token", token);
        console.log("amount", amount);
        if (token == NATIVE_TOKEN) {
            uint liquidity = address(this).balance;
            console.log("liquidity", liquidity);
            if (liquidity >= amount) {
                emit SwapProcessed(key, sourceNetwork, token, amount, recipient);
                SafeAmount.safeTransferETH(recipient, amount);
                return;
            }
        } else {
            uint liquidity = IERC20(token).balanceOf(address(this));
            if (liquidity >= amount) {
                emit SwapProcessed(key, sourceNetwork, token, amount, recipient);
                IERC20(token).safeTransfer(recipient, amount);
                return;
            }
        }
        
        emit SwapProcessedNotPaid(key, sourceNetwork, token, amount, recipient);
        Swap memory pendingSwap = Swap({
            token: NATIVE_TOKEN,
            amount: amount,
            recipient: recipient
        });
        pendingSwaps[recipient].push(pendingSwap);
    }

    function withdrawAllPendingSwaps(address user) external {
        uint256 swaplength = pendingSwaps[user].length;
        for (uint256 i = 0; i < swaplength; i++) {
            _withdrawLastPendingSwap(user);
        }
    }

    function clearUserPendingSwaps(address user) external onlyAdmin {
        delete pendingSwaps[user];
    }

    function sweepTokens(address token, address recipient) external onlyOwner {
        IERC20(token).safeTransfer(recipient, IERC20(token).balanceOf(address(this)));
    }

    function sweepNativeTokens(address recipient) external onlyOwner {
        SafeAmount.safeTransferETH(recipient, address(this).balance);
    }

    function _withdrawLastPendingSwap(address user) internal {
        Swap memory pswap = pendingSwaps[user][pendingSwaps[user].length - 1];
        pendingSwaps[user].pop();
        emit PendingSwapWithdrawn(pswap.token, pswap.amount, user);
        if (pswap.token == NATIVE_TOKEN) {
            SafeAmount.safeTransferETH(user, pswap.amount);
        } else {
            IERC20(pswap.token).safeTransfer(user, pswap.amount);
        }
    }

    function swapKey(uint chainId, uint swapId) private pure returns (uint) {
        return chainId << 128 | swapId;
    }

    function parseSwapKey(uint key) private pure returns (uint chainId, uint swapId) {
        chainId = key >> 128;
        swapId = key & ((1 << 128) - 1);
    }
}

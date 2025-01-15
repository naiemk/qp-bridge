// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/WithQpUpgradeable.sol";
import "./interfaces/WithRemotePeersUpgradeable.sol";
import "foundry-contracts/contracts/contracts/common/SafeAmount.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./AutoMintTokenBeacon.sol";
import "./IAutoMintToken.sol";

interface IERC20Extended is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IUpgradeTo {
    function upgradeTo(address newImplementation) external;
    function owner() external view returns (address);
}

contract QpBridgeUpgradeable is
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    WithQpUpgradeable,
    WithRemotePeersUpgradeable
{
    using SafeERC20 for IERC20;
    event SwapRegistered(
        uint swapId,
        uint chainId,
        address token,
        address targetToken,
        uint256 amount,
        address recipient,
        uint256 nativeGas,
        bytes extraData
    );
    event SwapProcessedNotPaid(
        uint swapId,
        uint chainId,
        address sourceToken,
        address token,
        uint256 amount,
        address recipient,
        bytes extraData
    );
    event SwapProcessed(
        uint swapId,
        uint chainId,
        address sourceToken,
        address token,
        uint256 amount,
        address recipient,
        bytes extraData
    );
    event SwapRetried(
        uint swapId,
        uint chainId,
        address sourceToken,
        address token,
        uint256 amount,
        address recipient,
        uint256 nativeGas,
        bytes extraData
    );
    event PendingSwapWithdrawn(
        address token,
        uint256 amount,
        address recipient
    );
    event PendingSwapsCleared(address user);

    address public constant NATIVE_TOKEN =
        address(0x0000000000000000000000000000000000000001);
    address public constant AUTO_MINT_TOKEN =
        address(0x0000000000000000000000000000000000000003);
    struct Swap {
        address sourceToken;
        address token;
        uint256 amount;
        address recipient;
        bytes extraData;
    }

    struct QPBridgeStorageV001 {
        mapping(address => mapping(uint256 => address)) remotePairs;
        mapping(address => Swap[]) pendingSwaps;
        mapping(uint => Swap) registeredSwaps;
        mapping(uint => bool) processedSwaps;
        uint swapIdCounter;
        // Auto-minting
        mapping(uint => bool) autoMintAllowed; // if allowed on target chain
        mapping(bytes32 => address) sourceToAutoMintedToken; // given source chain, what token is minted?
        mapping(address => bytes32) autoMintedTokenToSource; // given minted token, what source chain is it from?
        address autoMintTokenBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.qpbridge.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QPBridgeStorageV001Location =
        0x09e39d3a3359644fce7f31537959a18eb6c32c3679c1ab6a83f4cf8b500b9600;

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function initialize(
        address initialOwnerAdmin,
        address _portal
    ) public initializer {
        __WithQp_init(initialOwnerAdmin, _portal);
        __UUPSUpgradeable_init();
    }

    function _getQpBridgeStorageV001()
        internal
        pure
        returns (QPBridgeStorageV001 storage $)
    {
        assembly {
            $.slot := QPBridgeStorageV001Location
        }
    }

    receive() external payable {}

    function updateRemotePairs(
        uint256[] calldata remoteChainIds,
        address[] calldata tokens,
        address[] calldata remoteTokens
    ) external onlyOwner {
        for (uint i = 0; i < remoteChainIds.length; i++) {
            updateRemotePair(remoteChainIds[i], tokens[i], remoteTokens[i]);
        }
    }

    function updateAutoMintBeacon(address beacon) external onlyOwner {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        $.autoMintTokenBeacon = beacon;
        require(IUpgradeTo(beacon).owner() == address(this), "Beacon not owned by bridge");
    }

    function upgradeAutoMintBeacon(address impl) external onlyOwner {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        IUpgradeTo($.autoMintTokenBeacon).upgradeTo(impl);
    }

    function updateRemotePair(
        uint256 remoteChainId,
        address token,
        address remoteToken
    ) public onlyOwner {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        if (remoteToken == address(0)) {
            delete $.remotePairs[token][remoteChainId];
        } else {
            $.remotePairs[token][remoteChainId] = remoteToken;
        }
    }

    function setAutoMintAllowed(uint remoteChainId, bool allowed) external onlyOwner {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        $.autoMintAllowed[remoteChainId] = allowed;
    }

    function pendingSwapsLength(address user) external view returns (uint256) {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        return $.pendingSwaps[user].length;
    }

    function getRemotePair(
        uint remoteChainId,
        address token
    ) external view returns (address) {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        return $.remotePairs[token][remoteChainId];
    }

    function swap(
        uint remoteChainId,
        address token,
        uint256 amount,
        uint256 nativeGas
    ) external payable nonReentrant {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        require(amount != 0, "Amount must be greater than 0");
        require(token != address(0), "Token address cannot be 0");
        address remotePair = $.remotePairs[token][remoteChainId];
        bytes memory extraData;
        if (remotePair == address(0) && $.autoMintAllowed[remoteChainId]) {
            (remotePair, extraData) = getAutoMintTokenPair(token);
        }
        require(remotePair != address(0), "Remote pair not found");
        bytes32 autoMinted = $.autoMintedTokenToSource[token];

        if (token == NATIVE_TOKEN) {
            require(
                msg.value >= amount + nativeGas,
                "Insufficient native token balance"
            );
        } else if (autoMinted != 0) {
            require(
                msg.value >= nativeGas,
                "Native token balance should be enough for gas"
            );
            IAutoMintToken(token).burnFromBridge(msg.sender, amount);
        } else {
            require(
                msg.value >= nativeGas,
                "Native token balance should be enough for gas"
            );
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        uint swapIdCounter = $.swapIdCounter;
        uint key = swapKey(
            uint64(block.chainid),
            uint64(remoteChainId),
            uint128(swapIdCounter)
        );
        $.registeredSwaps[key] = Swap({
            sourceToken: token,
            token: remotePair,
            amount: amount,
            recipient: msg.sender,
            extraData: extraData
        });
        emit SwapRegistered(
            swapIdCounter,
            remoteChainId,
            token,
            remotePair,
            amount,
            msg.sender,
            nativeGas,
            extraData
        );
        $.swapIdCounter = swapIdCounter + 1;
        _swap(key, remoteChainId, token, remotePair, amount, msg.sender, nativeGas, extraData);
    }

    function getAutoMintTokenPair(address token
    ) internal view returns (address remotePair, bytes memory extraData) {
        extraData = abi.encode(
            IERC20Extended(token).symbol(),
            IERC20Extended(token).decimals(),
            IERC20Extended(token).name()
        );
        remotePair = AUTO_MINT_TOKEN;
    }

    function retrySwap(
        uint chainId,
        uint swapId
    ) external payable nonReentrant {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        uint skey = swapKey(
            uint64(block.chainid),
            uint64(chainId),
            uint128(swapId)
        );
        Swap memory s = $.registeredSwaps[skey];
        require(s.token != address(0), "Swap not found");
        emit SwapRetried(
            swapId,
            chainId,
            s.sourceToken,
            s.token,
            s.amount,
            s.recipient,
            msg.value,
            s.extraData
        );
        _swap(
            skey,
            chainId,
            s.sourceToken,
            s.token,
            s.amount,
            s.recipient,
            msg.value,
            s.extraData
        );
    }

    function _swap(
        uint key,
        uint remoteChainId,
        address sourceToken,
        address remotePair,
        uint256 amount,
        address recipient,
        uint256 nativeGas,
        bytes memory extraData
    ) internal {
        WithQpStorageV001 storage $$ = _getWithQpStorageV001();
        WithRemotePeersStorageV001 storage $$$ = _getWithRemotePeersStorageV001();
        bytes memory encodedCall = abi.encodeWithSelector(
            this.remoteSwap.selector,
            key,
            sourceToken,
            remotePair,
            amount,
            recipient,
            extraData
        );
        $$.portal.runNativeFee{value: nativeGas}(
            uint64(remoteChainId),
            $$$.remotePeers[remoteChainId],
            address(this),
            encodedCall
        );
    }

    function remoteSwap(
        uint key,
        address sourceToken,
        address token,
        uint256 amount,
        address recipient,
        bytes memory extraData
    ) external {
        WithRemotePeersStorageV001 storage $$$ = _getWithRemotePeersStorageV001();
        WithQpStorageV001 storage $$ = _getWithQpStorageV001();
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        (uint256 sourceNetwork, address sourceMsgSender, ) = $$
            .portal
            .msgSender();
        require(
            sourceNetwork != 0 && sourceMsgSender != address(0),
            "Not in context"
        );
        require(
            sourceMsgSender == $$$.remotePeers[sourceNetwork],
            "Call not allowed"
        );
        require(!$.processedSwaps[key], "Swap already processed");
        $.processedSwaps[key] = true;
        if (token == NATIVE_TOKEN) {
            uint liquidity = address(this).balance;
            if (liquidity >= amount) {
                emit SwapProcessed(
                    key,
                    sourceNetwork,
                    sourceToken,
                    token,
                    amount,
                    recipient,
                    extraData
                );
                SafeAmount.safeTransferETH(recipient, amount);
                return;
            }
        } else if (token == AUTO_MINT_TOKEN) {
            address autoMintToken = getOrDeployAutoMintToken(uint64(sourceNetwork), sourceToken, extraData);
            IAutoMintToken(autoMintToken).mintFromBridge(recipient, amount);
            emit SwapProcessed(
                key,
                sourceNetwork,
                sourceToken,
                autoMintToken,
                amount,
                recipient,
                extraData
            );
            return;
        } else {
            if (tryPayErc20(token, recipient, amount)) {
                emit SwapProcessed(
                    key,
                    sourceNetwork,
                    sourceToken,
                    token,
                    amount,
                    recipient,
                    extraData
                );
                return;
            }
        }

        emit SwapProcessedNotPaid(
            key,
            sourceNetwork,
            sourceToken,
            token,
            amount,
            recipient,
            extraData
        );
        Swap memory pendingSwap = Swap({
            sourceToken: sourceToken,
            token: token,
            amount: amount,
            recipient: recipient,
            extraData: extraData
        });
        $.pendingSwaps[recipient].push(pendingSwap);
    }

    function tryPayErc20(
        address token,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        uint liquidity = IERC20(token).balanceOf(address(this));
        if (liquidity >= amount) {
            IERC20(token).safeTransfer(recipient, amount);
            return true;
        }
        return false;
    }

    function withdrawAllPendingSwaps(address user) external {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        uint256 swaplength = $.pendingSwaps[user].length;
        for (uint256 i = 0; i < swaplength; i++) {
            _withdrawLastPendingSwap(user);
        }
    }

    function clearUserPendingSwaps(address user) external onlyAdmin {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        delete $.pendingSwaps[user];
        emit PendingSwapsCleared(user);
    }

    function sweepTokens(address token, address recipient) external onlyOwner {
        IERC20(token).safeTransfer(
            recipient,
            IERC20(token).balanceOf(address(this))
        );
    }

    function sweepNativeTokens(address recipient) external onlyOwner {
        SafeAmount.safeTransferETH(recipient, address(this).balance);
    }

    function _withdrawLastPendingSwap(address user) internal {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        Swap memory pswap = $.pendingSwaps[user][
            $.pendingSwaps[user].length - 1
        ];
        $.pendingSwaps[user].pop();
        emit PendingSwapWithdrawn(pswap.token, pswap.amount, user);
        if (pswap.token == NATIVE_TOKEN) {
            SafeAmount.safeTransferETH(user, pswap.amount);
        } else {
            IERC20(pswap.token).safeTransfer(user, pswap.amount);
        }
    }

    function getOrDeployAutoMintToken(
        uint64 sourceChainId,
        address sourceToken,
        bytes memory extraData
    ) internal returns (address) {
        QPBridgeStorageV001 storage $ = _getQpBridgeStorageV001();
        bytes32 amKey = autoMintKey(sourceChainId, sourceToken);

        // If we already have a minted token for this (chainId, token), return it
        address existing = $.sourceToAutoMintedToken[amKey];
        if (existing != address(0)) {
            return existing;
        }

        // Prepare init data to call `initialize(uint64, address)` on the newly deployed beacon proxy
        bytes memory initData = abi.encodeWithSelector(
            IAutoMintToken.initialize.selector,
            sourceChainId,
            sourceToken,
            extraData
        );

        // Deploy the BeaconProxy using CREATE2 with a deterministic salt
        // This ensures the same salt + beacon + initData => same deployed address on the same chain
        BeaconProxy beaconProxy = new BeaconProxy{salt: amKey}(
            $.autoMintTokenBeacon, // The beacon address
            initData // Initialization calldata
        );

        address mintedTokenAddr = address(beaconProxy);

        // Record the minted token in your mappings
        $.sourceToAutoMintedToken[amKey] = mintedTokenAddr;
        $.autoMintedTokenToSource[mintedTokenAddr] = amKey;

        return mintedTokenAddr;
    }

    function getSwapKey(
        uint sourceChainId,
        uint remoteChainId,
        uint swapId
    ) external pure returns (uint) {
        return
            swapKey(
                uint64(sourceChainId),
                uint64(remoteChainId),
                uint128(swapId)
            );
    }

    function swapKey(
        uint64 sourceChainId,
        uint64 remoteChainId,
        uint128 swapId
    ) private pure returns (uint) {
        return (((sourceChainId << 64) | remoteChainId) << 128) | swapId;
    }

    function parseSwapKey(
        uint key
    )
        private
        pure
        returns (uint sourceChainId, uint remoteChainId, uint swapId)
    {
        uint chainIds = key >> 128;
        swapId = key & ((1 << 128) - 1);
        sourceChainId = chainIds >> 64;
        remoteChainId = chainIds & ((1 << 64) - 1);
    }

    function autoMintKey(
        uint64 sourceChainId,
        address sourceToken
    ) private pure returns (bytes32) {
        return bytes32((bytes32(uint256(sourceChainId)) << 160) | bytes32(bytes20(sourceToken)));
    }

    function parseAutoMintKey(
        bytes32 key
    ) private pure returns (uint64 sourceChainId, address sourceToken) {
        sourceChainId = uint64(uint256(key >> 160));
        sourceToken = address(bytes20(key));
    }
}

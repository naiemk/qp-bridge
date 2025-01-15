// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "./IAutoMintToken.sol";

/**
 * @title AutoMintToken
 * @dev This ERC20 token can only be minted/burned by the Bridge contract. 
 *      Uses explicit storage in a reserved slot for upgrade-safety and supports:
 *         - Custom name + " (QP)"
 *         - Custom symbol
 *         - Custom decimals
 */
contract AutoMintToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    IAutoMintToken
{
    /**
     * @dev Storage layout struct.
     *      Keep ordering consistent if you upgrade later.
     */
    struct AutoMintTokenStorage {
        // The originating chain ID for which this token is a representation
        uint64 sourceChainId;

        // The originating token address on the source chain
        address sourceToken;

        // The address of the Bridge, which is allowed to mint/burn
        address bridge;

        // Extended token metadata
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
    }

    // keccak256("com.yourproject.AutoMintToken.storage.location") => unique ID
    bytes32 private constant STORAGE_SLOT =
        0xd6f4aa454e014d583293d6b12d2776d92dc28a7ccf3cc7dc1def99f8eb6814c2;

    /**
     * @dev Internal helper to access our custom storage struct in the reserved slot.
     */
    function _getStorage() internal pure returns (AutoMintTokenStorage storage st) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            st.slot := slot
        }
    }

    /// @dev Emitted when the bridge burns tokens from a user.
    event BridgeBurned(address indexed from, uint256 amount);

    /// @dev Emitted when the bridge mints tokens to a user.
    event BridgeMinted(address indexed to, uint256 amount);

    function initialize(
        uint64 _sourceChainId,
        address _sourceToken,
        bytes memory _extraData
    ) external override initializer {
        // Store fields in our dedicated struct
        AutoMintTokenStorage storage st = _getStorage();
        st.sourceChainId = _sourceChainId;
        st.sourceToken = _sourceToken;
        st.bridge = msg.sender;

        (string memory _name, string memory _symbol, uint8 _decimals) = abi.decode(_extraData, (string, string, uint8));
        st.tokenName = string(abi.encodePacked(_name, " (QP)"));
        st.tokenSymbol = _symbol;
        st.tokenDecimals = _decimals;

        // Initialize inherited OpenZeppelin contracts:
        __ERC20_init(st.tokenName, st.tokenSymbol);
        __ERC20Burnable_init();
    }

    /**
     * @notice Overriding decimals to return our custom decimals from storage.
     */
    function decimals() public view virtual override returns (uint8) {
        return _getStorage().tokenDecimals;
    }

    /**
     * @notice Burns `amount` of tokens from `from`. Only callable by the bridge.
     * @param from   The address whose tokens will be burned.
     * @param amount The quantity of tokens to burn.
     */
    function burnFromBridge(address from, uint256 amount) external override {
        AutoMintTokenStorage storage st = _getStorage();
        require(msg.sender == st.bridge, "AutoMintToken: Only bridge can burn");
        _burn(from, amount);
        emit BridgeBurned(from, amount);
    }

    /**
     * @notice Mints `amount` of tokens to `to`. Only callable by the bridge.
     * @param to     The address receiving the newly minted tokens.
     * @param amount The quantity of tokens to mint.
     */
    function mintFromBridge(address to, uint256 amount) external override {
        AutoMintTokenStorage storage st = _getStorage();
        require(msg.sender == st.bridge, "AutoMintToken: Only bridge can mint");
        _mint(to, amount);
        emit BridgeMinted(to, amount);
    }

    /**
     * @notice Returns the source chain ID for which this token is a representation.
     */
    function getSourceChainId() external view returns (uint64) {
        return _getStorage().sourceChainId;
    }

    /**
     * @notice Returns the original token address on the source chain.
     */
    function getSourceToken() external view returns (address) {
        return _getStorage().sourceToken;
    }

    /**
     * @notice Returns the address of the bridge allowed to mint/burn.
     */
    function getBridge() external view returns (address) {
        return _getStorage().bridge;
    }
}

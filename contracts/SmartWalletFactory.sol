// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "./SoulWalletProxy.sol";
import "./SmartWallet.sol";
import "./interfaces/ICreate2Deployer.sol";

/*
    a factory contract for create soul wallet
*/
contract SmartWalletFactory {
    address public immutable walletImpl;
    address public immutable singletonFactory;
    string public constant VERSION = "0.0.1";
    mapping(address => bool) public isWalletActive;

    event SoulWalletCreated(
        address indexed _proxy,
        address indexed _owner,
        address indexed _implementation,
        string version
    );

    constructor(address _walletImpl, address _singletonFactory) {
        require(_walletImpl != address(0), "walletImpl error");
        walletImpl = _walletImpl;
        require(_singletonFactory != address(0), "singletonFactory error");
        singletonFactory = _singletonFactory;
    }

    function createWallet(
        address _entryPoint,
        address _owner,
        uint32 _upgradeDelay,
        uint32 _guardianDelay,
        address _guardian,
        bytes32 _salt
    ) public returns (address) {
        bytes memory deploymentData = abi.encodePacked(
            type(SoulWalletProxy).creationCode,
            abi.encode(
                walletImpl,
                abi.encodeCall(
                    SmartWallet.initialize,
                    (
                        IEntryPoint(_entryPoint),
                        _owner,
                        _upgradeDelay,
                        _guardianDelay,
                        _guardian
                    )
                )
            )
        );

        address proxy = ICreate2Deployer(singletonFactory).deploy(
            deploymentData,
            _salt
        );
        require(proxy != address(0), "create2 failed");
        emit SoulWalletCreated(proxy, _owner, walletImpl, VERSION);
        isWalletActive[proxy] = true;
        return proxy;
    }

    function getWalletAddress(
        address _entryPoint,
        address _owner,
        uint32 _upgradeDelay,
        uint32 _guardianDelay,
        address _guardian,
        bytes32 _salt
    ) public view returns (address) {
        bytes memory deploymentData = abi.encodePacked(
            type(SoulWalletProxy).creationCode,
            abi.encode(
                walletImpl,
                abi.encodeCall(
                    SmartWallet.initialize,
                    (
                        IEntryPoint(_entryPoint),
                        _owner,
                        _upgradeDelay,
                        _guardianDelay,
                        _guardian
                    )
                )
            )
        );
        return
            computeAddress(_salt, keccak256(deploymentData), singletonFactory);
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    function computeAddress(
        bytes32 salt,
        bytes32 bytecodeHash,
        address deployer
    ) internal pure returns (address addr) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40) // Get free memory pointer

            // |                   | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
            // |-------------------|---------------------------------------------------------------------------|
            // | bytecodeHash      |                                                        CCCCCCCCCCCCC...CC |
            // | salt              |                                      BBBBBBBBBBBBB...BB                   |
            // | deployer          | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
            // | 0xFF              |            FF                                                             |
            // |-------------------|---------------------------------------------------------------------------|
            // | memory            | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
            // | keccak(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |

            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }
}

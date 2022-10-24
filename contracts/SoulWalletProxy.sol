// SPDX-License-Identifier: MIT
// Some functions are from `OpenZeppelin Contracts`
pragma solidity ^0.8.17;

import "./utils/Address.sol";

contract SoulWalletProxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `logic`.
     *
     * If `data` is nonempty, it's used as data in a delegate call to `logic`. This will typically be an encoded
     * function call, and allows initializing the storage of the proxy like a Solidity constructor.
     */
    constructor(address logic, bytes memory data) payable {
        _upgradeToAndCall(logic, data, true);
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external payable {
        _upgradeTo(newImplementation, false);
    }

    // /**
    //  * @dev Perform implementation upgrade with additional setup call.
    //  *
    //  * Emits an {Upgraded} event.
    //  */
    // function upgradeToAndCall(address newImplementation, bytes memory data)
    //     external
    //     payable
    // {
    //     _upgradeToAndCall(newImplementation, data, false);
    // }

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() private view returns (address implementation) {
        assembly {
            implementation := sload(_IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation, bool force) private {
        require(Address.isContract(newImplementation));
        if (!force) {
            // delegatecall to currentImplementation.upgradeVerifiy(newImplementation) selector is 0x2da77899
            // if can not upgrade, logic contract must "revert"
            Address.functionDelegateCall(
                getImplementation(),
                abi.encodeWithSelector(0x2da77899, newImplementation)
            );
        }
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(getImplementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation, bool force) private {
        _setImplementation(newImplementation, force);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool force
    ) private {
        _upgradeTo(newImplementation, force);
        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }
}

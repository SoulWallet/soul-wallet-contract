// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Address.sol";

abstract contract Upgradeable {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // The mask of the lower 160 bits for addresses.
    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    // The `Upgraded` event signature is given by:
    // `keccak256(bytes("Upgraded(address)"))`.
    bytes32 private constant _UPGRADED_EVENT_SIGNATURE =
        0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation()
        internal
        view
        returns (address implementation)
    {
        assembly {
            implementation := sload(_IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation));
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementationUnsafe(address newImplementation) private {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        assembly {
            // emit Upgraded(newImplementation);
            let _newImplementation := and(newImplementation, _BITMASK_ADDRESS)
            // Emit the `Upgraded` event.
            log2(0, 0, _UPGRADED_EVENT_SIGNATURE, _newImplementation)
        }
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToUnsafe(address newImplementation) internal {
        _setImplementationUnsafe(newImplementation);
        assembly {
            // emit Upgraded(newImplementation);
            let _newImplementation := and(newImplementation, _BITMASK_ADDRESS)
            // Emit the `Upgraded` event.
            log2(0, 0, _UPGRADED_EVENT_SIGNATURE, _newImplementation)
        }
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data)
        internal
    {
        _upgradeTo(newImplementation);
        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    function _initialize(address newImplementation, bytes memory data)
        internal
    {
        _upgradeToUnsafe(newImplementation);
        Address.functionDelegateCall(newImplementation, data);
    }
}

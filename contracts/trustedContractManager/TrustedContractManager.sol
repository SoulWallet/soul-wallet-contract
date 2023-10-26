// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./ITrustedContractManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TrustedContractManager
 * @dev Implementation of the ITrustedContractManager interface
 * Manages and checks the trusted contracts in the system
 */
abstract contract TrustedContractManager is ITrustedContractManager, Ownable {
    /// @notice Mapping to keep track of trusted contracts
    mapping(address => bool) private _trustedContract;

    /**
     * @dev Sets the initial owner of the contract to `_owner`
     * @param _owner Address of the initial owner
     */
    constructor(address _owner) Ownable(_owner) {}

    /**
     * @notice Checks if the given address is a trusted contract
     * @param module Address of the module to be checked
     * @return True if the address is a trusted contract, false otherwise
     */
    function isTrustedContract(address module) external view returns (bool) {
        return _trustedContract[module];
    }
    /**
     * @dev Internal function to check if the given address is a contract
     * @param addr Address to be checked
     * @return isContract True if the address has code (is a contract), false otherwise
     */

    function _isContract(address addr) private view returns (bool isContract) {
        assembly {
            isContract := gt(extcodesize(addr), 0)
        }
    }
    /**
     * @notice Adds one or more contracts to the list of trusted contracts
     * Can only be called by the owner
     * @param modules Addresses of the contracts to be added
     */

    function add(address[] memory modules) external onlyOwner {
        for (uint256 i = 0; i < modules.length; i++) {
            require(_isContract(modules[i]), "TrustedContractManager: not a contract");
            require(!_trustedContract[modules[i]], "TrustedContractManager: contract already trusted");
            _trustedContract[modules[i]] = true;
            emit TrustedContractAdded(modules[i]);
        }
    }
    /**
     * @notice Removes one or more contracts from the list of trusted contracts
     * Can only be called by the owner
     * @param modules Addresses of the contracts to be removed
     */

    function remove(address[] memory modules) external onlyOwner {
        for (uint256 i = 0; i < modules.length; i++) {
            require(_trustedContract[modules[i]], "TrustedContractManager: contract not trusted");
            _trustedContract[modules[i]] = false;
            emit TrustedContractRemoved(modules[i]);
        }
    }
}

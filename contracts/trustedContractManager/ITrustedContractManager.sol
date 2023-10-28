// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title ITrustedContractManager Interface
 * @dev This interface defines methods and events for managing trusted contracts
 */
interface ITrustedContractManager {
    /**
     * @dev Emitted when a new trusted contract (module) is added
     * @param module Address of the trusted contract added
     */
    event TrustedContractAdded(address indexed module);
    /**
     * @dev Emitted when a trusted contract (module) is removed
     * @param module Address of the trusted contract removed
     */
    event TrustedContractRemoved(address indexed module);
    /**
     * @notice Checks if the specified address is a trusted contract
     * @param addr Address to check
     * @return Returns true if the address is a trusted contract, false otherwise
     */

    function isTrustedContract(address addr) external view returns (bool);
}

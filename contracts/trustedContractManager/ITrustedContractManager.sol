// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface ITrustedContractManager {
    event TrustedContractAdded(address indexed module);
    event TrustedContractRemoved(address indexed module);
    function isTrustedContract(address addr) external view returns (bool);
}

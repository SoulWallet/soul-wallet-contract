// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./ITrustedModuleManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TrustedModuleManager is ITrustedModuleManager, Ownable {

    mapping(address => bool) public trustedModules;

    constructor(address _owner) {
        // optimization for multiple chains
        _transferOwnership(_owner);
    }

    function isTrustedModule(address module) external view returns (bool){
        return trustedModules[module];
    }
    
    function addTrustedModule(address[] memory modules) external onlyOwner {
        for(uint i = 0; i < modules.length; i++){
            trustedModules[modules[i]] = true;
        }
    }
    function removeTrustedModule(address[] memory modules) external onlyOwner {
        for(uint i = 0; i < modules.length; i++){
            trustedModules[modules[i]] = false;
        }
    }
}

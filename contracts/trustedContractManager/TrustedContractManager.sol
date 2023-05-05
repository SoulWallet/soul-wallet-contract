// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./ITrustedContractManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract TrustedContractManager is ITrustedContractManager, Ownable {

    mapping(address => bool) public trustedContract;

    constructor(address _owner) {
        // optimization for multiple chains
        _transferOwnership(_owner);
    }

    function isTrustedContract(address module) external view returns (bool){
        return trustedContract[module];
    }
    
    function addContract(address[] memory modules) external onlyOwner {
        for(uint i = 0; i < modules.length; i++){
            require(modules[i] != address(0), "TrustedContractManager: address is zero");
            require(!trustedContract[modules[i]], "TrustedContractManager: contract already trusted");
            trustedContract[modules[i]] = true;
            emit TrustedContractAdded(modules[i]);
        }
    }
    function removeTrustedModule(address[] memory modules) external onlyOwner {
        for(uint i = 0; i < modules.length; i++){
            require(trustedContract[modules[i]], "TrustedContractManager: contract not trusted");
            trustedContract[modules[i]] = false;
            emit TrustedContractRemoved(modules[i]);
        }
    }
}

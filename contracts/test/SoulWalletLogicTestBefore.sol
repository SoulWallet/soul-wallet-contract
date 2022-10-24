// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SoulWalletLogicTestBefore {
    bool initialized;
    address public owner;
    address allowedImplementation;

    
    uint256[50] __gap;

    constructor() {
        // disable constructor
    }

    function initialize(address owner_) external {
        require(!initialized, "already initialized");
        owner = owner_;
        initialized = true;
    }

    function setAllowedUpgrade(address implementation) external {
        require(msg.sender == owner, "only owner");
        require(implementation != address(0), "invalid implementation");
        allowedImplementation = implementation;
    }

    function upgradeVerifiy(address implementation) external {
        require(msg.sender == owner, "only owner can upgrade");
        require(
            implementation == allowedImplementation,
            "invalid implementation"
        );
        allowedImplementation = address(0);
    }

    function getLogicInfo() external pure returns (string memory) {
        return "SoulWalletLogicTestBefore";
    }
}

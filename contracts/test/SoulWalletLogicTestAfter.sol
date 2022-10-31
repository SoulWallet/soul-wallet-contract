// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../utils/Upgradeable.sol";

contract SoulWalletLogicTestAfter is Upgradeable {
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

    function upgradeVerifiy(address implementation) private {
        require(msg.sender == owner, "only owner can upgrade");
        require(
            implementation == allowedImplementation,
            "invalid implementation"
        );
        allowedImplementation = address(0);
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external payable {
        upgradeVerifiy(newImplementation);
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        external
        payable
    {
        upgradeVerifiy(newImplementation);
        _upgradeToAndCall(newImplementation, data);
    }

    function getLogicInfo() external pure returns (string memory) {
        return "SoulWalletLogicTestAfter";
    }
}

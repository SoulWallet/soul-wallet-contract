// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "../base/UpgradeManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NewImplementation is Initializable, UpgradeManager {
    address public immutable WALLETIMPL;
    bytes32 public constant CURRENT_UPGRADE_SLOT = keccak256("soul.wallet.upgradeTo_NewImplementation");

    constructor() {
        WALLETIMPL = address(this);
        _disableInitializers();
    }

    function initialize(
        address anOwner,
        address defalutCallbackHandler,
        bytes[] calldata modules,
        bytes[] calldata plugins
    ) external initializer {}

    function hello() external pure returns (string memory) {
        return "hello world";
    }

    function upgradeTo(address newImplementation) external override {
        UpgradeManager._upgradeTo(newImplementation);
    }

    function upgradeFrom(address oldImplementation) external override {
        (oldImplementation);
        require(oldImplementation != WALLETIMPL);
        bool hasUpgraded = false;

        bytes32 _CURRENT_UPGRADE_SLOT = CURRENT_UPGRADE_SLOT;
        assembly {
            hasUpgraded := sload(_CURRENT_UPGRADE_SLOT)
        }
        require(!hasUpgraded, "already upgraded");
        assembly {
            sstore(_CURRENT_UPGRADE_SLOT, 1)
        }

        // data migration during upgrade
    }
}

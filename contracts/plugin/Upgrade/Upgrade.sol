// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BaseDelegateCallPlugin.sol";
import "./IUpgrade.sol";

contract Upgrade is BaseDelegateCallPlugin, IUpgrade {
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor() BaseDelegateCallPlugin(keccak256("PLUGIN_UPGRADE_SLOT")) {}

    function readLogic() private view returns (address logic) {
        assembly {
            logic := sload(_IMPLEMENTATION_SLOT)
        }
    }

    function saveLogic(address logic) private {
        require(logic != address(0), "logic address is zero");
        assembly {
            sstore(_IMPLEMENTATION_SLOT, logic)
        }
    }

    function readNewLogic() private view returns (address logic) {
        bytes32 _PLUGIN_SLOT = PLUGIN_SLOT;
        assembly {
            logic := sload(_PLUGIN_SLOT)
        }
    }

    function saveNewLogic(address logic) private {
        bytes32 _PLUGIN_SLOT = PLUGIN_SLOT;
        require(logic != address(0), "logic address is zero");
        assembly {
            sstore(_PLUGIN_SLOT, logic)
        }
    }

    function inited() internal view virtual override returns (bool) {
        return readNewLogic() != address(0);
    }

    function _init(bytes calldata data) internal override onlyDelegateCall {
        address newLogic = abi.decode(data, (address));
        require(newLogic == address(0), "logic address is not zero");
        saveNewLogic(newLogic);
    }

    function _deInit() internal override onlyDelegateCall {
        bytes32 _PLUGIN_SLOT = PLUGIN_SLOT;
        address emptyAddress = address(0);
        assembly {
            sstore(_PLUGIN_SLOT, emptyAddress)
        }
    }

    function upgrade() external override onlyDelegateCall {
        address oldLogic = readLogic();
        address newLogic = readNewLogic();
        require(oldLogic != newLogic, "logic address is same");
        saveLogic(newLogic);
        emit Upgrade(newLogic, oldLogic);
    }

    function _supportsHook() internal pure override returns (uint8 hookType) {
        hookType = 0;
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) external pure override {
        (userOp, userOpHash);
        revert("not support");
    }

    function preHook(address target, uint256 value, bytes calldata data) external pure override {
        (target, value, data);
        revert("not support");
    }

    function postHook(address target, uint256 value, bytes calldata data) external pure override {
        (target, value, data);
        revert("not support");
    }
}

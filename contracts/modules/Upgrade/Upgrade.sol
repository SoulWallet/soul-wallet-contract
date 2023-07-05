// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BaseModule.sol";
import "./IUpgrade.sol";
import "../../interfaces/IUpgradable.sol";

contract Upgrade is BaseModule, IUpgrade {
    address public newImplementation;
    mapping(address => uint256) private _inited;

    constructor(address _newImplementation) {
        newImplementation = _newImplementation;
    }

    function inited(address _target) internal view override returns (bool) {
        return _inited[_target] != 0;
    }

    function _init(bytes calldata data) internal override {
        (data);
        _inited[sender()] = 1;
    }

    function _deInit() internal override {
        _inited[sender()] = 0;
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory _funcs = new bytes4[](1);
        _funcs[0] = IUpgradable.upgradeTo.selector;
        return _funcs;
    }

    function upgrade(address wallet) external override {
        require(_inited[wallet] != 0, "not inited");
        IUpgradable(wallet).upgradeTo(newImplementation);
    }
}

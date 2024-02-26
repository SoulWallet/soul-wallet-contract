// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../BaseModule.sol";
import "./IUpgrade.sol";
import "../../interfaces/IUpgradable.sol";

/*
The UpgradeModule is responsible for upgrading the logic contract of SoulWallet.
*/
contract UpgradeModule is BaseModule, IUpgrade {
    address public newImplementation;
    mapping(address => uint256) private _inited;
    mapping(address => bool) private _upgraded;

    constructor(address _newImplementation) {
        newImplementation = _newImplementation;
    }

    function inited(address wallet) internal view override returns (bool) {
        return _inited[wallet] != 0;
    }

    function _init(bytes calldata data) internal override {
        (data);
        _inited[sender()] = 1;
    }

    function _deInit() internal override {
        _inited[sender()] = 0;
    }

    function upgrade(address wallet) external override {
        require(_inited[wallet] != 0, "not inited");
        require(_upgraded[wallet] == false, "already upgraded");
        IUpgradable(wallet).upgradeTo(newImplementation);
        _upgraded[wallet] = true;
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory _funcs = new bytes4[](1);
        _funcs[0] = IUpgradable.upgradeTo.selector;
        return _funcs;
    }
}

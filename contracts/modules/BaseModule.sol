// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IModule.sol";
import "../interfaces/ISoulWallet.sol";

abstract contract BaseModule is IModule {
    function walletInited(address) internal virtual returns (bool);

    function _walletInit(bytes memory data) internal virtual;

    function _walletDeInit() internal virtual;

    modifier walletInitAllowed() {
        require(!walletInited(msg.sender));
        require(ISoulWallet(msg.sender).isAuthorizedModule(address(this)));

        _;

        require(walletInited(msg.sender));
    }

    modifier walletDeInitAllowed() {
        require(walletInited(msg.sender));
        require(!ISoulWallet(msg.sender).isAuthorizedModule(address(this)));

        _;

        require(!walletInited(msg.sender));
    }

    function walletInit(bytes memory data) external walletInitAllowed {
        _walletInit(data);
    }

    function walletDeInit() external walletDeInitAllowed {
        _walletDeInit();
    }
}

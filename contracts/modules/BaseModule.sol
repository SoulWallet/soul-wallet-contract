// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IModule.sol";
import "../interfaces/ISoulWallet.sol";

abstract contract BaseModule is IModule {
    
    function walletInited(address) internal virtual returns (bool);

    modifier walletInitAllowed(address wallet) {
        require(!walletInited(msg.sender));
        require(ISoulWallet(msg.sender).isAuthorizedModule(address(this)));

        _;

        require(walletInited(msg.sender));
    }

    modifier walletDeInitAllowed(address wallet) {
        require(walletInited(msg.sender));
        require(!ISoulWallet(msg.sender).isAuthorizedModule(address(this)));
        
        _;

        require(!walletInited(msg.sender));
    }


    function walletInit(bytes memory data) external {
    }

    function walletDeInit() external {
    }
}
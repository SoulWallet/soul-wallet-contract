

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@source/SoulWallet.sol";

contract SoulWalletLogicInstence {
    SoulWallet public soulWalletLogic;

    constructor(address _entryPoint,  address defaultValidator) {
        soulWalletLogic = new SoulWallet(_entryPoint, defaultValidator);
    }
    
}
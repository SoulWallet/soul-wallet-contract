// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../authority/GuardianManagerAuth.sol";

abstract contract GuardianManager is GuardianManagerAuth {
    address private immutable __guardianManager;

    constructor(address guardianManager) {
        __guardianManager = guardianManager;
    }

    function _guardianManager() internal view override returns (address) {
        return __guardianManager;
    }
}

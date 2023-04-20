// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../guardian/IGuardian.sol";

abstract contract ImmediateGuardian {
    
    IGuardian private immutable __guardianLogic;

    constructor(IGuardian guardianLogic) {
        __guardianLogic = guardianLogic;
    }

    function _getGuardianLogic() internal view returns (IGuardian) {
        return __guardianLogic;
    }
}

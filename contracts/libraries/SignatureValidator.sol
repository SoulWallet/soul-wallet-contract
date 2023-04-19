// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../account-abstraction/contracts/interfaces/UserOperation.sol";

library SignatureValidator {
    function isValid(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal returns (uint256 validationData) {
        (userOp);
        (userOpHash);
        return 0;
    }
}

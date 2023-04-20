// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;


interface IGuardian {
    function setAnonymousGuardian(address anonymousGuardian, bytes32 guardianHash) external;
    function setGuardian(address[] calldata guardians) external;
    function recovery(address target ,bytes calldata signature) external;
}

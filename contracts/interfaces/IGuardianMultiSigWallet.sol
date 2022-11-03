// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface IGuardianMultiSigWallet {

    function initialize(address[] calldata _guardians, uint256 _threshold) external;
}

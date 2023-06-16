// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface ISimple2FA {
    function signerAddress(address addr) external view returns (address);

    function reset2FA(address new2FA) external;

    function preReset2FA(address new2FA) external;

    function comfirmReset2FA(address new2FA) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;


interface IFallbackModule {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function supportsStaticCall(bytes4 methodId) external view returns (bool);
}

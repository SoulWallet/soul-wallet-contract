// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IFallbackManager {
    event FallbackChanged(address indexed fallbackContract);

    function setFallback(address fallbackContract) external;
}

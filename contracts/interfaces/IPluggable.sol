// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IPluggable is IERC165 {
    function walletInit(bytes calldata data) external;
    function walletDeInit() external;
}
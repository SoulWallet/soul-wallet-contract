// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

abstract contract ModuleAuth {
    function _moduleSelectorAuth(bytes4 selector) internal view virtual returns (bool);

}
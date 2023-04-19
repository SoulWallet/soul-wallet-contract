// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../account-abstraction/contracts/interfaces/IEntryPoint.sol";

abstract contract EntryPointBase {
    function entryPoint() public view virtual returns (IEntryPoint);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../account-abstraction/contracts/interfaces/IEntryPoint.sol";

abstract contract EntryPointAuth {
    function _entryPoint() internal view virtual returns (IEntryPoint);

    function _requireFromEntryPoint(address addr) internal view {
        require(addr == address(_entryPoint()), "require entrypoint");
    }

    modifier onlyEntryPoint() {
        _requireFromEntryPoint(msg.sender);
        _;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../interfaces/IModule.sol";
import "../../libraries/CallHelper.sol";

contract HelloWorldModule is IModule {

    bytes4 private constant _methodId = bytes4(keccak256("helloWorld()"));

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return interfaceId == type(IModule).interfaceId;
    }

    function supportsMethod(
        bytes4 methodId
    ) public view returns (CallHelper.CallType) {

        if( methodId == _methodId) {
            return CallHelper.CallType.STATICCALL;
        }
        return CallHelper.CallType.UNKNOWN;
    }

    function supportsHook(HookType hookType) external view returns (CallHelper.CallType) {
        return CallHelper.CallType.UNKNOWN;
    }

    function preHook(
        address target,
        uint256 value,
        bytes memory data
    ) external {
        revert("HelloWorldModule: preHook not supported");
    }

    function postHook(
        address target,
        uint256 value,
        bytes memory data
    ) external {
        revert("HelloWorldModule: postHook not supported");
    }

    function helloWorld() public pure returns (string memory) {
        return "Hello World";
    }
}

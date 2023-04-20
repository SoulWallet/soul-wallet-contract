// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../interfaces/IFallbackModule.sol";

contract HelloWorldModule is IFallbackModule {
    
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return interfaceId == type(IFallbackModule).interfaceId;
    }

    function supportsStaticCall(
        bytes4 methodId
    ) public view virtual override returns (bool) {
        bytes4 _methodId = bytes4(keccak256("helloWorld()"));
        return _methodId == methodId;
    }

    function helloWorld() public pure returns (string memory) {
        return "Hello World";
    }
}

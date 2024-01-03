// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModule} from "../../contracts/interface/IModule.sol";

contract DemoModule is IModule {
    event InitCalled(bytes data);
    event DeInitCalled();

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IModule).interfaceId;
    }

    function Init(bytes calldata data) external override {
        emit InitCalled(data);
    }

    function DeInit() external override {
        emit DeInitCalled();
    }
}

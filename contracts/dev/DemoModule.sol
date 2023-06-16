// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../modules/BaseModule.sol";

contract DemoModule is BaseModule {
    mapping(address => bool) public isInit;

    event initEvent(address wallet);
    event deInitEvent(address wallet);

    bytes4 constant _function = bytes4(keccak256("addOwner(address)"));

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        // addOwner(address owner)
        bytes4[] memory _requiredFunctions = new bytes4[](1);
        _requiredFunctions[0] = _function;
        return _requiredFunctions;
    }

    function inited(address wallet) internal view override returns (bool) {
        return isInit[wallet];
    }

    function _init(bytes calldata data) internal override {
        (data);
        isInit[sender()] = true;
        emit initEvent(sender());
    }

    function _deInit() internal override {
        isInit[sender()] = false;
        emit deInitEvent(sender());
    }

    function addOwner(address target, address newOwner) external {
        require(inited(target));
        (bool ok, bytes memory res) = target.call{value: 0}(abi.encodeWithSelector(_function, newOwner));
        require(ok, string(res));
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IPlugin.sol";
import "../interfaces/ISoulWallet.sol";

abstract contract BasePlugin is IPlugin {
    // GUARD_HOOK: 0b1
    uint8 internal constant GUARD_HOOK = 0x1;
    // PRE_HOOK: 0b10
    uint8 internal constant PRE_HOOK = 0x2;
    // POST_HOOK: 0b100
    uint8 internal constant POST_HOOK = 0x4;

    uint8 internal constant CALL = 0x0;
    uint8 internal constant DELEGATECALL = 0x1;

    // use immutable to avoid delegatecall to change the value
    address internal immutable DEPLOY_ADDRESS;

    constructor() {
        DEPLOY_ADDRESS = address(this);
    }

    function _sender() internal view returns (address) {
        return msg.sender;
    }

    modifier onlyCall() {
        require(address(this) == DEPLOY_ADDRESS, "only call");
        _;
    }

    modifier onlyDelegateCall() {
        require(address(this) != DEPLOY_ADDRESS, "only delegate call");
        _;
    }

    function _wallet() internal view virtual returns (address wallet);

    function _init(bytes calldata data) internal virtual;

    function _deInit() internal virtual;

    function _supportsHook() internal pure virtual returns (uint8 hookType);

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IPlugin).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CallHelperTarget {
    address private immutable DEPLOY_ADDRESS;
    bytes32 private constant VALUE_SLOT = keccak256("CallHelperTarget");

    constructor() {
        DEPLOY_ADDRESS = address(this);
    }

    function read() private view returns (uint256 v) {
        bytes32 slot = VALUE_SLOT;
        assembly {
            v := sload(slot)
        }
    }

    function save(uint256 v) private {
        bytes32 slot = VALUE_SLOT;
        assembly {
            sstore(slot, v)
        }
    }

    modifier onlyCall() {
        require(address(this) == DEPLOY_ADDRESS);
        _;
    }

    modifier onlyDelegateCall() {
        require(address(this) != DEPLOY_ADDRESS);
        _;
    }

    function _call1() external onlyCall {
        save(0);
        save(0x11111);
    }

    function _call2() external onlyCall returns (uint256) {
        save(0);
        save(0x11111);
        return read();
    }

    function _call3(uint256 i) external onlyCall returns (uint256) {
        save(i);
        uint256 _value = read();
        save(0x11111);
        return _value;
    }

    function _staticCall1() external view onlyCall {}

    function _staticCall2() external view onlyCall returns (uint256) {
        return read();
    }

    function _staticCall3(uint256 i) external view onlyCall returns (uint256) {
        return i;
    }

    function _delegateCall1() external onlyDelegateCall {
        save(0);
        save(0x11111);
    }

    function _delegateCall2() external onlyDelegateCall returns (uint256) {
        save(0);
        save(0x11111);
        return read();
    }

    function _delegateCall3(uint256 i) external onlyDelegateCall returns (uint256) {
        save(i);
        uint256 _value = read();
        save(0x11111);
        return _value;
    }
}

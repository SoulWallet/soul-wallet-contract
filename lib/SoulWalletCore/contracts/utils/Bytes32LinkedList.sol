// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Bytes32LinkedList {
    error INVALID_DATA();
    error DATA_ALREADY_EXISTS();
    error DATA_NOT_EXISTS();

    bytes32 internal constant SENTINEL_BYTES32 = 0x0000000000000000000000000000000000000000000000000000000000000001;

    modifier onlyBytes32(bytes32 data) {
        if (data <= SENTINEL_BYTES32) {
            revert INVALID_DATA();
        }
        _;
    }

    function add(mapping(bytes32 => bytes32) storage self, bytes32 data) internal onlyBytes32(data) {
        if (self[data] != bytes32(0)) {
            revert DATA_ALREADY_EXISTS();
        }
        bytes32 _prev = self[SENTINEL_BYTES32];
        if (_prev == bytes32(0)) {
            self[SENTINEL_BYTES32] = data;
            self[data] = SENTINEL_BYTES32;
        } else {
            self[SENTINEL_BYTES32] = data;
            self[data] = _prev;
        }
    }

    function remove(mapping(bytes32 => bytes32) storage self, bytes32 data) internal {
        if (!tryRemove(self, data)) {
            revert DATA_NOT_EXISTS();
        }
    }

    function tryRemove(mapping(bytes32 => bytes32) storage self, bytes32 data) internal returns (bool) {
        if (isExist(self, data)) {
            bytes32 cursor = SENTINEL_BYTES32;
            while (true) {
                bytes32 _data = self[cursor];
                if (_data == data) {
                    bytes32 next = self[_data];
                    self[cursor] = next;
                    self[_data] = bytes32(0);
                    return true;
                }
                cursor = _data;
            }
        }
        return false;
    }

    function clear(mapping(bytes32 => bytes32) storage self) internal {
        bytes32 data = self[SENTINEL_BYTES32];
        self[SENTINEL_BYTES32] = bytes32(0);
        while (data > SENTINEL_BYTES32) {
            bytes32 _data = self[data];
            self[data] = bytes32(0);
            data = _data;
        }
    }

    function isExist(mapping(bytes32 => bytes32) storage self, bytes32 data)
        internal
        view
        onlyBytes32(data)
        returns (bool)
    {
        return self[data] != bytes32(0);
    }

    function size(mapping(bytes32 => bytes32) storage self) internal view returns (uint256) {
        uint256 result = 0;
        bytes32 data = self[SENTINEL_BYTES32];
        while (data > SENTINEL_BYTES32) {
            data = self[data];
            unchecked {
                result++;
            }
        }
        return result;
    }

    function isEmpty(mapping(bytes32 => bytes32) storage self) internal view returns (bool) {
        return self[SENTINEL_BYTES32] == bytes32(0);
    }

    function list(mapping(bytes32 => bytes32) storage self, bytes32 from, uint256 limit)
        internal
        view
        returns (bytes32[] memory)
    {
        bytes32[] memory result = new bytes32[](limit);
        uint256 i = 0;
        bytes32 data = self[from];
        while (data > SENTINEL_BYTES32 && i < limit) {
            result[i] = data;
            data = self[data];
            unchecked {
                i++;
            }
        }

        return result;
    }
}

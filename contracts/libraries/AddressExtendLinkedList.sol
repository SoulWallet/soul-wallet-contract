// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library AddressExtendLinkedList {
    address internal constant SENTINEL_ADDRESS = address(1);
    uint160 internal constant SENTINEL_UINT = 1;
    //bytes32 internal constant SENTINEL_BYTES32 = 0x0000000000000000000000000000000000000001000000000000000000000000; // _pack(SENTINEL_ADDRESS, 0)

    struct AddressExtend {
        address addr;
        uint96 extend;
    }

    modifier onlyAddress(address addr) {
        require(uint160(addr) > SENTINEL_UINT, "invalid address");
        _;
    }

    function _pack(address addr, uint96 extend) internal pure returns (bytes32 result) {
        /*
            struct {
                address addr;
                uint96 extend;
            }
         */
        assembly {
            result := shl(96, addr)
            result := or(result, extend)
        }
    }

    function _unpack(bytes32 packed) internal pure returns (address addr, uint96 extend) {
        assembly {
            addr := shr(96, packed)
            extend := and(packed, 0xffffffffffffffffffffffff)
        }
    }

    function _unpackAddress(bytes32 packed) internal pure returns (address addr) {
        assembly {
            addr := shr(96, packed)
        }
    }

    function add(mapping(address => bytes32) storage self, address addr, uint96 extend) internal onlyAddress(addr) {
        require(self[addr] == 0, "address already exists");
        bytes32 prev = self[SENTINEL_ADDRESS];
        address _prev = _unpackAddress(prev);
        bytes32 _packed = _pack(addr, extend);
        if (_prev == address(0)) {
            self[SENTINEL_ADDRESS] = _packed;
            self[addr] = _pack(SENTINEL_ADDRESS, 0);
        } else {
            self[SENTINEL_ADDRESS] = _packed;
            self[addr] = prev;
        }
    }

    function remove(mapping(address => bytes32) storage self, address addr) internal {
        require(isExist(self, addr), "address not exists");
        address cursor = SENTINEL_ADDRESS;
        while (true) {
            bytes32 _packed = self[cursor];
            address _addr = _unpackAddress(_packed);
            if (_addr == addr) {
                bytes32 _packed_next = self[_addr];
                self[cursor] = _packed_next;
                self[_addr] = 0;
                return;
            }
            cursor = _addr;
        }
    }

    function clear(mapping(address => bytes32) storage self) internal {
        for (
            address addr = _unpackAddress(self[SENTINEL_ADDRESS]);
            uint160(addr) > SENTINEL_UINT;
            addr = _unpackAddress(self[addr])
        ) {
            self[addr] = 0;
        }
        self[SENTINEL_ADDRESS] = 0;
    }

    function isExist(mapping(address => bytes32) storage self, address addr)
        internal
        view
        onlyAddress(addr)
        returns (bool)
    {
        return self[addr] != 0;
    }

    function size(mapping(address => bytes32) storage self) internal view returns (uint256) {
        uint256 result = 0;
        address addr = _unpackAddress(self[SENTINEL_ADDRESS]);
        while (uint160(addr) > SENTINEL_UINT) {
            addr = _unpackAddress(self[addr]);
            unchecked {
                result++;
            }
        }
        return result;
    }

    function isEmpty(mapping(address => bytes32) storage self) internal view returns (bool) {
        return self[SENTINEL_ADDRESS] == 0;
    }

    /**
     * @dev This function is just an example, please copy this code directly when you need it, you should not call this function
     */
    function list(mapping(address => bytes32) storage self, address from, uint256 limit)
        internal
        view
        returns (AddressExtend[] memory)
    {
        AddressExtend[] memory result = new AddressExtend[](limit);
        uint256 i = 0;
        (address addr, uint96 ext) = _unpack(self[from]);
        while (uint160(addr) > SENTINEL_UINT && i < limit) {
            result[i] = AddressExtend(addr, ext);
            (addr, ext) = _unpack(self[addr]);
            unchecked {
                i++;
            }
        }

        return result;
    }
}

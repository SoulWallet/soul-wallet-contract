// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library AddressExtendLinkedList {
    address internal constant SENTINEL_ADDRESS = address(1);
    uint160 internal constant SENTINEL_UINT = 1;
    //bytes32 internal constant SENTINEL_BYTES32 = 0x0000000000000000000000000000000000000001000000000000000000000000; // encode(SENTINEL_ADDRESS, 0)

    struct AddressExtend {
        address addr;
        uint96 extData;
    }

    modifier onlyAddress(address addr) {
        require(uint160(addr) > SENTINEL_UINT, "invalid address");
        _;
    }

    function encode(address addr, uint96 extData) internal pure returns (bytes32 result) {
        /*
            struct {
                address addr;
                uint96 extData;
            }
         */
        assembly {
            result := shl(96, addr)
            result := or(result, extData)
        }
    }

    function decode(bytes32 packed) internal pure returns (address addr, uint96 extData) {
        assembly {
            addr := shr(96, packed)
            extData := and(packed, 0xffffffffffffffffffffffff)
        }
    }

    function decodeAddress(bytes32 packed) internal pure returns (address addr) {
        assembly {
            addr := shr(96, packed)
        }
    }

    function decodeExtendData(bytes32 packed) internal pure returns (uint96 extData) {
        assembly {
            extData := and(packed, 0xffffffffffffffffffffffff)
        }
    }

    function add(mapping(address => bytes32) storage self, address addr, uint96 extData) internal onlyAddress(addr) {
        require(self[addr] == 0, "address already exists");
        bytes32 prev = self[SENTINEL_ADDRESS];
        if (prev == 0) {
            self[SENTINEL_ADDRESS] = encode(addr, 0);
            self[addr] = encode(SENTINEL_ADDRESS, extData);
        } else {
            self[SENTINEL_ADDRESS] = encode(addr, 0);
            self[addr] = encode(decodeAddress(prev), extData);
        }
    }

    function isExist(mapping(address => bytes32) storage self, address addr)
        internal
        view
        onlyAddress(addr)
        returns (bool)
    {
        return self[addr] != 0;
    }

    function getExtData(mapping(address => bytes32) storage self, address addr)
        internal
        view
        onlyAddress(addr)
        returns (uint96 extData)
    {
        bytes32 packed = self[addr];
        require(packed != 0, "address not exists");
        extData = decodeExtendData(packed);
    }

    function remove(mapping(address => bytes32) storage self, address addr) internal {
        require(tryRemove(self, addr), "address not exists");
    }

    function tryRemove(mapping(address => bytes32) storage self, address addr) internal returns (bool) {
        if (isExist(self, addr)) {
            address cursor = SENTINEL_ADDRESS;
            while (true) {
                bytes32 _packed = self[cursor];
                address _addr = decodeAddress(_packed);
                if (_addr == addr) {
                    bytes32 _next = self[_addr];
                    address _nextaddr = decodeAddress(_next);
                    if (_nextaddr == SENTINEL_ADDRESS && cursor == SENTINEL_ADDRESS) {
                        self[SENTINEL_ADDRESS] = 0;
                    } else {
                        self[cursor] = encode(decodeAddress(_next), decodeExtendData(_packed));
                    }
                    self[_addr] = 0;
                    return true;
                }
                cursor = _addr;
            }
        }
        return false;
    }

    function clear(mapping(address => bytes32) storage self) internal {
        for (
            address addr = decodeAddress(self[SENTINEL_ADDRESS]);
            uint160(addr) > SENTINEL_UINT;
            addr = decodeAddress(self[addr])
        ) {
            self[addr] = 0;
        }
        self[SENTINEL_ADDRESS] = 0;
    }

    function size(mapping(address => bytes32) storage self) internal view returns (uint256) {
        uint256 result = 0;
        address addr = decodeAddress(self[SENTINEL_ADDRESS]);
        while (uint160(addr) > SENTINEL_UINT) {
            addr = decodeAddress(self[addr]);
            unchecked {
                result++;
            }
        }
        return result;
    }

    function isEmpty(mapping(address => bytes32) storage self) internal view returns (bool) {
        return self[SENTINEL_ADDRESS] == 0;
    }

    function list(mapping(address => bytes32) storage self, address from, uint256 limit)
        internal
        view
        returns (address[] memory)
    {
        address[] memory result = new address[](limit);
        uint256 i = 0;
        address addr = decodeAddress(self[from]);
        while (uint160(addr) > SENTINEL_UINT && i < limit) {
            result[i] = addr;
            addr = decodeAddress(self[addr]);
            unchecked {
                i++;
            }
        }

        return result;
    }
}

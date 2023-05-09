// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library AddressLinkedList {
    address internal constant SENTINEL_ADDRESS = address(1);

    modifier onlyAddress(address addr) {
        require(uint160(addr) > 1, "invalid address");
        _;
    }

    function add(
        mapping(address => address) storage self,
        address addr
    ) internal onlyAddress(addr) {
        require(self[addr] == address(0), "address already exists");
        address _prev = self[SENTINEL_ADDRESS];
        if (_prev == address(0)) {
            self[SENTINEL_ADDRESS] = addr;
            self[addr] = SENTINEL_ADDRESS;
        } else {
            self[SENTINEL_ADDRESS] = addr;
            self[addr] = _prev;
        }
    }

    function replace(
        mapping(address => address) storage self,
        address oldAddr,
        address newAddr
    ) internal onlyAddress(oldAddr) onlyAddress(newAddr) {
        require(self[oldAddr] != address(0), "old address not exists");
        require(self[newAddr] == address(0), "new address already exists");
        for (
            address addr = self[SENTINEL_ADDRESS];
            addr != SENTINEL_ADDRESS;
            addr = self[addr]
        ) {
            if (addr == oldAddr) {
                self[addr] = newAddr;
                self[newAddr] = self[oldAddr];
                self[oldAddr] = address(0);
                return;
            }
        }
    }

    function remove(
        mapping(address => address) storage self,
        address addr
    ) internal onlyAddress(addr) {
        require(self[addr] != address(0), "address not exists");
        for (
            address _addr = self[SENTINEL_ADDRESS];
            _addr != SENTINEL_ADDRESS;
            _addr = self[_addr]
        ) {
            if (_addr == addr) {
                self[_addr] = self[addr];
                self[addr] = address(0);
                return;
            }
        }
    }

    function clear(mapping(address => address) storage self) internal {
        for (
            address addr = self[SENTINEL_ADDRESS];
            addr != SENTINEL_ADDRESS;
            addr = self[addr]
        ) {
            self[addr] = address(0);
        }
        self[SENTINEL_ADDRESS] = address(0);
    }

    function isExist(
        mapping(address => address) storage self,
        address addr
    ) internal view onlyAddress(addr) returns (bool) {
        return self[addr] != address(0);
    }

    function list(
        mapping(address => address) storage self,
        address from,
        uint256 limit
    ) internal view returns (address[] memory) {
        address[] memory result = new address[](limit);
        uint256 i = 0;
        for (
            address addr = self[from];
            addr != SENTINEL_ADDRESS && i < limit;
            addr = self[addr]
        ) {
            result[i] = addr;
            i++;
        }
        return result;
    }
}

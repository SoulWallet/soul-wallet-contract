// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SelectorLinkedList {
    error INVALID_SELECTOR();
    error SELECTOR_ALREADY_EXISTS();
    error SELECTOR_NOT_EXISTS();

    bytes4 internal constant SENTINEL_SELECTOR = 0x00000001;
    uint32 internal constant SENTINEL_UINT = 1;

    modifier onlySelector(bytes4 selector) {
        if (uint32(selector) <= SENTINEL_UINT) {
            revert INVALID_SELECTOR();
        }
        _;
    }

    function add(mapping(bytes4 => bytes4) storage self, bytes4 selector) internal onlySelector(selector) {
        if (self[selector] != 0) {
            revert SELECTOR_ALREADY_EXISTS();
        }
        bytes4 _prev = self[SENTINEL_SELECTOR];
        if (_prev == 0) {
            self[SENTINEL_SELECTOR] = selector;
            self[selector] = SENTINEL_SELECTOR;
        } else {
            self[SENTINEL_SELECTOR] = selector;
            self[selector] = _prev;
        }
    }

    function add(mapping(bytes4 => bytes4) storage self, bytes4[] memory selectors) internal {
        for (uint256 i = 0; i < selectors.length;) {
            add(self, selectors[i]);
            unchecked {
                i++;
            }
        }
    }

    function remove(mapping(bytes4 => bytes4) storage self, bytes4 selector) internal {
        if (!isExist(self, selector)) {
            revert SELECTOR_NOT_EXISTS();
        }

        bytes4 cursor = SENTINEL_SELECTOR;
        while (true) {
            bytes4 _selector = self[cursor];
            if (_selector == selector) {
                bytes4 next = self[_selector];
                if (next == SENTINEL_SELECTOR && cursor == SENTINEL_SELECTOR) {
                    self[SENTINEL_SELECTOR] = 0;
                } else {
                    self[cursor] = next;
                }
                self[_selector] = 0;
                return;
            }
            cursor = _selector;
        }
    }

    function clear(mapping(bytes4 => bytes4) storage self) internal {
        bytes4 selector = self[SENTINEL_SELECTOR];
        self[SENTINEL_SELECTOR] = 0;
        while (uint32(selector) > SENTINEL_UINT) {
            bytes4 _selector = self[selector];
            self[selector] = 0;
            selector = _selector;
        }
    }

    function isExist(mapping(bytes4 => bytes4) storage self, bytes4 selector)
        internal
        view
        onlySelector(selector)
        returns (bool)
    {
        return self[selector] != 0;
    }

    function size(mapping(bytes4 => bytes4) storage self) internal view returns (uint256) {
        uint256 result = 0;
        bytes4 selector = self[SENTINEL_SELECTOR];
        while (uint32(selector) > SENTINEL_UINT) {
            selector = self[selector];
            unchecked {
                result++;
            }
        }
        return result;
    }

    function isEmpty(mapping(bytes4 => bytes4) storage self) internal view returns (bool) {
        return self[SENTINEL_SELECTOR] == 0;
    }

    function list(mapping(bytes4 => bytes4) storage self, bytes4 from, uint256 limit)
        internal
        view
        returns (bytes4[] memory)
    {
        bytes4[] memory result = new bytes4[](limit);
        uint256 i = 0;
        bytes4 selector = self[from];
        while (uint32(selector) > SENTINEL_UINT && i < limit) {
            result[i] = selector;
            selector = self[selector];
            unchecked {
                i++;
            }
        }

        return result;
    }
}

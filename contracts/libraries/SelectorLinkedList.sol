// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library SelectorLinkedList {
    bytes4 internal constant SENTINEL_SELECTOR = 0x00000001;

    function isSafeSelector(bytes4 selector) internal pure returns (bool) {
        return uint32(selector) > 1;
    }

    modifier onlySelector(bytes4 selector) {
        require(isSafeSelector(selector), "only safe bytes4");
        _;
    }

    function add(
        mapping(bytes4 => bytes4) storage self,
        bytes4 selector
    ) internal onlySelector(selector) {
        require(self[selector] == 0, "selector already exists");
        bytes4 _prev = self[SENTINEL_SELECTOR];
        if (_prev == 0) {
            self[SENTINEL_SELECTOR] = selector;
            self[selector] = SENTINEL_SELECTOR;
        } else {
            self[SENTINEL_SELECTOR] = selector;
            self[selector] = _prev;
        }
    }

    function add(
        mapping(bytes4 => bytes4) storage self,
        bytes4[] memory selectors
    ) internal {
        //#TODO: optimize
        require(selectors.length > 0, "selectors is empty");
        for (uint256 i = 0; i < selectors.length; i++) {
            add(self, selectors[i]);
        }
    }

    function remove(
        mapping(bytes4 => bytes4) storage self,
        bytes4 selector
    ) internal onlySelector(selector) {
        require(self[selector] != 0, "selector not exists");
        for (
            bytes4 _selector = self[SENTINEL_SELECTOR];
            _selector != SENTINEL_SELECTOR;
            _selector = self[_selector]
        ) {
            if (_selector == selector) {
                self[_selector] = self[selector];
                self[selector] = 0;
                return;
            }
        }
    }

    function remove(
        mapping(bytes4 => bytes4) storage self,
        bytes4[] memory selectors
    ) internal {
        require(selectors.length > 0, "selectors is empty");
        //#TODO: optimize
        for (uint256 i = 0; i < selectors.length; i++) {
            remove(self, selectors[i]);
        }
    }

    function clear(mapping(bytes4 => bytes4) storage self) internal {
        for (
            bytes4 _selector = self[SENTINEL_SELECTOR];
            _selector != SENTINEL_SELECTOR;
            _selector = self[_selector]
        ) {
            self[_selector] = 0;
        }
        self[SENTINEL_SELECTOR] = 0;
    }

    function isExist(
        mapping(bytes4 => bytes4) storage self,
        bytes4 selector
    ) internal view onlySelector(selector) returns (bool) {
        return self[selector] != 0;
    }

    function list(
        mapping(bytes4 => bytes4) storage self,
        bytes4 from,
        uint256 limit
    ) internal view returns (bytes4[] memory) {
        bytes4[] memory result = new bytes4[](limit);
        uint256 i = 0;
        for (
            bytes4 selector = self[from];
            selector != SENTINEL_SELECTOR && i < limit;
            selector = self[selector]
        ) {
            result[i] = selector;
            i++;
        }
        return result;
    }
}

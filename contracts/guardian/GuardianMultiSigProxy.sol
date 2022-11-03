// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.12;
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
/*
    using proxy to deploying contract to save gas
 */

contract GuardianMultiSigProxy is ERC1967Proxy {
    constructor(address logic, bytes memory data) ERC1967Proxy(logic, data) {
        // solhint-disable-previous-line no-empty-blocks
    }
}

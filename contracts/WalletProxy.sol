// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.12;
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WalletProxy is ERC1967Proxy {
    constructor(address logic, bytes memory data) ERC1967Proxy(logic, data) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external payable {
        super._upgradeTo(newImplementation);
    }

    // /**
    //  * @dev Perform implementation upgrade with additional setup call.
    //  *
    //  * Emits an {Upgraded} event.
    //  */
    // function upgradeToAndCall(address newImplementation, bytes memory data)
    //     external
    //     payable
    // {
    //     super._upgradeToAndCall(newImplementation, data, false);
    // }
}

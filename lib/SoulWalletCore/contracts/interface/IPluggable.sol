// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title Pluggable Interface
 * @dev This interface provides functionalities for initializing and deinitializing wallet-related plugins or modules
 */
interface IPluggable is IERC165 {
    /**
     * @notice Initializes a specific module or plugin for the wallet with the provided data
     * @param data Initialization data required for the module or plugin
     */
    function Init(bytes calldata data) external;

    /*
        NOTE: All implemention must ensure that the DeInit() function can be covered by 100,000 gas in all scenarios.
     */

    /**
     * @notice Deinitializes a specific module or plugin from the wallet
     */
    function DeInit() external;
}

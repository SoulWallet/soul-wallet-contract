// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "../interfaces/UserOperation.sol";

/**
 * @title EstimateGasHelper
 * @dev This contract is used to estimate gas cost of handleOps() function. It is noly used for ARBITRUM NETWORK.
 */
contract EstimateGasHelper {
    function userOpCalldataTest(UserOperation calldata op) external {}
}

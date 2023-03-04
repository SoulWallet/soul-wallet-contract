// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "../interfaces/IEntryPoint.sol";
import "../interfaces/UserOperation.sol";

/**
 * @title EstimateGasHelper
 * @dev This contract is used to estimate gas cost of handleOps() function. It is noly used for ARBITRUM NETWORK.
 */
contract EstimateGasHelper {
    function handleOps(
        IEntryPoint entryPoint,
        UserOperation[] calldata ops,
        address payable beneficiary
    ) external {
        try entryPoint.handleOps(ops, beneficiary) {} catch {}
    }

    function simulateValidation(
        IEntryPoint entryPoint,
        UserOperation calldata ops
    ) external {
        try entryPoint.simulateValidation(ops) {} catch {}
    }
}

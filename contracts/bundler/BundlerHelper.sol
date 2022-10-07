// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/*
    source from:https://github.com/eth-infinitism/
*/

import "../EntryPoint.sol";
import "solidity-string-utils/StringUtils.sol";

contract BundlerHelper {
    using StringUtils for *;

    /**
     * run handleop. require to get refund for the used gas.
     */
    function handleOps(
        uint256 expectedPaymentGas,
        EntryPoint ep,
        UserOperation[] calldata ops,
        address payable beneficiary
    ) public returns (uint256 paid, uint256 gasPrice) {
        gasPrice = tx.gasprice;
        uint256 expectedPayment = expectedPaymentGas * gasPrice;
        uint256 preBalance = beneficiary.balance;
        ep.handleOps(ops, beneficiary);
        paid = beneficiary.balance - preBalance;
        if (paid < expectedPayment) {
            revert(
                string.concat(
                    "didn't pay enough: paid ",
                    paid.toString(),
                    " expected ",
                    expectedPayment.toString(),
                    " gasPrice ",
                    gasPrice.toString()
                )
            );
        }
    }
}

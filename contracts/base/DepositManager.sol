// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../interfaces/IDepositManager.sol";
import "../authority/Authority.sol";

abstract contract DepositManager is IDepositManager, Authority {
    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() external view returns (uint256) {
        return _entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() external payable {
        _entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external {
        _requireFromEntryPointOrOwner();

        _entryPoint().withdrawTo(withdrawAddress, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../interfaces/ILogicUpgradeControl.sol";
import "../../AccountStorage.sol";
import "./implementationSlot.sol";


contract LogicUpgradeControl is ILogicUpgradeControl,ImplementationSlot {
    using AccountStorage for AccountStorage.Layout;

    function logicUpgradeInfo()
        public
        view
        returns (ILogicUpgradeControl.UpgradeLayout memory)
    {
        UpgradeLayout memory l = AccountStorage.layout().logicUpgrade;
        return l;
    }

    function _preUpgradeTo(address newImplementation) internal {
        ILogicUpgradeControl.UpgradeLayout storage layout = AccountStorage
            .layout()
            .logicUpgrade;

        layout.pendingImplementation = newImplementation;

        if (newImplementation != address(0)) {
            require(
                Address.isContract(newImplementation),
                "LogicUpgradeControl: new implementation is not a contract"
            );
            layout.activateTime = uint64(block.timestamp + layout.upgradeDelay);
        } else {
            layout.activateTime = 0;
        }
        emit PreUpgrade(newImplementation, layout.activateTime);
    }

    function upgrade() public {
        ILogicUpgradeControl.UpgradeLayout storage layout = AccountStorage
            .layout()
            .logicUpgrade;
        require(
            layout.activateTime != 0 && layout.activateTime >= block.timestamp,
            "LogicUpgradeControl: upgrade delay has not elapsed"
        );
        address newImplementation = layout.pendingImplementation;
        require(
            Address.isContract(newImplementation),
            "LogicUpgradeControl: new implementation is not a contract"
        );

        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }

        emit Upgraded(newImplementation);

        layout.activateTime = 0;
        layout.pendingImplementation = address(0);
    }
}

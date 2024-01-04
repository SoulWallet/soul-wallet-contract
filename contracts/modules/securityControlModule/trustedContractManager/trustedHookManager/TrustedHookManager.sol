// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../TrustedContractManager.sol";

contract TrustedHookManager is TrustedContractManager {
    constructor(address _owner) TrustedContractManager(_owner) {}
}

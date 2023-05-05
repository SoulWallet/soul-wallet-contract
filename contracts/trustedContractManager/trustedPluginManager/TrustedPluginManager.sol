// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../TrustedContractManager.sol";

contract TrustedPluginManager is TrustedContractManager {
    constructor(address _owner) TrustedContractManager(_owner) {}   
}

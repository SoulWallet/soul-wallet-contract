// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPluggable} from "./IPluggable.sol";

interface IModule is IPluggable {
/*
        NOTE: All implemention must ensure that the DeInit() function can be covered by 100,000 gas in all scenarios.
     */
}

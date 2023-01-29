// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "./BaseTokenPaymaster.sol";
import "../interfaces/UserOperation.sol";

contract WETHPaymaster is BaseTokenPaymaster {
    using UserOperationLib for UserOperation;

    //calculated cost of the postOp
    uint256 constant COST_OF_POST = 20000;

    constructor(
        EntryPoint _entryPoint,
        IERC20 _ERC20Token,
        address _owner
    ) BaseTokenPaymaster(_entryPoint, _ERC20Token, COST_OF_POST, _owner) {}

    function _calculateTokenGasfee(
        uint256 etherGasfee
    ) internal view override returns (uint256) {
        return etherGasfee;
    }
}

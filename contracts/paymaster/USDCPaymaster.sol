// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../EntryPoint.sol";
import "../BasePaymaster.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./BaseTokenPaymaster.sol";
import "../interfaces/UserOperation.sol";

contract USDCPaymaster is BaseTokenPaymaster {
    using UserOperationLib for UserOperation;

    //calculated cost of the postOp
    uint256 constant COST_OF_POST = 20000;

    /**
     * @notice for security reason, the price feed is immutable
     */
    AggregatorV3Interface public immutable priceFeed;

    constructor(
        EntryPoint _entryPoint,
        IERC20 _ERC20Token,
        AggregatorV3Interface _priceFeed,
        address _owner
    ) BaseTokenPaymaster(_entryPoint, _ERC20Token, COST_OF_POST, _owner) {
        priceFeed = _priceFeed;
    }

    function tokenPrice(
        uint256 ethers
    ) public view override returns (uint256) {
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        (price);
        // TODO

        return ethers;
    }
}

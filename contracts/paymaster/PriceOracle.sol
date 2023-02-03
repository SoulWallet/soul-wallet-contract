// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/IPriceOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceOracle is IPriceOracle {
    /**
     * @notice for security reason, the price feed is immutable
     */
    AggregatorV3Interface public immutable priceFeed;

    mapping (address => bool) private supportedToken;

    constructor(AggregatorV3Interface _priceFeed) {
        priceFeed = _priceFeed;
        supportedToken[address(0)] = true;
    }

    function exchangePrice(
        address token
    ) external view override returns (uint256) {
        
        // TODO
        //require(supportedToken[token], "unsupported token");

        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        (price, token);
        // TODO


        return 1e18;
    }
}

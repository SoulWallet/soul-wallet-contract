// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPriceOracle {

    function exchangePrice(address _token) external view returns (uint256 price, uint8 decimals);

}

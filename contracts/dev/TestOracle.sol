
pragma solidity ^0.8.17;

contract TestOracle {
    int256 public price;

    constructor(int256 _price) {
        price = _price;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (110680464442257311610, 190355094900, 1685339747, block.timestamp, 110680464442257311610);
    }
}

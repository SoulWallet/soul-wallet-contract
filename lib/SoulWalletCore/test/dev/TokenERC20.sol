// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenERC20 is ERC20 {
    constructor() ERC20("ERC20", "ERC20") {
        _mint(msg.sender, 1000 ether);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

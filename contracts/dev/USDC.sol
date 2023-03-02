// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "hardhat/console.sol";

contract USDCoin is ERC20, Ownable, ERC20Permit {
    constructor() ERC20("USD Mock Coin", "USDMC") ERC20Permit("USD Coin") {
       _mint(owner(), type(uint64).max);
    }

    function decimals() public view override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        address owner = _msgSender();
        //console.log("USDC:approve(owner, spender, amount):", owner, spender, amount);
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        //console.log("USDC:transferFrom (spender,from,to,amount)):");
        //console.log(spender,from,to, amount);
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
}

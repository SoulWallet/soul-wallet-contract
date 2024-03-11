pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAaveV3 {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}

contract AaveUsdcSaveAutomation is Ownable {
    using SafeERC20 for IERC20;

    IERC20 immutable usdcToken;
    IERC20 immutable aUsdcToken;
    IAaveV3 immutable aave;
    mapping(address => bool) public bots;

    modifier onlyBot() {
        require(bots[msg.sender], "no permission");
        _;
    }

    constructor(address _owner, address _usdcAddr, address _aaveUsdcPoolAddr, address _aUsdcTokenAddr)
        Ownable(_owner)
    {
        usdcToken = IERC20(_usdcAddr);
        aUsdcToken = IERC20(_aUsdcTokenAddr);
        aave = IAaveV3(_aaveUsdcPoolAddr);
        usdcToken.approve(address(aave), 2 ** 256 - 1);
    }

    function depositUsdcToAave(address _user, uint256 amount) public onlyBot {
        usdcToken.safeTransferFrom(_user, address(this), amount);
        uint256 aTokenBeforeSupply = aUsdcToken.balanceOf(_user);
        aave.supply(address(usdcToken), amount, _user, 0);
        uint256 aTokenAfterSupply = aUsdcToken.balanceOf(_user);
        require(aTokenAfterSupply - aTokenBeforeSupply == amount, "AaveSaveAutomation: deposit failed");
    }

    function addBot(address bot) public onlyOwner {
        bots[bot] = true;
    }

    function removeBot(address bot) public onlyOwner {
        bots[bot] = false;
    }
}

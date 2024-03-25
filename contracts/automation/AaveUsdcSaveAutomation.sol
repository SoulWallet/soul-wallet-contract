pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAaveV3 {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}

contract AaveUsdcSaveAutomation is Ownable {
    using SafeERC20 for IERC20;

    event BotAdded(address bot);
    event BotRemoved(address bot);
    event UsdcDepositedToAave(address user, uint256 amount);

    IERC20 immutable usdcToken;
    IAaveV3 immutable aave;
    mapping(address => bool) public bots;

    modifier onlyBot() {
        require(bots[msg.sender], "no permission");
        _;
    }

    constructor(address _owner, address _usdcAddr, address _aaveUsdcPoolAddr) Ownable(_owner) {
        usdcToken = IERC20(_usdcAddr);
        aave = IAaveV3(_aaveUsdcPoolAddr);
        usdcToken.approve(address(aave), 2 ** 256 - 1);
    }

    function depositUsdcToAave(address _user, uint256 amount) public onlyBot {
        usdcToken.safeTransferFrom(_user, address(this), amount);
        aave.supply(address(usdcToken), amount, _user, 0);
        emit UsdcDepositedToAave(_user, amount);
    }

    function addBot(address bot) public onlyOwner {
        bots[bot] = true;
        emit BotAdded(bot);
    }

    function removeBot(address bot) public onlyOwner {
        bots[bot] = false;
        emit BotRemoved(bot);
    }
}

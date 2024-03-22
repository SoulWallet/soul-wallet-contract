pragma solidity ^0.8.17;

import "../BaseModule.sol";
import "./base/BaseSocialRecovery.sol";

contract SocialRecoveryModule is BaseModule, BaseSocialRecovery {
    bytes4 private constant _FUNC_RESET_OWNER = bytes4(keccak256("resetOwner(bytes32)"));
    bytes4 private constant _FUNC_RESET_OWNERS = bytes4(keccak256("resetOwners(bytes32[])"));
    mapping(address => bool) walletInited;

    constructor() EIP712("SocialRecovery", "1") {}

    function _deInit() internal override {
        address _sender = sender();
        _clearWalletSocialRecoveryInfo(_sender);
        walletInited[_sender] = false;
    }

    function _init(bytes calldata _data) internal override {
        address _sender = sender();
        (bytes32 guardianHash, uint256 delayPeroid) = abi.decode(_data, (bytes32, uint256));
        _setGuardianHash(_sender, guardianHash);
        _setDelayPeriod(_sender, delayPeroid);
        walletInited[_sender] = true;
    }

    function inited(address wallet) internal view override returns (bool) {
        return walletInited[wallet];
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory functions = new bytes4[](2);
        functions[0] = _FUNC_RESET_OWNER;
        functions[1] = _FUNC_RESET_OWNERS;
        return functions;
    }
}

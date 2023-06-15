// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IModule.sol";
import "../interfaces/ISoulWallet.sol";
import "../interfaces/IModuleManager.sol";

abstract contract BaseModule is IModule {
    event ModuleInit(address indexed wallet);
    event ModuleDeInit(address indexed wallet);

    function inited(address wallet) internal view virtual returns (bool);

    function _init(bytes calldata data) internal virtual;

    function _deInit() internal virtual;

    function sender() internal view returns (address) {
        return msg.sender;
    }

    function walletInit(bytes calldata data) external {
        address _sender = sender();
        if (!inited(_sender)) {
            if (!ISoulWallet(_sender).isAuthorizedModule(address(this))) {
                revert("not authorized module");
            }
            _init(data);
            emit ModuleInit(_sender);
        }
    }

    function walletDeInit() external {
        address _sender = sender();
        if (inited(_sender)) {
            if (ISoulWallet(_sender).isAuthorizedModule(address(this))) {
                revert("authorized module");
            }
            _deInit();
            emit ModuleDeInit(_sender);
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IModule).interfaceId;
    }
}

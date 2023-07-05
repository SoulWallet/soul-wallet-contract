// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BasePlugin.sol";
import "./IDailylimit.sol";
import "../../safeLock/SafeLock.sol";
import "../../libraries/AddressLinkedList.sol";
import "../../libraries/SignatureDecoder.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "../../interfaces/IExecutionManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IPluginStorage.sol";

contract Dailylimit is BasePlugin, IDailylimit, SafeLock {
    //using AddressLinkedList for mapping(address => address);

    address private constant _ETH_TOKEN_ADDRESS = address(2);
    uint256 private constant _MAX_TIMERANGE = 1 hours;

    uint256 private __seed;

    function _newSeed() private returns (uint256) {
        return ++__seed;
    }

    struct initSeed {
        uint256 currentDay;
        uint256 seed;
    }

    mapping(address => initSeed) private _currentDay;

    constructor() SafeLock("PLUGIN_DAILYLIMIT_SAFELOCK_SLOT", 2 days) {}

    struct DaySpent {
        uint256 dailyLimit;
        uint256 day;
        uint256 spent;
    }

    struct Layout {
        uint256 currentDay;
        mapping(address => address) tokens;
        mapping(address => DaySpent) daySpent;
    }

    function _packedToken(address token) private view returns (bytes32 packedToken) {
        packedToken = _packedToken(_wallet(), token);
    }

    function _packedToken(address wallet, address token) private view returns (bytes32 packedToken) {
        address _token = _getTokenAddress(token);
        uint256 seed = _currentDay[wallet].seed;
        packedToken = keccak256(abi.encodePacked(_token, seed));
    }

    function _packDaySpent(uint256 dailyLimit, uint256 day, uint256 spent) private pure returns (bytes memory) {
        return abi.encodePacked(dailyLimit, day, spent);
    }

    function _unpackDaySpent(bytes memory data) private pure returns (uint256 dailyLimit, uint256 day, uint256 spent) {
        require(data.length == 96, "Dailylimit: invalid data");
        (dailyLimit, day, spent) = abi.decode(data, (uint256, uint256, uint256));
    }

    function _saveTokenDaySpent(address token, uint256 dailyLimit, uint256 day, uint256 spent) private {
        bytes32 _token = _packedToken(token);
        bytes memory data = _packDaySpent(dailyLimit, day, spent);
        IPluginStorage pluginStorage = IPluginStorage(_wallet());
        pluginStorage.pluginDataStore(_token, data);
    }

    function _initTokenDaySpent(address token, uint256 dailyLimit) private {
        bytes32 _token = _packedToken(token);
        IPluginStorage pluginStorage = IPluginStorage(_wallet());
        require(pluginStorage.pluginDataLoad(address(this), _token).length == 0, "Dailylimit: token already added");
        bytes memory data = _packDaySpent(dailyLimit, 0, 0);
        pluginStorage.pluginDataStore(_token, data);
    }

    function _loadTokenDaySpent(address token)
        private
        view
        returns (bool isExist, uint256 dailyLimit, uint256 day, uint256 spent)
    {
        bytes32 _token = _packedToken(token);
        IPluginStorage pluginStorage = IPluginStorage(_wallet());
        bytes memory data = pluginStorage.pluginDataLoad(address(this), _token);
        if (data.length == 0) {
            return (false, 0, 0, 0);
        }
        isExist = true;
        (dailyLimit, day, spent) = _unpackDaySpent(data);
    }

    function _removeTokenDaySpent(address token) private {
        bytes32 _token = _packedToken(token);
        IPluginStorage pluginStorage = IPluginStorage(_wallet());
        pluginStorage.pluginDataStore(_token, "");
    }

    function _supportsHook() internal pure override returns (uint8 hookType) {
        hookType = GUARD_HOOK | POST_HOOK;
    }

    function inited(address wallet) internal view override returns (bool) {
        return _currentDay[wallet].currentDay != 0;
    }

    function _init(bytes calldata data) internal override {
        if (_currentDay[_wallet()].currentDay == 0) {
            _currentDay[_wallet()].seed = _newSeed();
            _currentDay[_wallet()].currentDay = _getDay(block.timestamp);
            // decode data
            (address[] memory tokens, uint256[] memory limits) = abi.decode(data, (address[], uint256[]));
            require(tokens.length == limits.length, "Dailylimit: invalid data");
            for (uint256 i = 0; i < tokens.length; i++) {
                address _token = tokens[i];
                uint256 limit = limits[i];
                require(limit > 0, "Dailylimit: invalid limit");
                _initTokenDaySpent(_token, limit);
            }
            emit DailyLimitChanged(tokens, limits);
        }
    }

    function _deInit() internal override {
        if (_currentDay[_wallet()].currentDay != 0) {
            _currentDay[_wallet()].currentDay = 0;
        }
    }

    function _getTokenAddress(address token) private pure returns (address) {
        return token == address(0) ? _ETH_TOKEN_ADDRESS : token;
    }

    function _getDay(uint256 timeNow) private pure returns (uint256) {
        return timeNow / 1 days;
    }

    function _decodeERC20Spent(bytes4 selector, address to, bytes memory data)
        private
        view
        returns (address token, uint256 spent)
    {
        if (selector == IERC20.transfer.selector) {
            (, spent) = abi.decode(data, (address, uint256));
            token = to;
        } else if (selector == IERC20.approve.selector) {
            (, spent) = abi.decode(data, (address, uint256));
            token = to;
        } else if (selector == IERC20.transferFrom.selector) {
            (address sender,, uint256 amount) = abi.decode(data, (address, address, uint256));
            if (sender == _wallet()) {
                token = to;
                spent = amount;
            }
        }
    }

    function _calcRequiredPrefund(UserOperation calldata userOp) private pure returns (uint256 requiredPrefund) {
        uint256 requiredGas = userOp.callGasLimit + userOp.verificationGasLimit + userOp.preVerificationGas;
        requiredPrefund = requiredGas * userOp.maxFeePerGas;
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata guardData) external override {
        (userOpHash);
        require(guardData.length == 0, "Dailylimit: guard signature not allowed");
        uint256 _validationData;
        (,, _validationData,) = SignatureDecoder.decodeSignature(userOp.signature);

        if (_validationData == 0) revert("Dailylimit: signature timerange invalid");

        ValidationData memory validationData = _parseValidationData(_validationData);
        require(
            validationData.validUntil - validationData.validAfter < _MAX_TIMERANGE, "Dailylimit: exceed max timerange"
        );
        uint256 currentDay = _getDay(validationData.validAfter);

        _currentDay[_wallet()].currentDay = currentDay;
        (bool isExist, uint256 dailyLimit, uint256 day, uint256 spent) = _loadTokenDaySpent(_ETH_TOKEN_ADDRESS);
        if (isExist) {
            if (userOp.paymasterAndData.length == 0) {
                uint256 ethGasFee = _calcRequiredPrefund(userOp);
                uint256 _newSpent = (day == currentDay ? spent : 0) + ethGasFee;
                require(_newSpent <= dailyLimit, "Dailylimit: ETH daily limit reached");
                _saveTokenDaySpent(_ETH_TOKEN_ADDRESS, dailyLimit, day == currentDay ? day : currentDay, _newSpent);
            }
        }
    }

    function preHook(address target, uint256 value, bytes calldata data) external pure override {
        (target, value, data);
        revert("Dailylimit: preHook not support");
    }

    function postHook(address target, uint256 value, bytes calldata data) external override {
        uint256 _day = _getDay(block.timestamp);

        if (value > 0) {
            (bool isExist, uint256 dailyLimit, uint256 day, uint256 spent) = _loadTokenDaySpent(_ETH_TOKEN_ADDRESS);
            if (isExist) {
                uint256 _newSpent = (day == _day ? spent : 0) + value;
                require(_newSpent <= dailyLimit, "Dailylimit: ETH daily limit reached");
                _saveTokenDaySpent(_ETH_TOKEN_ADDRESS, dailyLimit, day == _day ? day : _day, _newSpent);
            }
        }

        if (uint160(target) > 1) {
            (bool isExist, uint256 dailyLimit, uint256 day, uint256 spent) = _loadTokenDaySpent(target);
            if (isExist) {
                (, uint256 _spent) = _decodeERC20Spent(bytes4(data[0:4]), target, data[4:]);
                if (_spent > 0) {
                    uint256 spentNow;
                    if (day == _day) {
                        spentNow = spent;
                    } else {
                        day = _day;
                        spent = 0;
                    }
                    uint256 _newSpent = spentNow + _spent;
                    require(_newSpent <= dailyLimit, "Dailylimit: token daily limit reached");
                    _saveTokenDaySpent(target, dailyLimit, day, _newSpent);
                }
            }
        }
    }

    function reduceDailyLimits(address[] calldata token, uint256[] calldata limit) external override {
        require(token.length == limit.length, "Dailylimit: invalid data");
        for (uint256 i = 0; i < token.length; i++) {
            uint256 _amount = limit[i];
            require(_amount > 0, "Dailylimit: invalid amount");
            address _token = token[i];
            (bool isExist, uint256 dailyLimit, uint256 day, uint256 spent) = _loadTokenDaySpent(_token);
            if (isExist) {
                require(dailyLimit > _amount, "Dailylimit: exceed daily limit");
                _saveTokenDaySpent(_token, _amount, day, spent);
            } else {
                revert("Dailylimit: token not exist");
            }
        }

        emit DailyLimitChanged(token, limit);
    }

    function preSetDailyLimit(address[] calldata token, uint256[] calldata limit) external override {
        bytes32 hash = keccak256(abi.encode(token, limit));
        _lock(hash);

        emit PreSetDailyLimit(token, limit);
    }

    function cancelSetDailyLimit(address[] calldata token, uint256[] calldata limit) external override {
        bytes32 hash = keccak256(abi.encode(token, limit));
        _cancelLock(hash);

        emit CancelSetDailyLimit(token, limit);
    }

    function comfirmSetDailyLimit(address[] calldata token, uint256[] calldata limit) external override {
        bytes32 hash = keccak256(abi.encode(token, limit));
        _unlock(hash);
        require(token.length == limit.length, "Dailylimit: invalid data");
        for (uint256 i = 0; i < token.length; i++) {
            uint256 _amount = limit[i];
            address _token = token[i];
            (bool isExist,, uint256 day, uint256 spent) = _loadTokenDaySpent(_token);
            if (isExist) {
                if (_amount == 0) {
                    _removeTokenDaySpent(_token);
                } else {
                    _saveTokenDaySpent(_token, _amount, day, spent);
                }
            } else {
                if (_amount > 0) {
                    _initTokenDaySpent(_token, _amount);
                }
            }
        }

        emit DailyLimitChanged(token, limit);
    }

    function getDailyLimit(address wallet, address token) external view override returns (uint256 dailyLimit) {
        bytes32 _token = _packedToken(wallet, token);
        IPluginStorage pluginStorage = IPluginStorage(wallet);
        bytes memory data = pluginStorage.pluginDataLoad(address(this), _token);
        if (data.length == 0) {
            return 0;
        }
        (dailyLimit,,) = _unpackDaySpent(data);
    }

    function getSpentToday(address wallet, address token) external view override returns (uint256 spent) {
        bytes32 _token = _packedToken(wallet, token);
        IPluginStorage pluginStorage = IPluginStorage(wallet);
        bytes memory data = pluginStorage.pluginDataLoad(address(this), _token);
        if (data.length == 0) {
            return 0;
        }
        (,, spent) = _unpackDaySpent(data);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BaseDelegateCallPlugin.sol";
import "./IDailylimit.sol";
import "../../safeLock/SafeLock.sol";
import "../../libraries/AddressLinkedList.sol";
import "../../libraries/SignatureDecoder.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "../../libraries/DecodeCalldata.sol";
import "../../interfaces/IExecutionManager.sol";

contract Dailylimit is BaseDelegateCallPlugin, IDailylimit, SafeLock {
    using AddressLinkedList for mapping(address => address);

    address private constant _ETH_TOKEN_ADDRESS = address(2);
    uint256 private constant _MAX_TIMERANGE = 1 hours;

    bytes4 private constant _FUNC_EXECUTE = bytes4(keccak256("execute(address,uint256,bytes)"));
    bytes4 private constant _FUNC_EXECUTE_BATCH = bytes4(keccak256("executeBatch(address[],bytes[])"));
    bytes4 private constant _FUNC_EXECUTE_BATCH_VALUE = bytes4(keccak256("executeBatch(address[],uint256[],bytes[])"));
    bytes4 private constant _FUNC_EXEC_FROM_MODULE = bytes4(keccak256("moduleEntryPoint(bytes)"));

    bytes4 private constant _ERC20_TRANSFER = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private constant _ERC20_APPROVE = bytes4(keccak256("approve(address,uint256)"));
    bytes4 private constant _ERC20_TRANSFER_FROM = bytes4(keccak256("transferFrom(address,address,uint256)"));

    /**
     * @dev all constructor parameters must be `immutable` type (Dailylimit plugin is a `delegatecall` plugin)
     */
    constructor()
        BaseDelegateCallPlugin(keccak256("PLUGIN_DAILYLIMIT_SLOT"))
        SafeLock("PLUGIN_DAILYLIMIT_SAFELOCK_SLOT", 2 days)
    {}

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

    function _layout() internal view returns (Layout storage l) {
        bytes32 slot = PLUGIN_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _supportsHook() internal pure override returns (uint8 hookType) {
        hookType = GUARD_HOOK | POST_HOOK;
    }

    function inited() internal view override returns (bool) {
        return _layout().currentDay != 0;
    }

    function _init(bytes calldata data) internal override onlyDelegateCall {
        Layout storage l = _layout();
        if (l.currentDay == 0) {
            l.currentDay = _getDay(block.timestamp);
            // decode data
            (address[] memory tokens, uint256[] memory limits) = abi.decode(data, (address[], uint256[]));
            require(tokens.length == limits.length, "Dailylimit: invalid data");
            for (uint256 i = 0; i < tokens.length; i++) {
                address _token = _getTokenAddress(tokens[i]);
                uint256 limit = limits[i];
                require(limit > 0, "Dailylimit: invalid limit");
                l.tokens.add(_token);
                l.daySpent[_token] = DaySpent(limit, 0, 0);
            }
            emit DailyLimitChanged(tokens, limits);
        }
    }

    function _deInit() internal override onlyDelegateCall {
        Layout storage l = _layout();
        if (l.currentDay != 0) {
            l.currentDay = 0;
            l.tokens.clear();
        }
    }

    function _getTokenAddress(address token) private pure returns (address) {
        return token == address(0) ? _ETH_TOKEN_ADDRESS : token;
    }

    function _getTokenDailyLimit(address token) private view returns (uint256) {
        return _layout().daySpent[_getTokenAddress(token)].dailyLimit;
    }

    function _getDay(uint256 timeNow) private pure returns (uint256) {
        return timeNow / 1 days;
    }

    function _getDaySpent(address token, uint256 timeNow) private view returns (uint128) {
        uint256 day = _getDay(timeNow);
        Layout storage l = _layout();
        DaySpent storage daySpent = l.daySpent[_getTokenAddress(token)];
        if (daySpent.day != day) {
            return 0;
        }
        return uint128(daySpent.spent);
    }

    function _decodeERC20Spent(bytes4 selector, address to, bytes memory data)
        private
        view
        returns (address token, uint256 spent)
    {
        if (selector == _ERC20_TRANSFER) {
            (, spent) = abi.decode(data, (address, uint256));
            token = to;
        } else if (selector == _ERC20_APPROVE) {
            (, spent) = abi.decode(data, (address, uint256));
            token = to;
        } else if (selector == _ERC20_TRANSFER_FROM) {
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

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) external override {
        (userOpHash);
        uint256 _validationData = SignatureDecoder.decodeSignature(userOp.signature).validationData;
        if (_validationData == 0) revert("Dailylimit: signature timerange invalid");

        ValidationData memory validationData = _parseValidationData(_validationData);
        require(
            validationData.validUntil - validationData.validAfter < _MAX_TIMERANGE, "Dailylimit: exceed max timerange"
        );
        uint256 currentDay = _getDay(validationData.validAfter);
        Layout storage l = _layout();
        l.currentDay = currentDay;
        if (l.tokens.isExist(_ETH_TOKEN_ADDRESS)) {
            if (userOp.paymasterAndData.length == 0) {
                uint256 ethGasFee = _calcRequiredPrefund(userOp);
                DaySpent storage _DaySpent = l.daySpent[_ETH_TOKEN_ADDRESS];

                uint256 _ethSpent;
                if (_DaySpent.day == currentDay) {
                    _ethSpent = _DaySpent.spent;
                } else {
                    _DaySpent.day = currentDay;
                }
                uint256 _newSpent = _ethSpent + ethGasFee;
                require(_newSpent <= _DaySpent.dailyLimit, "Dailylimit: ETH daily limit reached");
                _DaySpent.spent = _newSpent;
            }
        }
    }

    function preHook(address target, uint256 value, bytes calldata data) external pure override {
        (target, value, data);
        revert("Dailylimit: preHook not support");
    }

    function postHook(address target, uint256 value, bytes calldata data) external override {
        uint256 day = _getDay(block.timestamp);
        Layout storage l = _layout();
        if (value > 0 && l.tokens.isExist(_ETH_TOKEN_ADDRESS)) {
            DaySpent storage _DaySpent = l.daySpent[_ETH_TOKEN_ADDRESS];
            uint256 spent;
            if (_DaySpent.day == day) {
                spent = _DaySpent.spent;
            } else {
                _DaySpent.day = day;
            }
            uint256 _newSpent = spent + value;
            require(_newSpent <= _DaySpent.dailyLimit, "Dailylimit: ETH daily limit reached");
            _DaySpent.spent = _newSpent;
        }
        if (uint160(target) > 1 && l.tokens.isExist(target)) {
            (, uint256 _spent) = _decodeERC20Spent(bytes4(data[0:4]), target, data[4:]);

            if (_spent > 0) {
                DaySpent storage _DaySpent = l.daySpent[target];
                uint256 spent;
                if (_DaySpent.day == day) {
                    spent = _DaySpent.spent;
                } else {
                    _DaySpent.day = day;
                    _DaySpent.spent = 0;
                }
                uint256 _newSpent = spent + _spent;
                require(_newSpent <= _DaySpent.dailyLimit, "Dailylimit: token daily limit reached");
                _DaySpent.spent = _newSpent;
            }
        }
    }

    function reduceDailyLimits(address[] calldata token, uint256[] calldata limit) external override {
        require(token.length == limit.length, "Dailylimit: invalid data");
        Layout storage l = _layout();
        for (uint256 i = 0; i < token.length; i++) {
            uint256 _amount = limit[i];
            require(_amount > 0, "Dailylimit: invalid amount");
            address _token = _getTokenAddress(token[i]);
            DaySpent storage daySpent = l.daySpent[_token];
            require(daySpent.dailyLimit > _amount, "Dailylimit: exceed daily limit");

            daySpent.dailyLimit = _amount;
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
        Layout storage l = _layout();
        for (uint256 i = 0; i < token.length; i++) {
            uint256 _amount = limit[i];
            address _token = _getTokenAddress(token[i]);
            if (l.tokens.isExist(_token)) {
                if (_amount == 0) {
                    l.tokens.remove(_token);
                } else {
                    l.daySpent[_token].dailyLimit = _amount;
                }
            } else {
                if (_amount > 0) {
                    l.tokens.add(_token);
                    l.daySpent[_token] = DaySpent(_amount, 0, 0);
                }
            }
        }

        emit DailyLimitChanged(token, limit);
    }

    function getDailyLimit(address token) external view override returns (uint256) {
        return _getTokenDailyLimit(token);
    }

    function getSpentToday(address token) external view override returns (uint256) {
        return _getDaySpent(token, block.timestamp);
    }
}

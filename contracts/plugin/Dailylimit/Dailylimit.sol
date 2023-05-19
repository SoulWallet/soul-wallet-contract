// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BasePlugin.sol";
import "./IDailylimit.sol";
import "../../safeLock/SafeLock.sol";
import "../../libraries/AddressLinkedList.sol";
import "../../libraries/SignatureDecoder.sol";
import "@account-abstraction/contracts/core/Helpers.sol";

contract Dailylimit is BasePlugin, IDailylimit, SafeLock {
    using AddressLinkedList for mapping(address => address);

    address private constant ETH_TOKEN_ADDRESS = address(2);
    uint256 private constant MAX_TIMERANGE = 12 hours;

    bytes4 private constant FUNC_EXECUTE = bytes4(keccak256("execute(address,uint256,bytes)"));
    bytes4 private constant FUNC_EXECUTE_BATCH = bytes4(keccak256("executeBatch(address[],bytes[])"));
    bytes4 private constant FUNC_EXECUTE_BATCH_VALUE = bytes4(keccak256("executeBatch(address[],uint256[],bytes[])"));
    bytes4 private constant FUNC_EXEC_FROM_MODULE = bytes4(keccak256("execFromModule(bytes)"));

    bytes4 private constant ERC20_TRANSFER = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private constant ERC20_APPROVE = bytes4(keccak256("approve(address,uint256)"));
    bytes4 private constant ERC20_TRANSFER_FROM = bytes4(keccak256("transferFrom(address,address,uint256)"));

    constructor() BasePlugin(keccak256("PLUGIN_DAILYLIMIT_SLOT")) SafeLock("PLUGIN_DAILYLIMIT_SAFELOCK_SLOT", 2 days) {}

    struct DaySpent {
        uint256 dailyLimit;
        uint256 day;
        uint256 spent;
        uint256 nonce;
        uint256 tmpSpent;
    }

    struct Layout {
        uint256 currentDay;
        uint256 nonce;
        mapping(address => address) tokens;
        mapping(address => DaySpent) daySpent;
    }

    function layout() internal view returns (Layout storage l) {
        bytes32 slot = PLUGIN_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function getHookCallType(HookType hookType) external view override returns (CallHelper.CallType calltype) {
        if (hookType == HookType.PreHook) {
            return CallHelper.CallType.Unknown;
        }
        return CallHelper.CallType.DelegateCall;
    }

    function isHookCall(HookType hookType) external view override returns (bool) {
        return true;
    }

    function inited(address wallet) internal view override returns (bool) {
        (wallet); // DelegateCall plugin no need wallet parameter
        return layout().currentDay != 0;
    }

    function _init(bytes calldata data) internal override onlyDelegateCall {
        Layout storage l = layout();
        if (l.currentDay == 0) {
            l.currentDay = _getDay(block.timestamp);
            // decode data
            (address[] memory tokens, uint256[] memory limits) = abi.decode(data, (address[], uint256[]));
            require(tokens.length == limits.length, "Dailylimit: invalid data");
            for (uint256 i = 0; i < tokens.length; i++) {
                uint256 limit = limits[i];
                require(limit > 0, "Dailylimit: invalid limit");
                l.tokens.add(tokens[i]);
                l.daySpent[tokens[i]] = DaySpent(limit, 0, 0, 0, 0);
            }
            emit DailyLimitChanged(tokens, limits);
        }
    }

    function _deInit() internal override onlyDelegateCall {
        Layout storage l = layout();
        if (l.currentDay != 0) {
            l.currentDay = 0;
            l.tokens.clear();
        }
    }

    function _getTokenAddress(address token) private pure returns (address) {
        return token == address(0) ? ETH_TOKEN_ADDRESS : token;
    }

    function _getTokenDailyLimit(address token) private view returns (uint256) {
        return layout().daySpent[_getTokenAddress(token)].dailyLimit;
    }

    function _getDay(uint256 timeNow) private pure returns (uint256) {
        return timeNow / 1 days;
    }

    function _getDaySpent(address token, uint256 timeNow) private view returns (uint128) {
        uint256 day = _getDay(timeNow);
        Layout storage l = layout();
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
        if (selector == ERC20_TRANSFER) {
            (, spent) = abi.decode(data, (address, uint256));
            token = to;
        } else if (selector == ERC20_APPROVE) {
            (, spent) = abi.decode(data, (address, uint256));
            token = to;
        } else if (selector == ERC20_TRANSFER_FROM) {
            (address spender,, uint256 amount) = abi.decode(data, (address, address, uint256));
            if (spender == sender()) {
                token = to;
                spent = amount;
            }
        }
    }

    function _decodeExecute(Layout storage l, uint256 nonce, uint256 day, address to, bytes memory _data) private {
        uint256 dataLength = _data.length;
        if (dataLength > 4 && l.tokens.isExist(to)) {
            bytes4 selector;
            assembly {
                selector := mload(add(_data, 0x20))
            }
            bytes memory data;
            assembly {
                mstore(data, sub(dataLength, 4))
                calldatacopy(add(data, 0x20), 0x24, /* 32+4 */ sub(dataLength, 4))
            }

            (address token, uint256 spent) = _decodeERC20Spent(selector, to, data);

            if (spent > 0) {
                DaySpent storage _DaySpent = l.daySpent[token];
                if (_DaySpent.nonce != nonce) {
                    _DaySpent.nonce = nonce;
                    if (_DaySpent.day == day) {
                        _DaySpent.tmpSpent = _DaySpent.spent;
                    } else {
                        _DaySpent.tmpSpent = 0;
                    }
                }
                uint256 _spent = 0;
                if (_DaySpent.day == day) {
                    _spent = _DaySpent.spent;
                } else {
                    _DaySpent.day = day;
                }
                uint256 _newSpent = _DaySpent.tmpSpent + spent;
                require(_newSpent <= _DaySpent.dailyLimit, "Dailylimit: token daily limit reached");
            }
        }
    }

    function _decodeCalldata(uint256 nonce, uint256 day, bytes calldata data) private returns (uint256 ethSpent) {
        bytes4 selector = bytes4(data[0:4]);
        if (selector == FUNC_EXECUTE) {
            // execute(address,uint256,bytes)
            (address to, uint256 value, bytes memory _data) = abi.decode(data[4:], (address, uint256, bytes));
            _decodeExecute(layout(), nonce, day, to, _data);
            ethSpent = value;
        } else if (selector == FUNC_EXECUTE_BATCH) {
            // executeBatch(address[],bytes[])
            (address[] memory tos, bytes[] memory _datas) = abi.decode(data[4:], (address[], bytes[]));
            Layout storage l = layout();
            for (uint256 i = 0; i < tos.length; i++) {
                _decodeExecute(l, nonce, day, tos[i], _datas[i]);
            }
        } else if (selector == FUNC_EXECUTE_BATCH_VALUE) {
            // executeBatch(address[],uint256[],bytes[])
            (address[] memory tos, uint256[] memory values, bytes[] memory _datas) =
                abi.decode(data[4:], (address[], uint256[], bytes[]));
            Layout storage l = layout();
            for (uint256 i = 0; i < tos.length; i++) {
                uint256 value = values[i];
                _decodeExecute(l, nonce, day, tos[i], _datas[i]);
                ethSpent += value;
            }
        } else if (selector == FUNC_EXEC_FROM_MODULE) {
            // decode
            bytes calldata _data = data[4:];
            return _decodeCalldata(nonce, day, _data);
        }
    }

    function calcRequiredPrefund(UserOperation calldata userOp) private pure returns (uint256 requiredPrefund) {
        uint256 requiredGas = userOp.callGasLimit + userOp.verificationGasLimit + userOp.preVerificationGas;
        requiredPrefund = requiredGas * userOp.maxFeePerGas;
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) external override {
        (userOpHash);

        uint256 _validationData = SignatureDecoder.decodeSignature(userOp.signature).validationData;
        if (_validationData > 0) {
            ValidationData memory validationData = _parseValidationData(_validationData);
            require(
                validationData.validUntil - validationData.validAfter < MAX_TIMERANGE,
                "Dailylimit: exceed max timerange"
            );

            uint256 currentDay = _getDay(validationData.validAfter);
            Layout storage l = layout();
            l.currentDay = currentDay;
            l.nonce += 1;
            uint256 ethSpent = _decodeCalldata(l.nonce, currentDay, userOp.callData);

            if (l.tokens.isExist(ETH_TOKEN_ADDRESS)) {
                // calculate ETH gas fee , if not use paymaster
                uint256 ethGasFee;
                if (userOp.paymasterAndData.length == 0) {
                    ethGasFee = calcRequiredPrefund(userOp);
                    ethSpent += ethGasFee;
                }

                DaySpent storage _DaySpent = l.daySpent[ETH_TOKEN_ADDRESS];

                uint256 _ethSpent;
                if (_DaySpent.day == currentDay) {
                    _ethSpent = _DaySpent.spent;
                } else {
                    _DaySpent.day = currentDay;
                }

                uint256 _newSpent = _ethSpent + ethSpent;
                require(_newSpent <= _DaySpent.dailyLimit, "Dailylimit: ETH daily limit reached");

                // gas fee not exact here
                // The spent is updated here because it is not possible to process this data in the preHook or postHook
                _DaySpent.spent = _newSpent;
            }
        } else {
            revert("Dailylimit: signature timerange invalid");
        }
    }

    function preHook(address target, uint256 value, bytes calldata data) external override {
        (target, value, data);
        revert("Dailylimit: preHook not support");
    }

    function postHook(address target, uint256 value, bytes calldata data) external override {
        uint256 day = _getDay(block.timestamp);
        Layout storage l = layout();
        if (value > 0 && l.tokens.isExist(ETH_TOKEN_ADDRESS)) {
            DaySpent storage _DaySpent = l.daySpent[ETH_TOKEN_ADDRESS];
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
        if (l.tokens.isExist(target)) {
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
        Layout storage l = layout();
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
        lock(hash);

        emit PreSetDailyLimit(token, limit);
    }

    function cancelSetDailyLimit(address[] calldata token, uint256[] calldata limit) external override {
        bytes32 hash = keccak256(abi.encode(token, limit));
        cancelLock(hash);

        emit CancelSetDailyLimit(token, limit);
    }

    function comfirmSetDailyLimit(address[] calldata token, uint256[] calldata limit) external override {
        bytes32 hash = keccak256(abi.encode(token, limit));
        unlock(hash);
        require(token.length == limit.length, "Dailylimit: invalid data");
        Layout storage l = layout();
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
                    l.daySpent[_token] = DaySpent(_amount, 0, 0, 0, 0);
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

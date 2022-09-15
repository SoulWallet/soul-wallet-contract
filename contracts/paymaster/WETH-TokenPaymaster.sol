// SPDX-License-Identifier: GPL-3.0

/*
    source from:https://github.com/eth-infinitism/account-abstraction/releases/tag/audit
*/

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../EntryPoint.sol";

/**
 * Paymaster that accepts WETH tokens as payment.
 * The paymaster must be approved to transfer tokens from the user wallet.
 */
contract WETHTokenPaymaster is IPaymaster, Ownable {
    //calculated cost of the postOp
    uint256 constant COST_OF_POST = 15000;

    using UserOperationLib for UserOperation;
    EntryPoint public entryPoint;
    IERC20 public WETHToken;
    mapping(bytes32 => bool) public KnownWallets;

    constructor(EntryPoint _entryPoint, IERC20 _WETHToken) {
        setEntrypoint(_entryPoint);
        WETHToken = _WETHToken;
    }

    function setEntrypoint(EntryPoint _entryPoint) public onlyOwner {
        entryPoint = _entryPoint;
    }

    function addWallet(bytes32 walletCodeHash) public onlyOwner {
        KnownWallets[walletCodeHash] = true;
    }

    function removeWallet(bytes32 walletCodeHash) public onlyOwner {
        delete KnownWallets[walletCodeHash];
    }

    function withdraw(address payable to) public onlyOwner {
        uint256 balance = WETHToken.balanceOf(address(this));
        require(balance >= 0, "not enough balance");
        WETHToken.transfer(to, balance);
    }

    /**
     * @dev check allowance amount and user wallet banlance
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, /*requestId*/
        uint256 requiredPreFund
    ) external view returns (bytes memory context) {
        // make sure that verificationGas is high enough to handle postOp
        require(
            userOp.verificationGas > 16000,
            "WETH-TokenPaymaster: gas too low for postOp"
        );

        address sender = userOp.getSender();

        if (userOp.initCode.length != 0) {
            _validateConstructor(userOp);
        } else {
            require(
                WETHToken.allowance(sender, address(this)) >= requiredPreFund,
                "WETH-TokenPaymaster: not enough allowance"
            );
        }
        require(
            WETHToken.balanceOf(sender) >= requiredPreFund,
            "WETH-TokenPaymaster: not enough balance"
        );
        return "";
    }

    // when constructing a wallet, validate constructor code and parameters
    function _validateConstructor(UserOperation calldata userOp)
        internal
        view
        virtual
    {
        //constructor(EntryPoint anEntryPoint, address anOwner, IERC20 token, address paymaster)
        bytes32 bytecodeHash = keccak256(
            userOp.initCode[0:userOp.initCode.length - 128]
        );
        require(
            KnownWallets[bytecodeHash],
            "TokenPaymaster: unknown wallet constructor"
        );

        //verify the token constructor params:

        // first param (of 4) should be our entryPoint
        bytes32 entryPointParam = bytes32(
            userOp.initCode[userOp.initCode.length - 128:]
        );
        require(
            address(uint160(uint256(entryPointParam))) == address(entryPoint),
            "wrong paymaster in constructor"
        );

        //the 3nd parameter is WETH token
        bytes32 tokenParam = bytes32(
            userOp.initCode[userOp.initCode.length - 64:]
        );
        require(
            address(uint160(uint256(tokenParam))) == address(WETHToken),
            "wrong token in constructor"
        );

        // //the 4nd parameter is this paymaster
        // bytes32 paymasterParam = bytes32(
        //     userOp.initCode[userOp.initCode.length - 32:]
        // );
        // require(
        //     address(uint160(uint256(paymasterParam))) == address(this),
        //     "wrong paymaster in constructor"
        // );
    }

    /// validate the call is made from a valid entrypoint
    function _requireFromEntrypoint() internal virtual {
        require(msg.sender == address(entryPoint));
    }

    //actual charge of user.
    // this method will be called just after the user's TX with mode==OpSucceeded|OpReverted.
    // BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
    // the user's TX
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external override {
        (mode);
        _requireFromEntrypoint();

        address sender = abi.decode(context, (address));
        //actualGasCost is known to be no larger than the above requiredPreFund, so the transfer should succeed.
        WETHToken.transferFrom(
            sender,
            address(this),
            actualGasCost + COST_OF_POST
        );
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./EntryPoint.sol";
import "./BasePaymaster.sol";

/**
 * Paymaster that accepts WETH tokens as payment.
 * The paymaster must be approved to transfer tokens from the user wallet.
 */
contract WETHTokenPaymaster is BasePaymaster {
    //calculated cost of the postOp
    uint256 constant COST_OF_POST = 20000;

    using UserOperationLib for UserOperation;
    IERC20 public WETHToken;
    mapping(bytes32 => bool) public KnownWallets;

    constructor(
        EntryPoint _entryPoint,
        IERC20 _WETHToken,
        address _owner
    ) BasePaymaster(_entryPoint) {
        WETHToken = _WETHToken;
        _transferOwnership(_owner);
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
     * validate the request:
     * if this is a constructor call, make sure it is a known account (that is, a contract that
     * we trust that in its constructor will set
     * verify the sender has enough tokens.
     * (since the paymaster is also the token, there is no notion of "approval")
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 requiredPreFund
    ) external view override returns (bytes memory context, uint256 deadline) {
        require(
            userOp.verificationGasLimit > 45000,
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

        return (abi.encode(userOp.sender, userOp.gasPrice()), 0);
    }

    // when constructing a wallet, validate constructor code and parameters
    function _validateConstructor(
        UserOperation calldata userOp
    ) internal view virtual {
        /*
        constructor(IEntryPoint _entryPoint,
            address _owner,
            uint32 _upgradeDelay,
            uint32 _guardianDelay,
            address _guardian,
            IERC20 _erc20token,
            address _paymaster)
        */
        bytes32 bytecodeHash = keccak256(
            userOp.initCode[0:userOp.initCode.length -
                270] /* (32*7)+46=270  46 is fixed in current parameter encode */
        );

        // no check on POC
        (bytecodeHash);
        // require(
        //     KnownWallets[bytecodeHash],
        //     "TokenPaymaster: unknown wallet constructor"
        // );

        // first param (of 7) should be our entryPoint
        bytes32 entryPointParam = bytes32(
            userOp.initCode[userOp.initCode.length - 270:]
        );
        require(
            address(uint160(uint256(entryPointParam))) == address(entryPoint),
            "wrong paymaster in constructor"
        );

        //the 6th parameter is WETH token
        bytes32 tokenParam = bytes32(
            userOp.initCode[userOp.initCode.length - 110:] /* 64+46=110 */
        );
        require(
            address(uint160(uint256(tokenParam))) == address(WETHToken),
            "wrong token in constructor"
        );

        //the 7th parameter is this paymaster
        bytes32 paymasterParam = bytes32(
            userOp.initCode[userOp.initCode.length - 78:] /* 32+46=78 */
        );
        require(
            address(uint160(uint256(paymasterParam))) == address(this),
            "wrong paymaster in constructor"
        );
    }

    //actual charge of user.
    // this method will be called just after the user's TX with mode==OpSucceeded|OpReverted.
    // BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
    // the user's TX
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        (mode);
        (address sender, uint256 gasPrice) = abi.decode(
            context,
            (address, uint256)
        );
        //actualGasCost is known to be no larger than the above requiredPreFund, so the transfer should succeed.
        WETHToken.transferFrom(
            sender,
            address(this),
            actualGasCost + (COST_OF_POST * gasPrice)
        );
    }
}

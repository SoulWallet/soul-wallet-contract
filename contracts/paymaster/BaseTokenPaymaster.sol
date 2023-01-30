// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../EntryPoint.sol";
import "../interfaces/UserOperation.sol";
import "../BasePaymaster.sol";
import "hardhat/console.sol";

abstract contract BaseTokenPaymaster is BasePaymaster {

    using UserOperationLib for UserOperation;

    /**
     * @dev Emitted when new wallet logic hash added
     */
    event KnownWalletLogicHashAdd(
        bytes32[] walletCodeHash
    );

    /**
     * @dev Emitted when wallet logic hash removed
     */
    event KnownWalletLogicHashRemove(
        bytes32[] walletCodeHash
    );

    /**
     * @dev Emitted when the contract is paused
     */
    event Paused();

    /**
     * @dev Emitted when the contract is unpaused
     */
    event Unpaused();

    /**
     * @notice The ERC20 token that will be used to pay for the gas
     */
    IERC20 public immutable ERC20Token;


    bool public isPaused = false;


    //calculated cost of the postOp
    uint256 private immutable COST_OF_POST;

    /**
     * @notice The soulwallet proxy bytecode length
     */
    uint256 internal constant SOULPROXY_BYTECODE_LEN = 806;
    /**
     * @notice The soulwallet proxy bytecode hash
     */
    bytes32 internal constant SOULPROXY_BYTECODE_HASH = 0xf09caa9a155fd1b974d15a05d0028ca69e57dfb8cdb663cda591650ca4660f70;

    /**
     * @notice The known wallet logic hash,only the wallet logic in this list can be deployed
     */
    mapping(bytes32 => bool) internal KnownWalletLogicHash;

    constructor(
        EntryPoint _entryPoint,
        IERC20 _ERC20Token,
        uint256 _COST_OF_POST,
        address _owner
    ) BasePaymaster(_entryPoint) {
        ERC20Token = _ERC20Token;
        COST_OF_POST = _COST_OF_POST;
        if(_owner != address(0)){
            _transferOwnership(_owner);
        }
    }

    function pause() public onlyOwner {
        require(!isPaused, "Paymaster: paused");
        isPaused = true;
        emit Paused();
    }

    function unpause() public onlyOwner {
        require(isPaused, "Paymaster: unpaused");
        isPaused = false;
        emit Unpaused();
    }

    function addKnownWalletLogic(
        bytes32[] calldata walletCodeHash
    ) external onlyOwner {
        for (uint256 i = 0; i < walletCodeHash.length; i++) {
            KnownWalletLogicHash[walletCodeHash[i]] = true;
        }
        emit KnownWalletLogicHashAdd(walletCodeHash);
    }

    function removeKnownWalletLogic(
        bytes32[] calldata walletCodeHash
    ) external onlyOwner {
        for (uint256 i = 0; i < walletCodeHash.length; i++) {
            delete KnownWalletLogicHash[walletCodeHash[i]];
        }
        emit KnownWalletLogicHashRemove(walletCodeHash);
    }

    function withdraw(address payable to) external onlyOwner {
        uint256 balance = ERC20Token.balanceOf(address(this));
        require(balance >= 0, "not enough balance");
        ERC20Token.transfer(to, balance);
    }

    function tokenPrice(uint256 ethers) public view virtual returns (uint256) {
        (ethers);
        revert("must override");
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

        require(!isPaused, "Paymaster: paused");
        require(
            userOp.verificationGasLimit > 45000,
            "Paymaster: gas too low for postOp"
        );

        uint256 tokenRequiredPreFund = tokenPrice(requiredPreFund);

        address sender = userOp.getSender();

        if (userOp.initCode.length != 0) {
            _validateConstructor(userOp);
        } else {
            require(
                ERC20Token.allowance(sender, address(this)) >= tokenRequiredPreFund,
                "Paymaster: not enough allowance"
            );
        }

        require(
            ERC20Token.balanceOf(sender) >= tokenRequiredPreFund,
            "Paymaster: not enough balance"
        );

        uint size;
        assembly {
            size := extcodesize(sender)
        }

        return (abi.encode(sender, userOp.gasPrice()), 0);
    }


    // when constructing a wallet, validate constructor code and parameters
    function _validateConstructor(
        UserOperation calldata userOp
    ) internal view {
        /*
            function initialize(
                IEntryPoint _entryPoint,
                address _owner,
                uint32 _upgradeDelay,
                uint32 _guardianDelay,
                address _guardian,
                bytes memory _tokenAndPaymaster
            )
        */

        bytes32 bytecodeHash = keccak256(
            userOp.initCode[0:SOULPROXY_BYTECODE_LEN]
        );

        require(
            SOULPROXY_BYTECODE_HASH == bytecodeHash,
            "Paymaster: unknown wallet proxy"
        );

        bytes memory subinitCode = userOp.initCode[SOULPROXY_BYTECODE_LEN:];
        // check the wallet logic
        {
            address _walletLogic;
            assembly {
                _walletLogic := mload(add(subinitCode, 32))
            }
            // get walletLogic bytecode hash
            bytes32 _logicHash;
            assembly {
                _logicHash := extcodehash(_walletLogic)
            }
            require(
                KnownWalletLogicHash[_logicHash],
                "Paymaster: unknown wallet logic"
            );
        }

        // check call function signature
        {
            bytes4 _callSig;
            assembly {
                _callSig := mload(add(subinitCode, 128 /* 32+32+32+32 */))
            }
            require(_callSig == 0xe12c8096, "Paymaster: wrong callSig"); // initialize(address,address,uint32,uint32,address,bytes)	0xe12c8096
        }

        // check entryPoint
        {
            address _entryPoint;
            assembly {
                _entryPoint := mload(add(subinitCode, 132 /* 128+4 */))
            }
            require(
                _entryPoint == address(entryPoint),
                "Paymaster: wrong entryPoint in constructor"
            );
        }

        // check tokenAndPaymaster
        {
            bytes memory _tokenAndPaymaster;
            assembly {
                _tokenAndPaymaster := add(subinitCode, 324 /* 132+(6*32) */)
            }

            require(
                _tokenAndPaymaster.length % 40 == 0,
                "Paymaster: invalid length"
            );
            uint256 numTokens = _tokenAndPaymaster.length / 40;
            uint256 i;
            bool found = false;
            for (i = 0; i < numTokens; ) {
                address token;
                address paymaster;
                assembly {
                    token := mload(add(add(_tokenAndPaymaster, 20), mul(i, 40)))
                    paymaster := mload(
                        add(add(_tokenAndPaymaster, 20), add(20, mul(i, 40)))
                    )
                }
                if (token == address(ERC20Token) && paymaster == address(this)) {
                    found = true;
                    break;
                }
                unchecked {
                    i++;
                }
            }
            require(found, "Paymaster: must approve Token");
        }
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
        ERC20Token.transferFrom(
            sender,
            address(this),
            actualGasCost + (COST_OF_POST * gasPrice)
        );
         uint size;
        assembly {
            size := extcodesize(sender)
        }
    }
}

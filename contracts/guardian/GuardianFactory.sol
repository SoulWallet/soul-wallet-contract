// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./GuardianMultiSigProxy.sol";
import "../interfaces/IGuardianMultiSigWallet.sol";

/**
 * @title GuardianFactory
 * @dev permissionless factory to create guardian multisig wallets
 */
contract GuardianFactory {
      event NewGuardianCreated(
        address indexed addr
    );
    function deploy(
        address _logic,
        bytes memory _data,
        bytes32 _salt
    ) internal returns (address) {
        // This syntax is a newer way to invoke create2 without assembly, you just need to pass salt
        // https://docs.soliditylang.org/en/latest/control-structures.html#salted-contract-creations-create2
        return address(new GuardianMultiSigProxy{salt: _salt}(_logic, _data));
    }

    function getGuardianAddress(
        address _logic,
        bytes memory _data,
        bytes32 _salt
    ) public view returns (address) {
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                _salt,
                                keccak256(
                                    abi.encodePacked(
                                        type(GuardianMultiSigProxy)
                                            .creationCode,
                                        abi.encode(_logic, _data)
                                    )
                                )
                            )
                        )
                    )
                )
            );
    }

    function createGuardianMultiSig(
        address _guardianMultiSigImpAddr,
        address[] calldata _guardians,
        uint256 _threshold,
        bytes32 _salt
    ) public returns (address) {
        address clone = address(
            deploy(
                _guardianMultiSigImpAddr,
                abi.encodeWithSelector(
                    IGuardianMultiSigWallet.initialize.selector,
                    _guardians,
                    _threshold
                ),
                _salt
            )
        );
        emit NewGuardianCreated(clone);
        return clone;
    }
}

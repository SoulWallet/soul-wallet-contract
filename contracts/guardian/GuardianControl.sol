// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "../interfaces/IGuardianControl.sol";
import "../entrypoint/SenderCreator.sol";
import "../AccountStorage.sol";

contract GuardianControl is IGuardianControl {
    using AccountStorage for AccountStorage.Layout;
    using ECDSA for bytes32;

    struct GuardianCallData {
        bytes signature;
        bytes initCode;
    }

    SenderCreator private immutable senderCreator = new SenderCreator();

    /**
     * @dev decode guardian call data (data in signature)
     */
    function decodeGuardianCallData(
        bytes memory guardianCallData
    ) internal pure returns (GuardianCallData memory) {
        (bytes memory _signature, bytes memory _initCode) = abi.decode(
            guardianCallData,
            (bytes, bytes)
        );
        return GuardianCallData(_signature, _initCode);
    }

    /**
     * @dev get guardian info
     * @return (address,address,uint64,uint32) : (guardian now,guardian next,`guardian next` effective time, guardian delay)
     */
    function guardianInfo()
        public
        view
        returns (address, address, uint64, uint32)
    {
        GuardianLayout memory l = AccountStorage.layout().guardian;
        return (l.guardian, l.pendingGuardian, l.activateTime, l.guardianDelay);
    }

    function guardianProcess() public returns (bool) {
        IGuardianControl.GuardianLayout storage layout = AccountStorage
            .layout()
            .guardian;
        return _guardianProcess(layout);
    }

    function _guardianProcess(
        IGuardianControl.GuardianLayout storage layout
    ) private returns (bool) {
        if (
            layout.activateTime != 0 && layout.activateTime <= block.timestamp
        ) {
            layout.activateTime = 0;
            _setGuardian(layout, layout.pendingGuardian);
            layout.pendingGuardian = address(0);
            return true;
        } else {
            return false;
        }
    }

    function _setGuardianDelay(uint32 guardianDelay) internal {
        // set guardian delay
        IGuardianControl.GuardianLayout storage layout = AccountStorage
            .layout()
            .guardian;
        _setGuardianDelay(layout, guardianDelay);
    }

    function _setGuardianDelay(
        IGuardianControl.GuardianLayout storage layout,
        uint32 guardianDelay
    ) internal {
        // set guardian delay
        layout.guardianDelay = guardianDelay;
    }

    function _setGuardian(
        IGuardianControl.GuardianLayout storage layout,
        address guardian
    ) internal {
        emit GuardianConfirmed(guardian, layout.guardian);
        layout.guardian = guardian;
    }

    function _setGuardianWithDelay(address guardian) internal {
        IGuardianControl.GuardianLayout storage layout = AccountStorage
            .layout()
            .guardian;

        _guardianProcess(layout);

        layout.pendingGuardian = guardian;
        layout.activateTime = uint64(block.timestamp + layout.guardianDelay);
        emit GuardianSet(guardian, layout.activateTime);
    }

    function _cancelGuardian(address guardian) internal {
        IGuardianControl.GuardianLayout storage layout = AccountStorage
            .layout()
            .guardian;

        _guardianProcess(layout);

        require(
            layout.pendingGuardian == guardian,
            "GuardianControl: guardian not pending"
        );

        emit GuardianCanceled(guardian);
        layout.pendingGuardian = address(0);
        layout.activateTime = 0;
    }

    function _validateGuardiansSignatureCallData(
        address signer,
        bytes32 hash,
        bytes memory guardianSignature
    ) internal returns (bool success){

        /*

            In fact, no signature is performed on guardianInitCode, because no 
            matter how guardianInitCode is tampered with and changed, as long as 
            `senderCreator.createSender(guardianCallData.initCode) == guardian`
            is guaranteed, it meets the expectation，so we don't need to verify.

         */
        
        GuardianCallData memory guardianCallData = decodeGuardianCallData(
            guardianSignature
        );
        IGuardianControl.GuardianLayout storage layout = AccountStorage
            .layout()
            .guardian;

        _guardianProcess(layout);

        address guardian = layout.guardian;
        
        if(guardian != signer){
            return false;
        }

        /*
            During social recovery, create2 is used during execution validation,
            which means that the bundler need to allow known guardian contracts 
            to use create2 once when guardianInitCode.length > 0, and need to 
            allow to access known guardian contracts storage.
         */

        if (guardianCallData.initCode.length > 0) {
            bool deployed = senderCreator.createSender(guardianCallData.initCode) == guardian;
            if(!deployed){
                //guardian contract not deployed
                return false;
            }
        }

        return SignatureChecker.isValidSignatureNow(
                guardian,
                hash,
                guardianCallData.signature
            );
    }
}

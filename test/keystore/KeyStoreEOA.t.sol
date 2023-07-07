// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/keystore/L1/KeyStoreEOA.sol";
import "@source/keystore/L1/interfaces/IKeyStore.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract KeyStoreEOATest is Test {
    using ECDSA for bytes32;

    KeyStoreEOA keyStoreEOA;

    function setUp() public {
        keyStoreEOA = new KeyStoreEOA();
    }

    function test_storageLayout() public {
        /*
            # Storage Layout

            slot offset
            ┌──────────┬────────────────────────────────┬────────────────┐
            │  offset 0│ Key (EOA)                      │                │
            ├──────────┼────────────────────────────────┤                │
            │  offset 1│ nonce                          │                │
            ├──────────┼────────────────────────────────┤                ├──────────────────┐
            │  offset 2│ guardianHash                   │                │                  │
            ├──────────┼────────────────────────────────┤                │                  │
            │  offset 3│ pendingGuardianHash            │                │                  │
            ├──────────┼────────────────────────────────┤  KeyStoreInfo  │                  │
            │  offset 4│ guardianActivateAt             │                │                  │
            ├──────────┼────────────────────────────────┤                │                  │
            │  offset 5│ guardianSafePeriod             │                │   guardianInfo   │
            ├──────────┼────────────────────────────────┤                │                  │
            │  offset 6│ pendingGuardianSafePeriod      │                │                  │
            ├──────────┼────────────────────────────────┤                │                  │
            │  offset 7│ guardianSafePeriodActivateAt   │                │                  │
            └──────────┴────────────────────────────────┴────────────────┴──────────────────┘

        */

        bytes32 slot_start = keccak256("0x1");

        // solt #0
        address _slot_0;
        (_slot_0,) = makeAddrAndKey("0");
        bytes32 slot_0 = bytes32(uint256(uint160(_slot_0)));
        vm.store(address(keyStoreEOA), slot_start, slot_0);

        // solt #1
        uint256 _slot_1 = 1;
        bytes32 slot_1 = bytes32(_slot_1);
        bytes32 slot_offset1;
        assembly {
            slot_offset1 := add(slot_start, 1)
        }
        vm.store(address(keyStoreEOA), slot_offset1, slot_1);

        // solt #2
        bytes32 _slot_2 = bytes32(uint256(uint160(address(this))));
        bytes32 slot_offset2;
        assembly {
            slot_offset2 := add(slot_start, 2)
        }
        vm.store(address(keyStoreEOA), slot_offset2, _slot_2);

        IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreEOA.getKeyStoreInfo(slot_start);

        require(_keyStoreInfo.key == slot_0, "keyStoreInfo.key != slot_0");
        require(_keyStoreInfo.nonce == _slot_1, "keyStoreInfo.nonce != slot_1");
        require(_keyStoreInfo.guardianHash == _slot_2, "keyStoreInfo.guardianHash != slot_2");
    }

    function test_changeKey() public {
        bytes32 initialKey;
        address _initialKey;
        uint256 _initialPrivateKey;
        (_initialKey, _initialPrivateKey) = makeAddrAndKey("initialKey");
        initialKey = bytes32(uint256(uint160(_initialKey)));
        bytes32 initialGuardianHash = keccak256("0x1");
        uint64 initialGuardianSafePeriod = 2 days;

        bytes32 slot = keyStoreEOA.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        {
            IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreEOA.getKeyStoreInfo(slot);
            require(_keyStoreInfo.key == 0, "keyStoreInfo.key != 0");
            require(_keyStoreInfo.nonce == 0, "keyStoreInfo.nonce != 0");
            require(_keyStoreInfo.guardianHash == 0, "keyStoreInfo.guardianHash != 0");
            require(_keyStoreInfo.guardianSafePeriod == 0, "keyStoreInfo.guardianSafePeriod != 0");
        }

        /* 
        function setKey(
            bytes32 initialKey,
            bytes32 initialGuardianHash,
            uint64 initialGuardianSafePeriod,
            bytes32 newKey,
            bytes calldata keySignature
        ) external;
         */
        {
            address _initialKey_new_1;
            uint256 _initialPrivateKey_new_1;
            (_initialKey_new_1, _initialPrivateKey_new_1) = makeAddrAndKey("initialKey_new_1");
            bytes32 initialKey_new_1 = bytes32(uint256(uint160(_initialKey_new_1)));
            uint256 nonce = keyStoreEOA.nonce(slot);
            //return keccak256(abi.encode(address(this), slot, _nonce, data)).toEthSignedMessageHash();
            bytes32 messageHash =
                keccak256(abi.encode(address(keyStoreEOA), slot, nonce, initialKey_new_1)).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_initialPrivateKey_new_1, messageHash);
            bytes memory keySignature = abi.encodePacked(r, s, v);
            keyStoreEOA.setKey(
                initialKey, initialGuardianHash, initialGuardianSafePeriod, initialKey_new_1, keySignature
            );

            slot = keyStoreEOA.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);
            {
                IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreEOA.getKeyStoreInfo(slot);
                require(_keyStoreInfo.key == initialKey_new_1, "keyStoreInfo.key != initialKey_new");
                require(_keyStoreInfo.nonce == 1, "keyStoreInfo.nonce != 1");
                require(
                    _keyStoreInfo.guardianHash == initialGuardianHash,
                    "keyStoreInfo.guardianHash != initialGuardianHash"
                );

                require(_keyStoreInfo.pendingGuardianHash == 0, "keyStoreInfo.pendingGuardianHash != 0");
                require(_keyStoreInfo.guardianActivateAt == 0, "keyStoreInfo.guardianActivateAt != 0");
                require(
                    _keyStoreInfo.guardianSafePeriod == initialGuardianSafePeriod,
                    "keyStoreInfo.guardianSafePeriod != initialGuardianSafePeriod"
                );
                require(_keyStoreInfo.pendingGuardianSafePeriod == 0, "keyStoreInfo.pendingGuardianSafePeriod != 0");
                require(
                    _keyStoreInfo.guardianSafePeriodActivateAt == 0, "keyStoreInfo.guardianSafePeriodActivateAt != 0"
                );
            }

            address _initialKey_new_2;
            uint256 _initialPrivateKey_new_2;
            (_initialKey_new_2, _initialPrivateKey_new_2) = makeAddrAndKey("initialKey_new_2");
            bytes32 initialKey_new_2 = bytes32(uint256(uint160(_initialKey_new_2)));
            nonce = keyStoreEOA.nonce(slot);
            messageHash =
                keccak256(abi.encode(address(keyStoreEOA), slot, nonce, initialKey_new_2)).toEthSignedMessageHash();
            (v, r, s) = vm.sign(_initialPrivateKey_new_2, messageHash);
            keySignature = abi.encodePacked(r, s, v);
            keyStoreEOA.setKey(
                initialKey, initialGuardianHash, initialGuardianSafePeriod, initialKey_new_2, keySignature
            );
            {
                IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreEOA.getKeyStoreInfo(slot);
                require(_keyStoreInfo.key == initialKey_new_2, "keyStoreInfo.key != initialKey_new");
            }
        }
    }
}

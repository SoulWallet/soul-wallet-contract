// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/keystore/L1/KeyStoreEOA.sol";
import "@source/keystore/L1/interfaces/IKeyStore.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/dev/EIP1271Wallet.sol";

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

    function _signMsg(bytes32 messageHash, uint256 privateKey) private pure returns (bytes memory) {
        if (privateKey == 0) {
            // SC wallet
            bool _valid = true;
            bytes memory sig = abi.encode(messageHash, _valid);
            return sig;
        } else {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash.toEthSignedMessageHash());
            return abi.encodePacked(v, s, r);
        }
    }

    function test_socialRecovery() public {
        EIP1271Wallet SCwallet1 = new EIP1271Wallet();
        EIP1271Wallet SCwallet2 = new EIP1271Wallet();
        EIP1271Wallet SCwallet3 = new EIP1271Wallet();
        (address EOAWallet1,) = makeAddrAndKey("1");
        (address EOAWallet2,) = makeAddrAndKey("2");
        (address EOAWallet3,) = makeAddrAndKey("3");
        (address EOAWallet4, uint256 EOAPrivatekey4) = makeAddrAndKey("4");

        /*
            (address[] memory guardians, uint256 threshold, uint256 salt) = abi.decode(rawGuardian, (address[], uint256, uint256));
        */
        address[] memory guardians = new address[](7);
        guardians[0] = EOAWallet1;
        guardians[1] = address(SCwallet1);
        guardians[2] = EOAWallet2;
        guardians[3] = EOAWallet3;
        guardians[4] = EOAWallet4;
        guardians[5] = address(SCwallet2);
        guardians[6] = address(SCwallet3);
        uint256 threshold = 3;
        uint256 salt = 0x12345678;
        bytes memory rawGuardian = abi.encode(guardians, threshold, salt);
        bytes32 initialGuardianHash = keccak256(rawGuardian);

        bytes32 initialKey = keccak256("0x123");
        uint64 initialGuardianSafePeriod = 2 days;

        bytes32 slot = keyStoreEOA.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);

        /* 
        function setKey(
                bytes32 initialKey,
                bytes32 initialGuardianHash,
                uint64 initialGuardianSafePeriod,
                bytes32 newKey,
                bytes calldata rawGuardian,
                bytes calldata guardianSignature
            ) external;
        */
        address _newKey = address(0x111);
        bytes32 newKey = bytes32(uint256(uint160(_newKey)));
        uint256 nonce = keyStoreEOA.nonce(slot);

        // return keccak256(abi.encode(address(this), slot, _nonce, data));
        bytes32 signMessageHash = keccak256(abi.encode(address(keyStoreEOA), slot, nonce, newKey));

        uint8 v;
        bytes4 s_bytes4;

        // sign [0],skip
        v = 2;
        s_bytes4 = 0;
        bytes memory _sign0 = abi.encodePacked(v, s_bytes4);

        // sign [1],  approvedHashes
        vm.prank(address(SCwallet1));
        keyStoreEOA.approveHash(signMessageHash);
        v = 1;
        bytes memory _sign1 = abi.encodePacked(v);

        // sign [2~3], skip
        v = 2;
        s_bytes4 = bytes4(uint32(1));
        bytes memory _sign2 = abi.encodePacked(v, s_bytes4);

        // sign [4]
        bytes memory _sign4 = _signMsg(signMessageHash, EOAPrivatekey4);

        // sign [5], skip
        v = 2;
        s_bytes4 = 0;
        bytes memory _sign5 = abi.encodePacked(v, s_bytes4);

        // sign [6]
        /* 
         EIP-1271 signature
                    s: bytes4 Length of signature data 
                    r: no set
                    dynamic data: signature data
         */
        v = 0;
        bytes memory _signTemp = _signMsg(signMessageHash, 0);
        s_bytes4 = bytes4(uint32(_signTemp.length));
        bytes memory _sign6 = abi.encodePacked(v, s_bytes4, _signTemp);

        bytes memory guardianSignature = abi.encodePacked(_sign0, _sign1, _sign2, _sign4, _sign5, _sign6);

        keyStoreEOA.setKey(
            initialKey, initialGuardianHash, initialGuardianSafePeriod, newKey, rawGuardian, guardianSignature
        );

        IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreEOA.getKeyStoreInfo(slot);
        require(_keyStoreInfo.key == newKey, "keyStoreInfo.key != newKey");
    }

    function test_updateGuardian() public {
        bytes32 initialKey;
        address _initialKey;
        uint256 _initialPrivateKey;
        (_initialKey, _initialPrivateKey) = makeAddrAndKey("initialKey");
        initialKey = bytes32(uint256(uint160(_initialKey)));
        bytes32 initialGuardianHash = keccak256("0x1");
        uint64 initialGuardianSafePeriod = 2 days;

        bytes32 slot = keyStoreEOA.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);

        /*
                function setGuardian(
                    bytes32 initialKey,
                    bytes32 initialGuardianHash,
                    uint64 initialGuardianSafePeriod,
                    bytes32 newGuardianHash,
                    bytes calldata keySignature
                ) external 
             */
        bytes32 newGuardianHash = keccak256("0x2");
        uint256 nonce = keyStoreEOA.nonce(slot);
        //return keccak256(abi.encode(address(this), slot, _nonce, data)).toEthSignedMessageHash();
        bytes32 messageHash =
            keccak256(abi.encode(address(keyStoreEOA), slot, nonce, newGuardianHash)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_initialPrivateKey, messageHash);
        bytes memory keySignature = abi.encodePacked(r, s, v);
        keyStoreEOA.setGuardian(
            initialKey, initialGuardianHash, initialGuardianSafePeriod, newGuardianHash, keySignature
        );
        IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreEOA.getKeyStoreInfo(slot);
        require(
            _keyStoreInfo.pendingGuardianHash == newGuardianHash, "keyStoreInfo.pendingGuardianHash != newGuardianHash"
        );
        require(_keyStoreInfo.guardianHash == initialGuardianHash, "keyStoreInfo.guardianHash != initialGuardianHash");
        require(
            _keyStoreInfo.guardianActivateAt == (block.timestamp + initialGuardianSafePeriod),
            "keyStoreInfo.guardianActivateAt != ( block.timestamp+initialGuardianSafePeriod)"
        );
        for (uint256 i = 0; i < 5; i += 0.6 days) {
            uint256 snapshotId = vm.snapshot();

            bytes32 initialKey_new_1 = bytes32(uint256(uint160(address(0x2))));
            nonce = keyStoreEOA.nonce(slot);
            messageHash =
                keccak256(abi.encode(address(keyStoreEOA), slot, nonce, initialKey_new_1)).toEthSignedMessageHash();
            (v, r, s) = vm.sign(_initialPrivateKey, messageHash);
            keySignature = abi.encodePacked(r, s, v);
            keyStoreEOA.setKey(
                initialKey, initialGuardianHash, initialGuardianSafePeriod, initialKey_new_1, keySignature
            );

            _keyStoreInfo = keyStoreEOA.getKeyStoreInfo(slot);
            require(_keyStoreInfo.key == initialKey_new_1, "keyStoreInfo.key != initialKey_new_1");
            if (i < initialGuardianSafePeriod) {
                require(
                    _keyStoreInfo.guardianHash == initialGuardianHash,
                    "keyStoreInfo.guardianHash != initialGuardianHash"
                );
                require(
                    _keyStoreInfo.pendingGuardianHash == newGuardianHash,
                    "keyStoreInfo.pendingGuardianHash != newGuardianHash"
                );
            } else {
                require(_keyStoreInfo.guardianHash == newGuardianHash, "keyStoreInfo.guardianHash != newGuardianHash");
                require(_keyStoreInfo.pendingGuardianHash == 0, "keyStoreInfo.pendingGuardianHash != 0");
            }

            vm.revertTo(snapshotId);
        }
    }
}

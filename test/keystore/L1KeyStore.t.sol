// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/keystore/L1/KeyStore.sol";
import "@source/keystore/L1/KeyStoreStorage.sol";
import "@source/keystore/L1/interfaces/IKeyStore.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/dev/EIP1271Wallet.sol";
import "@source/validator/KeystoreValidator.sol";

contract L1KeyStoreEOATest is Test {
    using ECDSA for bytes32;

    KeystoreValidator keystoreValidator;

    KeyStore keyStoreContract;
    KeyStoreStorage keyStoreStorage;
    address keystoreAdmin;
    uint256 keystoreAdminPrivateKey;

    bytes32 private constant _TYPE_HASH_SET_KEY =
        keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN =
        keccak256("SetGuardian(bytes32 keyStoreSlot,uint256 nonce,bytes32 newGuardianHash)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("SetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce,uint64 newGuardianSafePeriod)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN =
        keccak256("CancelSetGuardian(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("CancelSetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_SOCIAL_RECOVERY =
        keccak256("SocialRecovery(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");

    bytes32 private constant _TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private DOMAIN_SEPARATOR;

    function setUp() public {
        (keystoreAdmin, keystoreAdminPrivateKey) = makeAddrAndKey("keystore");
        keystoreValidator = new KeystoreValidator();
        keyStoreStorage = new KeyStoreStorage(keystoreAdmin);
        keyStoreContract = new KeyStore(keystoreValidator, keyStoreStorage, keystoreAdmin);
        vm.prank(keystoreAdmin);
        keyStoreStorage.setDefaultKeystoreAddress(address(keyStoreContract));
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _TYPEHASH, keccak256(bytes("KeyStore")), keccak256(bytes("1")), block.chainid, address(keyStoreContract)
            )
        );
    }

    function test_changeKey() public {
        bytes32 initialKey;
        address _initialKey;
        uint256 _initialPrivateKey;
        (_initialKey, _initialPrivateKey) = makeAddrAndKey("initialKey");
        console.log("initialKey:", _initialKey);
        address[] memory owners = new address[](1);
        owners[0] = _initialKey;
        initialKey = keccak256(abi.encode(owners));
        bytes32 initialGuardianHash = keccak256("0x1");
        uint64 initialGuardianSafePeriod = 2 days;

        bytes32 slot = keyStoreContract.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        {
            IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreContract.getKeyStoreInfo(slot);
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
            address[] memory newOwners = new address[](1);
            newOwners[0] = _initialKey_new_1;
            bytes32 initialKey_new_1 = keccak256(abi.encode(newOwners));
            uint256 nonce = keyStoreContract.nonce(slot);
            assertEq(nonce, 0, "nonce != 0");

            bytes32 structHash = keccak256(abi.encode(_TYPE_HASH_SET_KEY, slot, nonce, initialKey_new_1));
            bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_initialPrivateKey, typedDataHash);

            bytes memory keySignature = abi.encodePacked(r, s, v);
            uint8 signType = 0;
            bytes memory validatorSignature = abi.encodePacked(signType, keySignature);
            keyStoreContract.setKeyByOwner(
                initialKey,
                initialGuardianHash,
                initialGuardianSafePeriod,
                abi.encode(newOwners),
                abi.encode(owners),
                validatorSignature
            );

            slot = keyStoreContract.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);
            {
                IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreContract.getKeyStoreInfo(slot);
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

                bytes memory rawOwners = keyStoreContract.rawOwnersBySlot(slot);
                assertEq(rawOwners, abi.encode(newOwners));
            }

            address _initialKey_new_2;
            uint256 _initialPrivateKey_new_2;
            (_initialKey_new_2, _initialPrivateKey_new_2) = makeAddrAndKey("initialKey_new_2");
            address[] memory new_owners_2 = new address[](1);
            new_owners_2[0] = _initialKey_new_2;
            bytes32 initialKey_new_2 = keccak256(abi.encode(new_owners_2));

            nonce = keyStoreContract.nonce(slot);
            assertEq(nonce, 1, "nonce != 1");

            structHash = keccak256(abi.encode(_TYPE_HASH_SET_KEY, slot, nonce, initialKey_new_2));
            typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
            (v, r, s) = vm.sign(_initialPrivateKey_new_1, typedDataHash);
            keySignature = abi.encodePacked(r, s, v);
            validatorSignature = abi.encodePacked(signType, keySignature);

            keyStoreContract.setKeyByOwner(
                initialKey,
                initialGuardianHash,
                initialGuardianSafePeriod,
                abi.encode(new_owners_2),
                abi.encode(newOwners),
                validatorSignature
            );
            nonce = keyStoreContract.nonce(slot);
            assertEq(nonce, 2, "nonce != 2");
            {
                IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreContract.getKeyStoreInfo(slot);
                require(_keyStoreInfo.key == initialKey_new_2, "keyStoreInfo.key != initialKey_new");

                bytes memory rawOwners = keyStoreContract.rawOwnersBySlot(slot);
                assertEq(rawOwners, abi.encode(new_owners_2));
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
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash /*.toEthSignedMessageHash()*/ );
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

        bytes32 slot = keyStoreContract.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);

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
        address[] memory owners = new address[](1);
        owners[0] = _newKey;
        bytes32 newKey = keccak256(abi.encode(owners));
        uint256 nonce = keyStoreContract.nonce(slot);

        bytes32 structHash = keccak256(abi.encode(_TYPE_HASH_SOCIAL_RECOVERY, slot, nonce, newKey));
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        uint8 v;
        bytes4 s_bytes4;

        // sign [0],skip
        v = 2;
        s_bytes4 = 0;
        bytes memory _sign0 = abi.encodePacked(v, s_bytes4);

        // sign [1],  approvedHashes
        vm.prank(address(SCwallet1));
        keyStoreContract.approveHash(typedDataHash);
        v = 1;
        bytes memory _sign1 = abi.encodePacked(v);

        // sign [2~3], skip
        v = 2;
        s_bytes4 = bytes4(uint32(1));
        bytes memory _sign2 = abi.encodePacked(v, s_bytes4);

        // sign [4]
        console.log("EOAPrivatekey4:");
        console.log(EOAWallet4);
        bytes memory _sign4 = _signMsg(typedDataHash, EOAPrivatekey4);

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
        bytes memory _signTemp = _signMsg(typedDataHash, 0);
        s_bytes4 = bytes4(uint32(_signTemp.length));
        bytes memory _sign6 = abi.encodePacked(v, s_bytes4, _signTemp);

        bytes memory guardianSignature = abi.encodePacked(_sign0, _sign1, _sign2, _sign4, _sign5, _sign6);

        keyStoreContract.setKeyByGuardian(
            initialKey,
            initialGuardianHash,
            initialGuardianSafePeriod,
            abi.encode(owners),
            rawGuardian,
            guardianSignature
        );

        IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreContract.getKeyStoreInfo(slot);
        require(_keyStoreInfo.key == newKey, "keyStoreInfo.key != newKey");

        bytes memory rawOwners = keyStoreContract.rawOwnersBySlot(slot);
        assertEq(rawOwners, abi.encode(owners));
    }

    function test_updateGuardian() public {
        bytes32 initialKey;
        address _initialKey;
        uint256 _initialPrivateKey;
        (_initialKey, _initialPrivateKey) = makeAddrAndKey("initialKey");
        address[] memory owners = new address[](1);
        owners[0] = _initialKey;
        initialKey = keccak256(abi.encode(owners));

        bytes32 initialGuardianHash = keccak256("0x1");
        uint64 initialGuardianSafePeriod = 2 days;

        bytes32 slot = keyStoreContract.getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);

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
        uint256 nonce = keyStoreContract.nonce(slot);

        bytes32 structHash = keccak256(abi.encode(_TYPE_HASH_SET_GUARDIAN, slot, nonce, newGuardianHash));
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_initialPrivateKey, typedDataHash);
        bytes memory keySignature = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, keySignature);

        keyStoreContract.setGuardian(
            initialKey,
            initialGuardianHash,
            initialGuardianSafePeriod,
            newGuardianHash,
            abi.encode(owners),
            validatorSignature
        );
        IKeyStore.keyStoreInfo memory _keyStoreInfo = keyStoreContract.getKeyStoreInfo(slot);
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

            address[] memory newOwners = new address[](1);
            newOwners[0] = address(0x2);
            bytes32 initialKey_new_1 = keccak256(abi.encode(newOwners));
            nonce = keyStoreContract.nonce(slot);

            structHash = keccak256(abi.encode(_TYPE_HASH_SET_KEY, slot, nonce, initialKey_new_1));
            typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
            (v, r, s) = vm.sign(_initialPrivateKey, typedDataHash);
            keySignature = abi.encodePacked(r, s, v);
            validatorSignature = abi.encodePacked(signType, keySignature);

            keyStoreContract.setKeyByOwner(
                initialKey,
                initialGuardianHash,
                initialGuardianSafePeriod,
                abi.encode(newOwners),
                abi.encode(owners),
                validatorSignature
            );

            _keyStoreInfo = keyStoreContract.getKeyStoreInfo(slot);
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

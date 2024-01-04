// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/keystore/L1/KeyStore.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@source/modules/keystore/arbitrum/ArbMerkleRootHistory.sol";
import "@source/modules/keystore/KeyStoreMerkleProof.sol";
import "@source/modules/keystore/arbitrum/ArbKeyStoreCrossChainMerkleRootManager.sol";
import "@source/validator/KeyStoreValidator.sol";
import "@source/keystore/L1/KeyStoreStorage.sol";
import {ArbitrumInboxMock} from "./ArbitrumInboxMock.sol";

contract ArbKeystoreMerkleTree is Test {
    using ECDSA for bytes32;

    KeyStore keyStoreContract;
    KeyStoreMerkleProof keyStoreMerkleProof;
    KeyStoreValidator keyStoreValidator;
    KeyStoreStorage keyStoreStorage;

    bytes32 private constant _TYPE_HASH_SET_KEY =
        keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");

    bytes32 private constant _TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private DOMAIN_SEPARATOR;
    uint256 TEST_BLOCK_NUMBER = 100;
    address owner;
    ArbKeyStoreCrossChainMerkleRootManager l1Contract;
    ArbitrumInboxMock inboxMock;
    ArbMerkleRootHistory l2Contract;

    bytes32 slot;
    bytes32 initialKey_new_1;
    address _initialKey_new_1;
    bytes rawOwners;

    function zeros(uint256 i) public pure returns (bytes32) {
        if (i == 0) return bytes32(0x0000000000000000000000000000000000000000000000000000000000000000);
        else if (i == 1) return bytes32(0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5);
        else if (i == 2) return bytes32(0xb4c11951957c6f8f642c4af61cd6b24640fec6dc7fc607ee8206a99e92410d30);
        else if (i == 3) return bytes32(0x21ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85);
        else if (i == 4) return bytes32(0xe58769b32a1beaf1ea27375a44095a0d1fb664ce2dd358e7fcbfb78c26a19344);
        else if (i == 5) return bytes32(0x0eb01ebfc9ed27500cd4dfc979272d1f0913cc9f66540d7e8005811109e1cf2d);
        else if (i == 6) return bytes32(0x887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968);
        else if (i == 7) return bytes32(0xffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83);
        else if (i == 8) return bytes32(0x9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af);
        else if (i == 9) return bytes32(0xcefad4e508c098b9a7e1d8feb19955fb02ba9675585078710969d3440f5054e0);
        else if (i == 10) return bytes32(0xf9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5);
        else if (i == 11) return bytes32(0xf8b13a49e282f609c317a833fb8d976d11517c571d1221a265d25af778ecf892);
        else if (i == 12) return bytes32(0x3490c6ceeb450aecdc82e28293031d10c7d73bf85e57bf041a97360aa2c5d99c);
        else if (i == 13) return bytes32(0xc1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb);
        else if (i == 14) return bytes32(0x5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc);
        else if (i == 15) return bytes32(0xda7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2);
        else if (i == 16) return bytes32(0x2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f);
        else if (i == 17) return bytes32(0xe1d3b5c807b281e4683cc6d6315cf95b9ade8641defcb32372f1c126e398ef7a);
        else if (i == 18) return bytes32(0x5a2dce0a8a7f68bb74560f8f71837c2c2ebbcbf7fffb42ae1896f13f7c7479a0);
        else if (i == 19) return bytes32(0xb46a28b6f55540f89444f63de0378e3d121be09e06cc9ded1c20e65876d36aa0);
        else if (i == 20) return bytes32(0xc65e9645644786b620e2dd2ad648ddfcbf4a7e5b1a3a4ecfe7f64667a3f0b7e2);
        else if (i == 21) return bytes32(0xf4418588ed35a2458cffeb39b93d26f18d2ab13bdce6aee58e7b99359ec2dfd9);
        else if (i == 22) return bytes32(0x5a9c16dc00d6ef18b7933a6f8dc65ccb55667138776f7dea101070dc8796e377);
        else if (i == 23) return bytes32(0x4df84f40ae0c8229d0d6069e5c8f39a7c299677a09d367fc7b05e3bc380ee652);
        else if (i == 24) return bytes32(0xcdc72595f74c7b1043d0e1ffbab734648c838dfb0527d971b602bc216c9619ef);
        else if (i == 25) return bytes32(0x0abf5ac974a1ed57f4050aa510dd9c74f508277b39d7973bb2dfccc5eeb0618d);
        else if (i == 26) return bytes32(0xb8cd74046ff337f0a7bf2c8e03e10f642c1886798d71806ab1e888d9e5ee87d0);
        else if (i == 27) return bytes32(0x838c5655cb21c6cb83313b5a631175dff4963772cce9108188b34ac87c81c41e);
        else if (i == 28) return bytes32(0x662ee4dd2dd7b2bc707961b1e646c4047669dcb6584f0d8d770daf5d7e7deb2e);
        else if (i == 29) return bytes32(0x388ab20e2573d171a88108e79d820e98f26c0b84aa8b2f4aa4968dbb818ea322);
        else if (i == 30) return bytes32(0x93237c50ba75ee485f4c22adf2f741400bdf8d6a9cc7df7ecae576221665d735);
        else if (i == 31) return bytes32(0x8448818bb4ae4562849e949e17ac16e0be16688e156b5cf15e098c627c0056a9);
        else revert("Index out of bounds");
    }

    function setUp() public {
        owner = makeAddr("owner");
        vm.deal(owner, 10 ether);
        vm.startPrank(owner);
        keyStoreValidator = new KeyStoreValidator();
        keyStoreStorage = new KeyStoreStorage(owner);
        keyStoreContract = new KeyStore(keyStoreValidator, keyStoreStorage, owner);
        keyStoreStorage.setDefaultKeystoreAddress(address(keyStoreContract));
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _TYPEHASH, keccak256(bytes("KeyStore")), keccak256(bytes("1")), block.chainid, address(keyStoreContract)
            )
        );
        inboxMock = new ArbitrumInboxMock();
        l2Contract = new ArbMerkleRootHistory(address(0), owner);
        l1Contract =
            new ArbKeyStoreCrossChainMerkleRootManager(address(0), address(keyStoreStorage), address(inboxMock), owner);
        l2Contract.updateL1Target(address(l1Contract));
        l1Contract.updateL2Target(address(l2Contract));
        keyStoreMerkleProof = new KeyStoreMerkleProof(address(l2Contract));

        vm.stopPrank();
    }

    function test_MerkelProof() public {
        keystoreSetKey();
        setL2MerkelRoot();
        merkelProof();
    }

    function merkelProof() private {
        bytes32[] memory proofs = new bytes32[](keyStoreStorage.getTreeDepth());
        for (uint256 i = 0; i < keyStoreStorage.getTreeDepth(); i++) {
            proofs[i] = zeros(i);
        }
        keyStoreMerkleProof.proveKeyStoreData(
            slot, keyStoreStorage.getMerkleRoot(), initialKey_new_1, rawOwners, TEST_BLOCK_NUMBER, 0, proofs
        );
    }

    function setL2MerkelRoot() private {
        address l2Alias = AddressAliasHelper.applyL1ToL2Alias(address(l1Contract));
        vm.deal(l2Alias, 100 ether);
        vm.startPrank(l2Alias);
        l2Contract.setMerkleRoot(keyStoreStorage.getMerkleRoot());
    }

    function keystoreSetKey() private {
        bytes32 initialKeyHash;
        address _initialKey;
        uint256 _initialPrivateKey;
        (_initialKey, _initialPrivateKey) = makeAddrAndKey("initialKeyHash");
        console.log("initialKeyHash:", _initialKey);
        address[] memory owners = new address[](1);
        owners[0] = _initialKey;
        initialKeyHash = keccak256(abi.encode(owners));
        bytes32 initialGuardianHash = keccak256("0x1");
        uint64 initialGuardianSafePeriod = 2 days;

        slot = keyStoreContract.getSlot(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);
        uint256 _initialPrivateKey_new_1;
        (_initialKey_new_1, _initialPrivateKey_new_1) = makeAddrAndKey("initialKey_new_1");
        address[] memory newOwners = new address[](1);
        newOwners[0] = _initialKey_new_1;
        rawOwners = abi.encode(newOwners);
        initialKey_new_1 = keccak256(abi.encode(newOwners));
        uint256 nonce = keyStoreContract.nonce(slot);
        assertEq(nonce, 0, "nonce != 0");

        bytes32 structHash = keccak256(abi.encode(_TYPE_HASH_SET_KEY, slot, nonce, initialKey_new_1));
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_initialPrivateKey, typedDataHash);
        bytes memory keySignature = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, keySignature);

        vm.roll(TEST_BLOCK_NUMBER);

        keyStoreContract.setKeyByOwner(
            initialKeyHash,
            initialGuardianHash,
            initialGuardianSafePeriod,
            abi.encode(newOwners),
            abi.encode(owners),
            validatorSignature
        );

        bytes32 merkelRootCal;
        bytes32 node = keccak256(abi.encodePacked(slot, initialKey_new_1, TEST_BLOCK_NUMBER));
        console.logBytes32(node);

        for (uint256 i = 0; i < keyStoreStorage.getTreeDepth(); i++) {
            merkelRootCal = keccak256(abi.encodePacked(node, zeros(i)));
            node = merkelRootCal;
        }
        assertEq(merkelRootCal, keyStoreStorage.getMerkleRoot());
    }
}

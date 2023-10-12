// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/OpKnownStateRootWithHistory.sol";
import "@source/modules/keystore/KeystoreProof.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/IL1Block.sol";
import "./MockKeyStoreData.sol";
import "@source/libraries/TypeConversion.sol";

contract MockL1Block is IL1Block, MockKeyStoreData {
    function hash() external view returns (bytes32) {
        return TEST_BLOCK_HASH;
    }

    function number() external view returns (uint256) {
        return TEST_BLOCK_NUMBER;
    }
}

contract OpKeystoreTest is Test, MockKeyStoreData {
    OpKnownStateRootWithHistory knownStateRootWithHistory;
    MockL1Block mockL1Block;
    KeystoreProof keystoreProofContract;

    using TypeConversion for address;

    function setUp() public {
        mockL1Block = new MockL1Block();
        knownStateRootWithHistory = new OpKnownStateRootWithHistory(address(mockL1Block));
        keystoreProofContract = new KeystoreProof(TEST_L1_KEYSTORE,address(knownStateRootWithHistory));
    }

    function test_mockL1BlockReturn() public {
        bytes32 returnHash = mockL1Block.hash();
        assertEq(returnHash, TEST_BLOCK_HASH);
    }

    function test_insertNewStateRoot() public {
        /*
     {
    "baseFeePerGas": "0xb",
    "difficulty": "0x0",
    "extraData": "0x4e65746865726d696e64",
    "gasLimit": "0x1c9c380",
    "gasUsed": "0x73e9a5",
    "hash": "0x8696a7e4c7a24b94a476e17b472b1ca399a3945d0ff601a3bf97b27d135284e7",
    "logsBloom": "0x10280884002000480002890988000040008840000640584600010404000010100240000002002100090b08e01001800000120700000160442a108600102c640100404128cc0124890858009a8008882002430040036400020008000488240020000400eb0602a080240000808020c800840100082032010012024810000a20c00402203601042008204803204100400040011523284502080201134004228040032804084003220802009102000c2001204002008200018040500a2420204000809450021800082000000380001082280500000400000110508143006004634010108380802000014882130a0080080002001480603086414448984400600230",
    "miner": "0x4123c277dfcbdddc3585fdb10c0cee3ce9bbbcf1",
    "mixHash": "0x3edf132c4599d1e4375a9ddb7006554c962c46713a39d9161b2a205565a39b6e",
    "nonce": "0x0000000000000000",
    "number": "0x94b448",
    "parentHash": "0x09058535822e465292d1f84022621889921b9583eefdcd1e407481fe327c199c",
    "receiptsRoot": "0xdaca9199619168c44a2166a42e1faf1c0d3952b1dc4b0496d11614e304aaa3ae",
    "sha3Uncles": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
    "size": "0x295d4",
    "stateRoot": "0xbe5ce28db63ad7b63b2f23c205e35659bb7df594527d35af9d8d422b415c30e0",
    "timestamp": "0x650ee558",
    "totalDifficulty": "0xa4a470",
    "transactions": ["0xf49e8dfd7567eb15dfcea73d8e925655cd2175fc7c2539172fa4b1903ce4a953", "0xdc3a6e3dee721dbc10a0e370a97a51dd88242c7831c2ab116e4123eaf7917c34", "0xfd0f46f9129fb43e9ffab6fef997d17bb66ffab1168e6ba2741954c65b4e7e9e", "0xcc3e768f64e5ecc1b67358a7fc3a9fa5495001ca98da2a43cfaa64166b297437", "0x1fc0f2902203d47ff0a4aacc350fe3db892f6998187bc2dfcb75145a83dba57e", "0xb7667313e62eea8a66c154d9794987f3a907c955c1fd1bd6ef0559933b7df27e", "0x40807a4122a70cd423c729b42362d0c8bfab3db2b6a97447e0c48d24a2500a3c", "0x308a6a3061efbd7a75d5a970baf9de6d31d061d269cfed615efd5a573aeb6c4b", "0xee30fcdf4795d5506b98eaaedc287b2a68fc9a015ecd8e79eb0ae8e9c266a4aa", "0xf85240feff6b19f83c95452542c6397d54c5a5aa4567a0db8e764655bc93efea", "0xc82f192f1a9491bcbae3d6b321ebbe4e6bdd5067ed701b67e4f3360889371e3a", "0x0ae0667706eeb3fe80ab1cd1e4421748088a77391f693ad794f6167199e99faf", "0x6ddcad9647818f3c404b570d8b60c348ad69f9476758d511a22888bb717a1fa0", "0x01a42b16f149059e7e5308748991076ef4dfd2cff1a4517a99bc473a7415b02d", "0x1996af0236a9d5af2510d3bccd9ab8684731c7f05ff8b8979f7bf8d6c261a14d", "0x53cad02e87d979061a398f83525bec51b4f1f5adf35fe8a4170005d4b4f47121", "0xb1a157bc9c46a4879147b2e684c10b47f2ead8edf13c1d2e07fbdc12f36a6a62", "0x1c0cafbfb8011eea258dae24064257c181f0f0045c20e0e4ca94858ac1edf6cc", "0x7034cd029c7e8776551482421c63b0cac68880e3169ee5a334ff0fabda8b492a", "0x5e15284dac48de471241cdd1977cafe22d3bf83ed7de3f844c807b1f67035859", "0xea4ba750e50b10e67e751245967f79130c757ed683706b5c696e91163ea5e709", "0xeda911ef2a9d90429156b875a1dec834d43be922ed3866d3a2b6bf92858a5b50", "0x306348d0665ee4b7b6c49cd28e4e32b026f0c5ea9826ce1916b051a83d48d560", "0x7e2c74c08329e50644938ab562d0a3b3b423d74bab755c287b711655ace523d0", "0x973de96d16df6af86265cedfe97f3f3ebf58bba9f1c19892d4fb859c9cd79d34", "0x0815b7105a987c014142cd47cf54f2f07e4da560ac2659d5c8822b0004d7302d", "0x700361f2a4e16d6e82a62f88f07556851812553f72a17638408359d964d17bc1", "0xfb7cd295aa34fb83c757d5831bfcfd7b2461111d60c68b2ebeaf3e51edc2e08b", "0x3b52163a156691e4a20094507856d50f7397e17053521e067033ebffdc324620", "0xd4f0c358137978df29569c82480605f950e1a7e1f9b0fd8e3edfbe0cec8ab53b", "0x4f5f2e2e79f70242d28c976fa801af0cbcb6022acd5bf1efd0537713fbeb6a3b", "0x1faec5b811d827d18e5bb31e19cc6d2b2357f724e673edb65b772608c85ba0c4", "0x5cf5cff5ce147b32f43949b2080a3d0e20d1d6bb840e7ba45af083451bb58ec3", "0x6ef2c7a8ee9abbd1200fb488085a1f0936fc16eb301c6067e084c10f9ca6b483", "0x916c41557c63e3ec2c440853e50edcc6f29e5019265e2f6eec7429d3836a0557", "0x6938fc5ccd52addd6b8a84424e9bdbbce8ce7b4a3ba72de516be421d00668453", "0x1da096505dc7eb5020fa24447e41766440f95d07c7f87407ce0b37f2354d5c75", "0x1237ac6f15f6ba6811aa3f1f9752d966cc41fbeb36d47c154f7fba428793ed22", "0x97fa5cff709906a934fb5cb93bb1ca9b7fa7afb226880cc8d39b2cb28437212a", "0xe05ece07d11c350ab5bf364c60d4d012d6d6b6c140462fcf9f13f4918d762339", "0x3b4807c84f69585872f901658dc17c5bab338b0b5a41c1ad746caf7448e527f6", "0x72a7802e3c4ef9673db9cf9d2717f2274d1875d2f94c28d71e3d574e8f3a5ae7", "0x186f714569a67b92a717d540fb30d267bdb409c3983b511cd1203182e8f829e7", "0xd1a1ae7e16ad4c2a41e939e9a85204e780028d26ef4d492f4f8ecb2a1f8fce4b"],
    "transactionsRoot": "0x3d53df9c52bede608cd3cfe8c470bff1ba3eb3f79f73a2101132a365ca4868db",
    "withdrawals": [{
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2e568b",
    "index": "0x1097b82",
    "validatorIndex": "0x38f38"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2ee4f8",
    "index": "0x1097b83",
    "validatorIndex": "0x38f39"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2e7027",
    "index": "0x1097b84",
    "validatorIndex": "0x38f3a"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2ebb30",
    "index": "0x1097b85",
    "validatorIndex": "0x38f3b"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2edc36",
    "index": "0x1097b86",
    "validatorIndex": "0x38f3c"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2fa072",
    "index": "0x1097b87",
    "validatorIndex": "0x38f3d"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2f3e6b",
    "index": "0x1097b88",
    "validatorIndex": "0x38f3e"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2dfc3e",
    "index": "0x1097b89",
    "validatorIndex": "0x38f3f"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2f0c58",
    "index": "0x1097b8a",
    "validatorIndex": "0x38f40"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2f8164",
    "index": "0x1097b8b",
    "validatorIndex": "0x38f41"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2ef788",
    "index": "0x1097b8c",
    "validatorIndex": "0x38f42"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2efb4d",
    "index": "0x1097b8d",
    "validatorIndex": "0x38f43"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2ebb8a",
    "index": "0x1097b8e",
    "validatorIndex": "0x38f44"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2e9ef0",
    "index": "0x1097b8f",
    "validatorIndex": "0x38f45"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2ec75b",
    "index": "0x1097b90",
    "validatorIndex": "0x38f46"
    }, {
    "address": "0x8f0844fd51e31ff6bf5babe21dccf7328e19fd9f",
    "amount": "0x2fb88e",
    "index": "0x1097b91",
    "validatorIndex": "0x38f47"
    }],
    "withdrawalsRoot": "0x041dd68736473ba6278c4d37781af5484dfeb25a2d07f67d4e33730932255215"
        }
        */
        insertStateRoot();
        (bool result, BlockInfo memory blockinfo) = knownStateRootWithHistory.stateRootInfo(TEST_STATE_ROOT);
        assertEq(result, true);
        assertEq(blockinfo.blockHash, TEST_BLOCK_HASH);
    }

    function insertStateRoot() internal {
        bytes memory blockInfoParameter = BLOCK_INFO_BYTES;
        knownStateRootWithHistory.setBlockHash();
        knownStateRootWithHistory.insertNewStateRoot(TEST_BLOCK_NUMBER, blockInfoParameter);
    }
    /*
     {
    "accountProof": ["0xf90211a06c68b3ef497eca0d38404aaa92abebda35840bdc105fe180601ba231df3c307da0fa07ce024b1e736848285264dab31960dedd489ddbd2135c55cf707a14d0ae1ea02d63a9dfb00e69f27d65556739c0d778f935c980ee1a4bea2737bc401bc25090a096e9e4115747398fb8ae8c1beeaabf3ea69a6c86aab0c147f6aa934420aa8a4aa01019371c03a8b67a227c2c02c47dac7ddee9090c06a248502e15b9249b023acca0f6797c8d4f33ce2a052c04ecdb532970a401271be189365342a52a264c52e467a0928233e82fe7acc406c4bae31f3fcc0f9c57dda61c70368bdd5eb6d08528c01ea0b103558dbe9e65f593ce832fbc7b673c6525c9fb6dfe587b123a22b314c4527aa00c3f030a359f8c329fd9249e8dbe19ff23104019b597114429130ec35fc0f937a0b3b00c4952514e30c6391fa910b7e24674695f22a199cc66e23f3a878d7e415ba0b1d5e15fbbd20b715ca85bc439cf13cb94741ae6889c65f16449aa0aae83c62ca05581f96cc83196777576fae0cc3579010b449e00256942853f20072ee4033e47a0bc0831dafb08372f6070445db624e4ce3d6a10570ade6f5a87f1b5baf6b640e1a066fc24469725c37afc4e15a59ce2551d86e0978d62657c06d031010045749173a098fcf79fee71ee4d2b8c3aa8f098cbaadc295d3cad9319735f99d40a97824bd3a0667f2add04d8ea58e0d89afda407a3ec3e3d84707e9f3075928de32aa20ec37e80", "0xf90211a091a45a724544e58542988037084a76a1b195a23eba5b5c1f06d0f083ec0979e9a097b241d574ed634a9a74c1a28f7b0727c94d8d92f7421b37c0e19df925b51033a0960a0be1b76ccc031fa0dcaedc09a1e6c9d2ad24ea47abf80895f9f3b6ecdec4a040361eb320487f646ff7cb138cb858d630daf382f470da18815de4ef73338b56a04cd66496206755e4f7b97bb728f538f26991be91902147819761963ba38fbf66a03527a08ba24044631700f16d2b5ea4140a2ec46cdb6b3491e9f048c33bbd3148a0a600b8633f95a77af80ffea431e6b498ed1dda2ae350a78b04a1fc133bed3a8ba06ef38b726e11355e132b0ecfbce913630334a054215c28dae5da9e257a9902e4a07d64b3366ff933aa950c5cfe06b23243343b16dda3a21990e951e314f363364ea0e357cb027b53a8f7a3cbb191f0c0e2bb1dec969901baa0c867e465357c8fe579a0871ed22026648dca97a24b8359ea8b9d866b6e32239e83553671c79c1c647866a06ab6e70beada3497cd8b468766fa7fd7898c87b1b44db1ba952be249f7a90adba00c0684e9f40cb99747d64ba05efc9aa54d23a667bbe67cdcf577cd6045c6af20a0c360ba5c1bb4d1478565459405ba701e5892e62de26d862a8de58002191b98d7a01a5f09a245a5661317e4f7db5086fedcb7d5e6d233f8d31d92efa8fa6d990edba0181cd3dcbfff9e53661debf8a2086b7a7a973a06e005f6a18f8ae888ea1a374e80", "0xf90211a0ef1d48bca25e43cb31607b292ff9477258ddbba240cc46a557f916c3d970162da0bd54cf60c10e1cf9e66a58dbbe4a7972530b186dc9b0ccfca9da8d54accf5770a0dd7e8ead4e3d38fa3b60e42863bba6e59d2d40bea3b2a2597d5f7d93c48fee8da020a21fd424a1ee4a1df5a0ef7a8b944f286405cda339484845ad4d31f32862bca0e898281b543e6512b0935ed219e438caa593fcae2c29f890780bbe2def4a0a1ca00646590913d3d7c0812088d1068123222da7756fe6270c43a287e0fe20a30117a0d266f72db8b2b2258922566e96eeec78b334810f1961dc238b20ed72268efceea03098970dd8f43b9fcd218c11fd9faa544819fa37b444f2e6fd5b70352b4e717fa0f7a7c4a37d3ec5867663b104f236e46c8946e94b6e01c6fd27687b7fe3ccdcc9a052b096360cc013464c99eebf66f80d41f6289275db3f3c0a61f4c41f8bb13290a0083eaae68d63307586a2738e6d2b0394eb45aaf9c0870bbd590fc44a43154f38a0e55fcfcab51ab67a99760d0adf219d37e40d8a6b62e626dbec45265e2296f3fca09676f3352d9a5411a290eca3424ec7262bb7252fc7500072376a792dbe18e608a074389b9189906b3b63282fdb7315a2a45d83eab257b374a230d05935de2156afa0cd4ae181e411b23eee4b313205a56a984f84e85ede2222dc78b1cf992356476ca0a643dce7ff1ce163b672471ff4406ed2d793f95600a4caf52116796c31ed74e180", "0xf90211a024b27f61cb24b9459ecb4fe642567e62aa165d5d8263b93c7e97b2712aa4dc6da06378efceb593ac2ec3581409d3056fd449da87651b71833ec3c65df6ed2a2903a02676fd677360db5a7f9b9484716a2298694fb68cfd4c90014057c40ae4430ae0a0c59c5a85b1a05ee268fcb84982c043871ed4534d2ff461719d8767a7fad761e0a01924f4ceff0e9cc1e064f4548901861643c38dd601f02fcc021eda767b838277a0530e14ba5bc91614fb6b2ad806997e8f45d84e56ee22ffce461f47d46bbc031aa070ed445d8b0f44c5d1d5852d5de9eb4463d61a43b95574f291bf8c2ff0798a91a056f3b7d2b3bfe6842863cc9e93e7f4414e8392d32379c4f66405e85ab90c10a6a017596992661d579a3c46ec7cc6443ab9de1e787fbda69d2837496aab1d225c34a09f7496f03d3b0063b8ab2ccbc122fc17bed84bba081e0c5901bd6a3293c375cea087af975e9cefb2413c418dda55579114f7a0dc5580ed9bb44eb9ca61676da0a0a074026d17effb134253012739fb8459c0ff86f517e5307e1589a9a89e6d297004a0ea7100829b5a4bcbbe021ad71f974c020f1d7c404c453ea1b29aa64fdb7aa10aa048647d49d04d92ede0a0a766038d6a3b9ac218536d87096781cc65dc79ceb421a0f9482ce4801662256f6a199ef0b37d0bc09f5ee4143f53bc4278b75852ffcb7ba033323336b10a4c6f97ef12de00e60bd79dc2f325c57989f6c37907f554e8bc8880", "0xf90211a0ed5339e74ff6c6fdf018bcda7f0f7ccab2f996ce74d3cf7647916dafc30da7eba08517500aeba18f3dc81e408ff26ae986caf4cb6b6612814c25d5ff14b7f13397a0c57353cd2fff16a1d91e0802a511139450ed7853b37c5cbadf5f7d335594d0fda08ae0af08c914b207bfa4f6217a16bbb0618afdba367cfad833a8e03d96b9bef2a0cb0bd4d0b6caf27209e965540fe8ea11b2c0766fc769d42a10372e70db584220a0199796dcc38fadfba05bd5053c53320fbdf21adcb1f0144c816473729de2dc51a0fd4a9cdbf2f47ac2a667c92524a2879337a6dc5df23ae4bd7ec2dc552187ad25a0689e71fb7629dece3470edc81c3dcd70e77d26bfc0a4f71b95e4f53606e3b93fa0d6be6dafd1deeb175da165be249056998f5cc0edec8467155955c09c9502f84fa0c51e41b163a089e3d24b75f27d2ad80d317b0e015fd99bbf364ca75db2120c27a09aca5638cd6ae066119c7d22dee83649e67f0dd11f8e2763c229d3fdbbd06065a096be25c50167a4b24475d71535d33bc39701e273dd62d69fa2ec7c98f9f60b4aa06cf95ac5e722760ef6a3eedcb58b7195584f83d82a985b3f59868b991cb272e4a0a38524b07946d22e267a86ebfdca4b613102f987fbf763f2b7e73a126d937ebca0b300cc5614a4375a0cb56cde8b19f79734d65218f4a54789c3e0485c7655b61ea03284337fdcf55d31332d498a2f82f9075a7cad18693418b3c3a7582d9422e78280", "0xf901b1a0eda8e20a4aa74a91ffa84eeaa24f78750de341586deee94d6554196ff66ac75080a0c67ca3261ee48f08fb7a0924ab892109aac5fe18f2cec9da638f98450bde609ca032af8aaf791d62b5dd34e3c820f48969bb9610679fb2ae915c61dfe7a75da44ca09cf66822b47ad8e593614ee0fb79bd209df789609676fb907793dba01ed2cfa0a0a03ba3567c76485cfb3e3600884152d39b54da2aa6ffbba388f3b7dbe588a7ada07c10036f63c48fd47a50212d05d228a44c43ecec3e10750a770b4354bed09ba0a04e3bf9bb7591dbff93dfe4d0dd03537664a6d9a892b26b05b89c7b510235f889a0ebd74f88ce76fd0d0e146d6cdb5d906e3f18969e4fc02acf5934ca9f81d810f5a0dbdc2592ede452ad3b188f07a0fb8e6bb381587ca757f55d86dc1a3f48fbe99ba0018df8f58227467a39589dc7b9fa67a88e386e78349f14d8ecd3b7a63dd7451c80a09e0b67a5690fb693d795812a700e5e35372988bb1d550163355860effe01d48480a0f936750c9efb849d83f9f55dbc1b256771d21adf221625ef1ee6712257428ffaa0caed5009bb52fbd56871d4aad4119e81993da97b609432846ec3cab010a2300880", "0xf851808080808080808080a09bd97b637933f34507054718e9a2e7d7946c7ac75270be9313ec1abb8e50837e808080a01d4d8bff1844c765bd10f60f2a975afe6103f23b1b0bda497530eb4a9a34859f808080", "0xf8669d388447052349eafe1b500009bc7ddc9af6bce223aa4f04ba87fbce7979b846f8440180a09cccc0ba90d9282de0f512556414a39fdff073b1884f17f552c4f58dc5f6f63da0f651d18f1d492e2a3f41f587b0b273240dd8b90b6dd22419604f416c8167b39a"],
    "address": "0xdc2c9b6cf8b8dfbe46292ac4a8a354ec3c9a231b",
    "balance": "0x0",
    "codeHash": "0xf651d18f1d492e2a3f41f587b0b273240dd8b90b6dd22419604f416c8167b39a",
    "nonce": "0x1",
    "storageHash": "0x9cccc0ba90d9282de0f512556414a39fdff073b1884f17f552c4f58dc5f6f63d",
    "storageProof": [{
    "key": "0xb8e644bb648df55d79b96f2d1198b27e71c266bfc0128bf0e4b1dc73c59e3096",
    "proof": ["0xf8518080808080808080808080a0338bab1c10db5d6387b8a0c938ebc2167e0f198e3621a8127eee7e81b11b391d80a01fba58ac8ec292dd229c0d58c3c0c2e63e95eb5d1e9e446b8a24b21a40ea26c1808080", "0xf843a032a549da69802f7989f0b49cafb7a0d6bd610894e1a85a25ab8d1f7f3af2d077a1a08921e8ed690b7f8403ab4309004d5b6228691f0c3e658646aec40fafb5d53ed8"],
    "value": "0x8921e8ed690b7f8403ab4309004d5b6228691f0c3e658646aec40fafb5d53ed8"
    }]
    }
    */

    function test_proofL1Keystore() public {
        insertStateRoot();
        keystoreProofContract.proofKeystoreStorageRoot(TEST_STATE_ROOT, TEST_ACCOUNT_PROOF);
        bytes32[] memory newOwners = new bytes32[](1);
        newOwners[0] = TEST_NEW_OWNER.toBytes32();
        bytes32 ownerKeyHash = keccak256(abi.encode(newOwners));

        keystoreProofContract.proofL1Keystore(
            TEST_SLOT, TEST_STATE_ROOT, ownerKeyHash, abi.encode(newOwners), TEST_KEY_PROOF
        );

        bytes32 newSignKey = keystoreProofContract.keystoreBySlot(TEST_SLOT);
        assertEq(newSignKey, ownerKeyHash);
    }

    function testFuzz_proofL1KeystoreWrongProof(bytes memory _keyProof) public {
        insertStateRoot();
        keystoreProofContract.proofKeystoreStorageRoot(TEST_STATE_ROOT, TEST_ACCOUNT_PROOF);
        vm.expectRevert();
        bytes32[] memory newOwners = new bytes32[](1);
        newOwners[0] = TEST_NEW_OWNER.toBytes32();
        bytes32 ownerKeyHash = keccak256(abi.encode(newOwners));
        keystoreProofContract.proofL1Keystore(
            TEST_SLOT, TEST_STATE_ROOT, ownerKeyHash, abi.encode(newOwners), _keyProof
        );
    }

    // function test_proofL1KeystoreProofTwice() public {
    //     insertStateRoot();
    //     keystoreProofContract.proofKeystoreStorageRoot(TEST_STATE_ROOT, TEST_ACCOUNT_PROOF);
    //     vm.expectRevert("storage root already proved");
    //     keystoreProofContract.proofKeystoreStorageRoot(TEST_STATE_ROOT, TEST_ACCOUNT_PROOF);
    // }

    // function test_proofL1KeystoreWitoutStorageRoot() public {
    //     insertStateRoot();
    //     vm.expectRevert("storage root not set");
    //     bytes32[] memory newOwners = new bytes32[](1);
    //     newOwners[0] = TEST_NEW_OWNER.toBytes32();
    //     bytes32 ownerKeyHash = keccak256(abi.encode(newOwners));
    //     keystoreProofContract.proofL1Keystore(
    //         TEST_SLOT, TEST_STATE_ROOT, ownerKeyHash, abi.encode(newOwners), TEST_KEY_PROOF
    //     );
    // }

    function testFuzz_proofL1KeystoreUnknownStorageRoot(bytes32 _stateRoots) public {
        insertStateRoot();
        vm.expectRevert();
        console.logBytes32(_stateRoots);
        bytes32[] memory newOwners = new bytes32[](1);
        newOwners[0] = TEST_NEW_OWNER.toBytes32();
        bytes32 ownerKeyHash = keccak256(abi.encode(newOwners));
        keystoreProofContract.proofL1Keystore(
            TEST_SLOT, _stateRoots, ownerKeyHash, abi.encode(newOwners), TEST_KEY_PROOF
        );
    }
}

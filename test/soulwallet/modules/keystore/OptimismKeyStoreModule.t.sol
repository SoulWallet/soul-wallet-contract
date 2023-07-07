// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/modules/OptimismKeyStoreProofModule/KnownStateRootWithHistory.sol";
import "@source/modules/OptimismKeyStoreProofModule/KeystoreProof.sol";
import "@source/modules/OptimismKeyStoreProofModule/IL1Block.sol";
import "@source/modules/OptimismKeyStoreProofModule/OptimismKeyStoreModule.sol";
import "../../base/SoulWalletInstence.sol";

contract MockL1Block is IL1Block {
    function hash() external returns (bytes32) {
        return hex"807bd796a85a0fede42edf1561832c5ee0a0d1e8819406d9bbcb64c0ccb343c9";
    }
}

contract OptimismKeyStoreModuleTest is Test {
    KnownStateRootWithHistory knownStateRootWithHistory;
    MockL1Block mockL1Block;
    KeystoreProof keystoreProofContract;
    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    OptimismKeyStoreModule optimismKeyStoreModule;

    address public walletOwner;
    address public newOwner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public walletOwnerPrivateKey;

    function setUp() public {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");
        mockL1Block = new MockL1Block();
        knownStateRootWithHistory = new KnownStateRootWithHistory(address(mockL1Block));
        keystoreProofContract =
            new KeystoreProof(0xACB5b53F9F193b99bcd8EF8544ddF4c398DE24a3,address(knownStateRootWithHistory));
        optimismKeyStoreModule = new OptimismKeyStoreModule(address(keystoreProofContract));
    }

    function deployWallet() private {
        bytes[] memory modules = new bytes[](1);
        // mock encode slot postion in l1
        modules[0] = abi.encodePacked(optimismKeyStoreModule, abi.encode(0x5));
        bytes32 salt = bytes32(0);
        bytes[] memory plugins = new bytes[](0);
        soulWalletInstence = new SoulWalletInstence(address(0), walletOwner,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();
    }

    function test_setUp() public {
        deployWallet();
        (address[] memory _modules,) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
        assertEq(_modules[0], address(optimismKeyStoreModule), "module address error");
        assertEq(soulWallet.isOwner(walletOwner), true);
    }

    function proofL1KeyStore() internal {
        bytes memory blockInfoParameter =
            hex"f90238a0939dcdd4ae703cb363c372a248d96e1a8fc06ef9825ea4051d762532ffddd33ea01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d493479494750381be1aba0504c666ee1db118f68f0780d4a0e5f3f63ed5cf0a5c3e15efe0df467a35fde185f16d75a500430f805adea94345a0ac1fae9e5a88b2ff9bd1c7c9985f4fae7490ac79d91d8e5356cb95c212c29422a01216d866ad3647bd72a9e6ad8cd8dfff9bc885630c04376afb0c735aed97ffd3b901000d2502c20273d10d3c72449ba61761c43c39f7503b44186741870c1ab891343f40b214e10b652b4200180568959d84dcfb6b0812c802aa4003311e04926c2a600a43c6aa4e7760926a084b3b10a882a4c5598272f76638218692c0a682e42ac904e4b1d992e40ac124c681ed885008281858c8e52cea25c0113542f45712f06e0b0221f4d4e4712b62400d41f0200436980dce812b0513ae3507a3c0154240460388181c76c022514a00a7a669334b6306020341e1552184819119e66221826299b458e241b4ac0ec09a2681ad13460d2e4a50a01280293482c16ea20cceeb621c101225a2e07311b932035c60505020029190604b9223430a7cb148280106b180838d7c6e8401c9c38083ee71f28464a03d6099d883010b04846765746888676f312e32302e32856c696e7578a010395f604f9dda9b4b54dc3a36d25d10fa5d236d3c814f3f076e36bbaa481fd9880000000000000000820306a0df2da8ee290d7ae0d2a5fc1cef38725643955cbe4595ea130330f6dbe22074c3";
        knownStateRootWithHistory.insertNewStateRoot(blockInfoParameter);
        keystoreProofContract.proofKeystoreStorageRoot(
            hex"e5f3f63ed5cf0a5c3e15efe0df467a35fde185f16d75a500430f805adea94345",
            hex"f90c61f90211a01f637d5f303796398f597e281b996d2605cc2b4fa7f0d92c513643130b2ff20da089a7a2558bfc43b22bf94c0489ea272161336304ee073b1eb3cc5d67a43be85aa007c7db44ded4af05e226fde1dd27ebb06036d44578ed72e2f63185fc574824e0a00ede8e8721328c47cbb3a2e74c36f549dd14c09a0233886f1d4e1fc18f401e8ea00cbb12d68dd4b740ea9e800d1199f00a35d692db0ab8e9ed2fb1a47e0f588072a0a58dfae8a87a6c76372b41127b3e2ce6e9ddfd4d1c552aaf9a4454807a882624a00f672733f3345a31bbe321141622c049b0fb179f9ef40c342df8d24e4912cccaa019da89a275da8046764a10939a41273e2061a5b105497511873777caeaa34e1fa092c0b95c8ab716250731ae3392d37199eba20f93c65222f157bdda1512c3e7d6a0b581996823252424ded4070ae4dbeeab5feca24d35ee5a24923ee2d6434aab4fa0c8b33d11e6470163b7bc2744773464988b8b89a5d61d5cf3327d83b513f11023a0914a740d0c687ad4c9cb5e95533ec6c14a9fd4e2ade04109ea6061a5bb726f94a0a7f0abee3b7f32fdca21e33b66529a8104bbc2bf7e5e46ec222a9097fca70d70a07506f196de8b534ebea66c9a6bdebc076a2c2b8018a77e94b77bad166a114d0ba00b33350375aa142e4f252a47713eb1f2f5ba6de5b90d3ea0de5b064fa2524e61a09596f01244c21780adf59571a369b3dbffc23d8dbad7528ebaf3736332f70c8c80f90211a0b8ac725b8d0be0004a2544eaa1bf2d7f1037254050c9998bf64eee1648e1d408a09fc0959e40bcf9c5a7f59f4c7ef1cabfe7d43cab85ef9560c42e6be2dd4af485a0776349a9b8c554095d740b4882f252f020404aedf775079f11806b675defbd43a0e5248cfb4342291f153b1bb96b5fd3cb13701813fdd3b28658e75fdb4a4c2691a0dd15608767a6e25eb5ef21d326f636cc086656fc30c2705e93bff10203af3400a003f139478e75af0a3a4db50342fc25796740f0b187b94b78afa86e9dea806d61a045de899863a9c9405215907ee020de8c2c3668edf3cfcf4a868abf94b4084241a06b8bf68e0495279360e25598a4b3bd7450578f4cdbbbb618f6ac4cbbc73d0d89a0dafee061e758274bee84f8fa6df933ace88c96618837543ccd752bda16e1b11ca008cb5fd03f8dc430e61ae9228648fbed1a2fcfe81a2341b5a842a1203b912854a0b8d777d015f0b66b25fb3bed354fccf64541108828b7f8dce7cb6f7a2c7b15e8a0d581f43db340358b59476ff853c5a627471c4df2f2baf1fd450b8f9aca650622a0f1bf0b017201301757f432e7559f9231576b38c007d8be227d3ceaff4e9054fba0d3dfd89378794d18044a4e54c96ff60e99308bffdbf29b424d5ab6ec7933566fa0e3234869f8a243407b7cf5280cdb4cdf60866e26f324395c0ba21351d931b4a0a0bab778f165b8c8806d8058abbba694102db5e5898dcf65448e471fc5daf7632680f90211a0deb9561c8202eeb1088becdc19f2b87cfe94a10497b4fb58c9a1e38ae90a915ca0a466ac165a3e0b1f50b6454c99c10cc5c41503d4f0c3cf871ee5d6b88d3393f1a057e8fb3a3f532083b1ad47c961473608292768bda30208aab18aac186dd7726fa07b412ee1626842fb754ccc72587ea7a058db91da478d1abafc40209cd8ce7df1a055ad83292693cce77321ff7df1807ffac7dea4f1cd1e7501c71c29b1c736a5d9a0b477344d447ee0014bf9021593a4f45ff5beba1b8b78a08a42f2418485038925a072c645d4a2fd1d362b0b5e0489d83ea8cdb8485d35625caf65f1d3a6076bf8c5a02ffda44f5572fc0d077096bf56d754a94896eb2c89fbc56c2a7a3897abbbb2b2a0aebb9af57494d972874f9a72beb9f079765a43ec16baf122d8c1265f78fcc2c6a03095b7311c4a8c6ab593d03a39fe5b41db884a51369822167b8b618f98dbc0eea08b355e0cce07425f2f02ae40385e2b21e0e3da32cb7b0a6f4aba06690a961166a0939d02dfc357824044d3f0cafcb781f46ec45da4b25836f09b682f9536d120efa0dbeda80bd4f404c73d14fba54915f5328fb51ac4e4536a29c586e1cafe214c21a0152540adefc403d3032bdeb54cc74930b29f687945115e2d4cd9494f69ef6844a069a290528dde4285fb8e628ffccbf1fb69b82f5cc5198128b4dc1eabbc765a4ba0e46855e23be7d591137302942bf4637e44a77844294f9a8caae81f13826a689580f90211a0d5dba92148fb213294b687fefa76f14277ff871a2c6c584d9a0b591a6414de67a012deccc7b0f50a019cb85858f3261d85c4e8b5458712e74f47b65b656d24cacaa07f1791abfc2c5240b5c2ef8667df3d1469a0cdf07131a7df024197f7c9d074eaa0f088f24f3a92c4c2ab2e4fc474c1b92259d1e02a98078b05e57f4a3e80e9fb59a098d73378302969ee6f255f5db38bfa44dc9b0df7674597345f322c24237851efa0460401be8388ad1a8e02d09a662b7c6274c66c1bcdcd2317b2c99e49d283a34ea0f34b5119985bfbdd50feb8c5ccd3bef1f9cceca022bdcea082d541b340a8347ba0de3e68b7e3e64df5b06ca52a615d6c9f00322344f7557bc3c95050b792b86272a06f2c2a0d8e8d27cbac3f02aba212eeb79f80a6868a58c96ba7ae8d0446cce694a049d95d4d82b7defb3d193052598ddbbac648235e383dcbe535a2fc493cd3e39ba0df07b16cbd8a44ea53e8e75d1eebb6ab67fc0e5f2447d8e5768fabf68f02bbc8a038d19ec63584588b2f93cd80c161d1827cf054a2f9cef63d1470654b9c681fcfa0907eaaaa3693594e95941637e9f4c3f83ce02a14cf8fc2cb02418dbdbc043839a0171bd79602ff7c303083d1e3774ed0c77309afdb5be6f12396fce392ba52312da0cb54daa5193ee3efc0e2afbe0a1b13e5418a570220dff9063b322cc07785100ca0a7daeeef3b2e9b542906cd982a7860c1eb8652b776deb2d7db954031a595c06b80f90211a010a55b10828dc87c870bf7ffc1f17e490bfedef06b447f44d5cb05f987a55192a0998e2744898f5abc5c55a7670eac383e750761ea7873ab929e89882767f9b29fa0e7430cf5391d79c45edcbf4a9f267b95a90b764245987dbfb940f386f1c97eaaa08abfb3ebb057cb9f26960a5ce0ce3b016f85f4b54020928de70f6b0e8efbc6f8a0d2013763bdd3e8138663674d44aa6a01c43a1673590f8f5583354019d047c33fa0bf8c3a2443fa424fafd3041c191b23cb9df88ee80d2a6b2eac62414252aec47fa099081275005ca12f20335b1bea768f1da0625f9c0d6128839169c9036da1c3b2a0b19fd624a64340cdf3134fa715926ec4c9a7bde61e5b7d5ba976339c5d11c6f8a0555cb85d214d24f3f017771c2eea86d3c1e2850cba545eff8f7cf068a6fbe5c5a0deffdb2431042577063cd124835ff348ae4d5d1dbce3cc0da0840cd6bad593d0a074b243b4cbac7dfaf229ec5ed8f960d2c8d8ea74ae2d23853c527e0f284fe6b5a023f1b3c16d7540223ae68038b414a7a8dac63c44d565dbf5b6103a30c2e037a8a0d5fd5c6a69fd42bf9b8393e2a003ba5e09caefccfa5f3afc437baf6276d831f7a0f0b24f2057ef2fda74acbd3eeb37463eb41a59d95b7efdb04071e990af593b7ba0d8a5a745362753801c7d31d8c70d00abf5c298044066a91b164578c20bfce227a03224b86f2f7fcdae70c0bad45c1b743d37f344bc2e62922723624b562765425d80f90191a08190beca2fa9132ec0e66a0941160b478e8a5d709c445dd8e60a2714e3bf7454a0bb28b0642a3f59da9b458f985a3123f44e11bb66c4a17048cc636b4c381ae45680a0c70b7be01895bc02247cd4c32faa6f395a33437340fbc5281a386bc17f62da0ca08ca208e9e2e0046decaf23092891d897a2c481ecb7baf7d4baa8b79e9463d072a085170ab1325f84f6da3902311f5367b1d7cdc456e2faff883e5f5a77cc06801ea01f7446d0aa0c9105a7d0895b32999e1ca262f4323bfe595fc8c47941159dbb24a09385ff36324631c8ae1eb4d3e40b1bf21e74e4dc8b9a8e914f7312371780d024a05cb9ae2531f250141a58cece3694ab04da3dfa9fe10364b3e955ab0f8d7df27fa0ee414ba7ce4ad05131e96e154a5163328bc0da65a019553d828ead34e5be22b080a01a355ce465305852dad4e8a78749e33fb47eb53723552232d6ff7aba74a1d870a0cb6e0c992b267823039107b3de67893235f7452d75ecc6504ae0d85722fdc0be80a039978eb3ab27721875bc507611aa50434fff2f2f16b27943685f08a40cc9e4628080f8679e205e7c0ddb68e10d8432e66d6351acc6baf80161e6088af210fee0815cd6b846f8440180a0c451881707b89b35f5b838c07894b6f5eca4a5415941625e5916e3c06870207ca0227a99a2297d05d1bea5114772e59611991c4aa2f1ebb0d23330b02173426c23"
        );
        keystoreProofContract.proofL1Keystore(
            hex"0000000000000000000000000000000000000000000000000000000000000005",
            hex"e5f3f63ed5cf0a5c3e15efe0df467a35fde185f16d75a500430f805adea94345",
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            hex"f8ebf8b1a0baefd740d886a75a00998f859f788b55e7d7db1843b5ed550e8135c3a45e0c1d808080a0df1326d6c2c3e493d1bfff3543916a258519bb6365d62334d217e8a0efd0a19e808080a0670f9fb6e73ff93d538f7cc92c723f51d7df32d94d16848b51289260eb21292c8080a0c2c2ff8fbb388b92799847764ccadb622f5e8464f13c8aec173f8ee8ebda8e2fa0849db0f7b77fc361400b0f26d1e39ebc8f1a421829839c9bafa80be0a14feba680808080f7a0336b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db09594f39fd6e51aad88f6f4ce6ab8827279cfffb92266"
        );
    }

    function test_setUpWithKeyStoreValueExist() public {
        proofL1KeyStore();
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), false);
        assertEq(soulWallet.isOwner(newOwner), true);
    }

    function test_keyStoreSyncWithModule() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), true);
        assertEq(soulWallet.isOwner(newOwner), false);
        proofL1KeyStore();
        vm.startPrank(walletOwner);
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        assertEq(soulWallet.isOwner(walletOwner), false);
        assertEq(soulWallet.isOwner(newOwner), true);
        vm.stopPrank();
    }

    function test_keyStoreSyncWithModuleSyncAgain() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), true);
        assertEq(soulWallet.isOwner(newOwner), false);
        proofL1KeyStore();
        vm.startPrank(walletOwner);
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        assertEq(soulWallet.isOwner(walletOwner), false);
        assertEq(soulWallet.isOwner(newOwner), true);
        vm.expectRevert("keystore already synced");
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        vm.stopPrank();
    }

    function test_keyStoreSyncWithoutKeyStoreInfo() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), true);
        assertEq(soulWallet.isOwner(newOwner), false);
        vm.startPrank(walletOwner);
        vm.expectRevert("keystore proof not sync");
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        vm.stopPrank();
    }
}

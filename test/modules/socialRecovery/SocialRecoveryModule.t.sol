pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/modules/socialRecovery/SocialRecoveryModule.sol";
import "../../soulwallet/base/SoulWalletInstence.sol";

contract SocialRecoveryModuleTest is Test {
    using TypeConversion for address;

    struct GuardianData {
        address[] guardians;
        uint256 threshold;
        uint256 salt;
    }

    SocialRecoveryModule socialRecoveryModule;
    SoulWalletInstence public soulWalletInstence;
    ISoulWallet soulWallet;
    GuardianData guarianData;
    address _owner;
    uint256 _ownerPrivateKey;
    address _newOwner;
    uint256 _newOwnerPrivateKey;
    address _guardian;
    uint256 _guardianPrivateKey;

    uint256 delayTime;
    bytes32 private constant _TYPE_HASH_SOCIAL_RECOVERY =
        keccak256("SocialRecovery(address wallet,uint256 nonce, bytes32[] newOwner)");
    bytes32 private constant _TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private DOMAIN_SEPARATOR;

    function setUp() public {
        (_owner, _ownerPrivateKey) = makeAddrAndKey("owner");
        (_newOwner, _newOwnerPrivateKey) = makeAddrAndKey("newOwner");
        (_guardian, _guardianPrivateKey) = makeAddrAndKey("guardian");
        socialRecoveryModule = new SocialRecoveryModule();
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _TYPEHASH,
                keccak256(bytes("SocialRecovery")),
                keccak256(bytes("1")),
                block.chainid,
                address(socialRecoveryModule)
            )
        );
    }

    function deployWallet() private {
        bytes[] memory modules = new bytes[](1);
        bytes[] memory hooks = new bytes[](0);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = address(_owner).toBytes32();

        address[] memory guardians = new address[](1);
        guardians[0] = _guardian;
        guarianData = GuardianData(guardians, 1, 0);

        bytes32 guardianHash = keccak256(abi.encode(guarianData.guardians, guarianData.threshold, guarianData.salt));
        console.log("deployWallet guardianHash");
        console.logBytes32(guardianHash);
        delayTime = 1 days;

        bytes memory socialRecoveryInitData = abi.encode(guardianHash, delayTime);
        modules[0] = abi.encodePacked(socialRecoveryModule, socialRecoveryInitData);
        bytes32 salt = bytes32(0);
        soulWalletInstence = new SoulWalletInstence(address(0), owners, modules, hooks, salt);
        soulWallet = soulWalletInstence.soulWallet();
        assertEq(soulWallet.isOwner(_owner.toBytes32()), true);
        assertEq(soulWallet.isOwner(_newOwner.toBytes32()), false);
        assertEq(soulWallet.isInstalledModule(address(socialRecoveryModule)), true);
    }

    function test_deployWalletWithSocialRecoveryModule() public {
        deployWallet();
    }

    function test_scheduleSocialReocery() public {
        scheduleSocialReocery();
    }

    function scheduleSocialReocery()
        private
        returns (
            address wallet,
            bytes memory newRawOwners,
            bytes memory rawGuardian,
            bytes memory guardianSignature,
            bytes32 recoveryId
        )
    {
        deployWallet();
        uint256 nonce = socialRecoveryModule.walletNonce(address(soulWallet));
        bytes32[] memory newOwners = new bytes32[](1);
        newOwners[0] = address(_newOwner).toBytes32();

        bytes32 structHash = keccak256(
            abi.encode(_TYPE_HASH_SOCIAL_RECOVERY, address(soulWallet), nonce, keccak256(abi.encodePacked(newOwners)))
        );

        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_guardianPrivateKey, typedDataHash);
        bytes memory keySignature = abi.encodePacked(v, s, r);
        bytes memory guardianSig = abi.encodePacked(keySignature);
        console.log("guardianData");
        console.logBytes(abi.encode(guarianData));
        console.log("guardianData2");
        console.logBytes(abi.encode(guarianData.guardians, guarianData.threshold, guarianData.salt));

        recoveryId = socialRecoveryModule.scheduleReocvery(
            address(soulWallet),
            abi.encode(newOwners),
            abi.encode(guarianData.guardians, guarianData.threshold, guarianData.salt),
            guardianSig
        );
        return (
            address(soulWallet),
            abi.encode(newOwners),
            abi.encode(guarianData.guardians, guarianData.threshold, guarianData.salt),
            guardianSig,
            recoveryId
        );
    }

    function test_executeSocialRecovery() public {
        (address wallet, bytes memory newRawOwners, bytes memory rawGuardian, bytes memory guardianSignature,) =
            scheduleSocialReocery();
        vm.warp(block.timestamp + delayTime);
        socialRecoveryModule.executeReocvery(wallet, newRawOwners, rawGuardian, guardianSignature);
        assertEq(soulWallet.isOwner(_newOwner.toBytes32()), true);
        assertEq(soulWallet.isOwner(_owner.toBytes32()), false);
    }

    function test_executeSocialRecoveryNotInReadyState() public {
        (address wallet, bytes memory newRawOwners, bytes memory rawGuardian, bytes memory guardianSignature,) =
            scheduleSocialReocery();
        vm.expectRevert();
        socialRecoveryModule.executeReocvery(wallet, newRawOwners, rawGuardian, guardianSignature);
        assertEq(soulWallet.isOwner(_newOwner.toBytes32()), false);
        assertEq(soulWallet.isOwner(_owner.toBytes32()), true);
    }
}

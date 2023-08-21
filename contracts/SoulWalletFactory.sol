// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "./SoulWalletProxy.sol";
import "./SoulWallet.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author  soulwallet team.
 * @title   A factory contract to create soul wallet.
 * @dev     it is called by the entrypoint which call the "initCode" factory to create and return the sender wallet address.
 * @notice  .
 */

contract SoulWalletFactory is Ownable {
    uint256 private immutable _WALLETIMPL;
    IEntryPoint public immutable entryPoint;
    string public constant VERSION = "0.0.1";

    event SoulWalletCreation(address proxy);

    constructor(address _walletImpl, address _entryPoint, address _owner) {
        require(_walletImpl != address(0));
        _WALLETIMPL = uint256(uint160(_walletImpl));
        require(_entryPoint != address(0));
        entryPoint = IEntryPoint(_entryPoint);
        transferOwnership(_owner);
    }

    function walletImpl() external view returns (address) {
        return address(uint160(_WALLETIMPL));
    }

    function _calcSalt(bytes memory _initializer, bytes32 _salt) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(keccak256(_initializer), _salt));
    }

    /**
     * @notice  deploy the soul wallet contract using proxy and returns the address of the proxy. should be called by entrypoint with useropeartoin.initcode > 0
     */
    function createWallet(bytes memory _initializer, bytes32 _salt) external returns (address proxy) {
        bytes memory deploymentData = abi.encodePacked(type(SoulWalletProxy).creationCode, _WALLETIMPL);
        bytes32 salt = _calcSalt(_initializer, _salt);
        assembly ("memory-safe") {
            proxy := create2(0x0, add(deploymentData, 0x20), mload(deploymentData), salt)
        }
        if (proxy == address(0)) {
            revert();
        }
        assembly ("memory-safe") {
            let succ := call(gas(), proxy, 0, add(_initializer, 0x20), mload(_initializer), 0, 0)
            if eq(succ, 0) { revert(0, 0) }
        }
        emit SoulWalletCreation(proxy);
    }

    /**
     * @notice  returns the proxy creationCode external method.
     * @dev     used by soulwalletlib to calcudate the soul wallet address.
     * @return  bytes  .
     */
    function proxyCode() external pure returns (bytes memory) {
        return _proxyCode();
    }

    /**
     * @notice  returns the proxy creationCode private method.
     * @dev     .
     * @return  bytes  .
     */
    function _proxyCode() private pure returns (bytes memory) {
        return type(SoulWalletProxy).creationCode;
    }

    /**
     * @notice  return the counterfactual address of soul wallet as it would be return by createWallet()
     */
    function getWalletAddress(bytes memory _initializer, bytes32 _salt) external view returns (address proxy) {
        bytes memory deploymentData = abi.encodePacked(type(SoulWalletProxy).creationCode, _WALLETIMPL);
        bytes32 salt = _calcSalt(_initializer, _salt);
        proxy = Create2.computeAddress(salt, keccak256(deploymentData));
    }

    function deposit() public payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function withdrawTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
        entryPoint.withdrawTo(withdrawAddress, amount);
    }

    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    function unlockStake() external onlyOwner {
        entryPoint.unlockStake();
    }

    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        entryPoint.withdrawStake(withdrawAddress);
    }
}

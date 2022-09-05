pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "./SmartWallet.sol";


/**
 * minimal wallet.
 *  this is sample minimal wallet.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract SmartWalletV2Mock is SmartWallet {
    uint256[4] private publicKey;
    constructor() SmartWallet() {

    }
    event PublicKeyChanged(uint256[4] oldPublicKey, uint256[4] newPublicKey);

    function setBlsPublicKey(uint256[4] memory newPublicKey) external onlyOwner {
        emit PublicKeyChanged(publicKey, newPublicKey);
        publicKey = newPublicKey;
    }

    function getBlsPublicKey() external view returns (uint256[4] memory) {
        return publicKey;
    }

    function getVersion() override external view virtual returns(uint){
        return 2;
    }
   
}

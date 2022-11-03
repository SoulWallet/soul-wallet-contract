# Anonymous guardian with create2

## Why anonymous guardian

The user who has a lot of money and doesn't want their friends to know how much they have unless the emergency actually comes up. in this case, the user doesn't want to store the guardian list on the chain. because others can easily see the list which results in poor privacy.

## Related background

[Create deterministic contract address using create2](https://eips.ethereum.org/EIPS/eip-1014)

[Erc1271 Standard Signature Validation Method for Contracts](https://eips.ethereum.org/EIPS/eip-1271)

[Gnosis safe multi sig wallet](https://github.com/safe-global/safe-contracts/blob/c36bcab46578a442862d043e12a83fec41143dec/contracts/GnosisSafe.sol#L240)

## Goal achievement

- smart contract guardain do not have publicly known.
- guardain don't know each other guadain identities.
- only reveal guardain when recovery needed.


## Implementation

### Add guardian

* the guardain moduel is a separate smart contract, the main functionality is a multi sig wallet which store the list of guardains for social recovery of the erc4337 wallet.
* this contract expose ```function isValidSignature(bytes calldata _data, bytes calldata _signature) ```**(erc1271 interface)** to the public for signature verfication.
* inside the **isValidSignature** function, it accept signature which comes from guardains and perform the verification with threshold, for example, 3/5 or 4/7 multi sig verification. [gnosis code reference](https://github.com/safe-global/safe-contracts/blob/c36bcab46578a442862d043e12a83fec41143dec/contracts/GnosisSafe.sol#L240).



![](https://hackmd.io/_uploads/HyrunBANo.png)


### Using guardian for social recovery


* When users want to replace the signing key using social recovery, the user needs to provide the guardian's list to the security center, the security center will generate the init code with the user-provided guardian list and compute the create2 address. the security center will give back the calculated address for the user to verify if the address equal to the guardian address setting on the erc4337 smart contract wallet.
* If users succeed to regenerate the guardian address for the erc4337 wallet, the user will ask the security center to deploy the contract for him.
* Users will compose a replace sign key user operation, and ask guardians to sign it.
* Once the user collects enough signatures from guardians, the user will send this user operation on the chain.
* The erc4337 smart contract checks if the user operation is a replacement key function with guardians. for the signature verification, it will call the guardian address with  ```function isValidSignature(bytes calldata _data, bytes calldata _signature) ```  
* Inside the ```isValidSignature``` in the guardian smart contract, it will perform the multi-sig check for the guardians.


![](https://hackmd.io/_uploads/S1OviLC4o.png)


#### Sequence diagram



![](https://hackmd.io/_uploads/BknPSI0Ej.png)


### Modify guardian

* Because the guardian address is set on the erc4337 smart contract wallet based on the guardian list and guardian smart contract bytecode. if the user wants to add/remove a guardian, the guardian address needs to be recalculated on-chain which means the user has to provide the full guardian list and recompute the new guardian address.
* the guardian list must sort descending in order to generate a deterministic guardian contract address.
* the user has to remember the guardian list. **should we store the guardian list somewhere or every time we ask users to provide the guardian list if they want to update the guardian?**

 
![](https://hackmd.io/_uploads/SJFLEwJro.png)

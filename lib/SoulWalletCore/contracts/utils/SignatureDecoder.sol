// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SignatureDecoder {
    /*

        Signature:
            [0:20]: `validator address`
            [20:24]: n = `validator signature length`, bytes4 max to 16777215 bytes
            [24:24+n]: `validator signature`
            [24+n:]: `hook signature` [optional]

        `hook signature`:
            [0:20]: `first hook address`
            [20:24]: n1 = `first hook signature length`, bytes4 max to 16777215 bytes
            [24:24+n1]: `first hook signature`

            `[optional]`
            [24+n1:24+n1+20]: `second hook signature` 
            [24+n1+20:24+n1+24]: n2 = `second hook signature length`, bytes4 max to 16777215 bytes
            [24+n1+24:24+n1+24+n2]: `second hook signature`

            ...
     */
    function signatureSplit(bytes calldata self)
        internal
        pure
        returns (address validator, bytes calldata validatorSignature, bytes calldata hookSignature)
    {
        /*
            Equivalent code：
                validator = address(bytes20(self[0:20]));
                uint32 validatorSignatureLength = uint32(bytes4(self[20:24]));
                uint256 hookSignatureStartAt;
                unchecked {
                    hookSignatureStartAt = 24 + validatorSignatureLength;
                }
                validatorSignature = self[24:hookSignatureStartAt];
                hookSignature = self[hookSignatureStartAt:];
         */
        assembly ("memory-safe") {
            if lt(self.length, 24) { revert(0, 0) }

            {
                // validator
                let _validator := calldataload(self.offset)
                // _validator >> ((32-20)*8)
                validator := shr(96, _validator)
            }
            {
                // validatorSignature
                let _validatorSignatureLength := calldataload(add(20, self.offset))
                // _validatorSignatureLength >> ((32-4)*8)
                let validatorSignatureLength := shr(224, _validatorSignatureLength)

                if gt(add(24, validatorSignatureLength), self.length) { revert(0, 0) }
                validatorSignature.offset := add(24, self.offset)
                validatorSignature.length := validatorSignatureLength
            }
            {
                // hookSignature
                hookSignature.offset := add(validatorSignature.offset, validatorSignature.length)
                hookSignature.length := sub(sub(self.length, validatorSignature.length), 24)
            }
        }
    }
}

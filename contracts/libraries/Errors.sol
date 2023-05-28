// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library Errors {
    // require from Entrypoint or owner
    error RequireFromEntryPointOrOwner();

    // require from Entrypoint or owner or self
    error RequireFromEntryPointOrOwnerOrSelf();

    // can not call self
    error CanNotCallSelf();

    // wrong array lengths
    error WrongArrayLength();

    // fallbackContract is zero address
    error FallbackContractIsZeroAddress();

}

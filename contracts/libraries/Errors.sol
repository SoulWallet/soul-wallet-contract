// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library Errors {
    // require from Entrypoint
    error RequireFromEntryPoint();

    // require from Entrypoint or self
    error RequireFromEntryPointOrSelf();

    // can not call self
    error CanNotCallSelf();

    // wrong array lengths
    error WrongArrayLength();

    // fallbackContract is zero address
    error FallbackContractIsZeroAddress();

}

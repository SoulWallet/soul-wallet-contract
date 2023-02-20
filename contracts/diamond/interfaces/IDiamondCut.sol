// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDiamondCut {
    enum FacetCutAction {
        ADD,
        REPLACE,
        REMOVE
    }

    event DiamondCut(FacetCut[] facetCuts, address target, bytes data);

    error DiamondCut__InvalidInitializationParameters();
    error DiamondCut__RemoveTargetNotZeroAddress();
    error DiamondCut__ReplaceTargetIsIdentical();
    error DiamondCut__SelectorAlreadyAdded();
    error DiamondCut__SelectorIsImmutable();
    error DiamondCut__SelectorNotFound();
    error DiamondCut__SelectorNotSpecified();
    error DiamondCut__TargetHasNoCode();

    struct FacetCut {
        address target;
        FacetCutAction action;
        bytes4[] selectors;
    }
}

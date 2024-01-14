// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../base/MerkleRootHistoryBase.sol";
import "./IScrollMessenger.sol";

contract ScrollMerkleRootHistory is MerkleRootHistoryBase {
    address public immutable L2_SCROLL_MESSENGER;

    constructor(address _l1Target, address _owner, address _l2_scroll_messenger)
        MerkleRootHistoryBase(_l1Target, _owner)
    {
        L2_SCROLL_MESSENGER = _l2_scroll_messenger;
    }

    function isValidL1Sender() internal view override returns (bool) {
        return msg.sender == address(L2_SCROLL_MESSENGER)
            && IScrollMessenger(L2_SCROLL_MESSENGER).xDomainMessageSender() == l1Target;
    }
}

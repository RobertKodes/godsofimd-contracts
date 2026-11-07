// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Buyer side of the IMD Intake v2 contract (0xa43e6f75ee006411f79ac1c84120606c2330de82 on every chain).
/// The intake pulls `amount` of `asset` from msg.sender, so approve it first.
// Action ids are strings right-padded to bytes32, e.g. "oracle.request@oracle-1", "oracle.group@group-1".
interface IIntake {
    struct Callback {
        address target;
        bytes4 selector;
    }

    function requestWithFailure(
        bytes32 action,
        bytes calldata body,
        Callback calldata callback,
        bytes4 onFailure,
        address asset,
        uint256 amount
    ) external returns (bytes32 requestId);
}

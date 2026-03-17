// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBondedTypes} from "./IBondedTypes.sol";

interface ISpendingPolicy is IBondedTypes {
    event PolicySet(
        address indexed agent,
        address indexed operator,
        uint96 maxSinglePaymentWei,
        uint96 dailySpendLimitWei,
        uint64 validAfter,
        uint64 validBefore
    );

    event ApprovedTargetSet(address indexed agent, address indexed target, bool allowed);
    event SpendRecorded(address indexed agent, uint256 indexed dayIndex, uint96 amountWei);

    function marketplace() external view returns (address);

    function policies(address agent) external view returns (
        address operator,
        uint96 maxSinglePaymentWei,
        uint96 dailySpendLimitWei,
        uint64 validAfter,
        uint64 validBefore,
        bool active
    );

    function approvedTargets(address agent, address target) external view returns (bool);
    function dailySpent(address agent, uint256 dayIndex) external view returns (uint96);

    function setPolicy(
        address agent,
        uint96 maxSinglePaymentWei,
        uint96 dailySpendLimitWei,
        uint64 validAfter,
        uint64 validBefore
    ) external;

    function setApprovedTarget(address agent, address target, bool allowed) external;

    function checkSpend(
        address agent,
        address target,
        uint96 amountWei
    ) external view returns (bool ok, string memory reason);

    function recordSpend(address agent, uint96 amountWei) external;
}
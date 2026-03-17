// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISpendingPolicy} from "./interfaces/ISpendingPolicy.sol";

contract SpendingPolicy is ISpendingPolicy {
    address public owner;
    address public marketplace;

    mapping(address => Policy) public policies;
    mapping(address => mapping(address => bool)) public approvedTargets;
    mapping(address => mapping(uint256 => uint96)) public dailySpent;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyMarketplace() {
        require(msg.sender == marketplace, "not marketplace");
        _;
    }

    modifier onlyOperator(address agent) {
        require(policies[agent].operator != address(0), "policy not set");
        require(msg.sender == policies[agent].operator, "not operator");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setMarketplace(address _marketplace) external onlyOwner {
        require(_marketplace != address(0), "zero marketplace");
        require(marketplace == address(0), "marketplace already set");
        marketplace = _marketplace;
    }

    function setPolicy(
        address agent,
        uint96 maxSinglePaymentWei,
        uint96 dailySpendLimitWei,
        uint64 validAfter,
        uint64 validBefore
    ) external {
        require(agent != address(0), "zero agent");
        require(maxSinglePaymentWei > 0, "zero max single");
        require(dailySpendLimitWei > 0, "zero daily limit");
        require(validBefore > validAfter, "invalid time window");

        Policy storage existing = policies[agent];
        if (existing.operator != address(0)) {
            require(msg.sender == existing.operator, "not operator");
        }

        policies[agent] = Policy({
            operator: msg.sender,
            maxSinglePaymentWei: maxSinglePaymentWei,
            dailySpendLimitWei: dailySpendLimitWei,
            validAfter: validAfter,
            validBefore: validBefore,
            active: true
        });

        emit PolicySet(
            agent,
            msg.sender,
            maxSinglePaymentWei,
            dailySpendLimitWei,
            validAfter,
            validBefore
        );
    }

    function setApprovedTarget(address agent, address target, bool allowed)
        external
        onlyOperator(agent)
    {
        require(target != address(0), "zero target");
        approvedTargets[agent][target] = allowed;
        emit ApprovedTargetSet(agent, target, allowed);
    }

    function checkSpend(
        address agent,
        address target,
        uint96 amountWei
    ) external view returns (bool ok, string memory reason) {
        Policy memory p = policies[agent];

        if (!p.active) return (false, "policy inactive");
        if (block.timestamp < p.validAfter) return (false, "policy not active yet");
        if (block.timestamp > p.validBefore) return (false, "policy expired");
        if (!approvedTargets[agent][target]) return (false, "target not approved");
        if (amountWei > p.maxSinglePaymentWei) return (false, "amount exceeds max single");

        uint256 dayIndex = block.timestamp / 1 days;
        uint256 spentToday = dailySpent[agent][dayIndex];

        if (spentToday + amountWei > p.dailySpendLimitWei) {
            return (false, "amount exceeds daily limit");
        }

        return (true, "");
    }

    function recordSpend(address agent, uint96 amountWei) external onlyMarketplace {
        Policy memory p = policies[agent];
        require(p.active, "policy inactive");

        uint256 dayIndex = block.timestamp / 1 days;
        uint256 newDailySpent = uint256(dailySpent[agent][dayIndex]) + amountWei;
        require(newDailySpent <= p.dailySpendLimitWei, "daily limit exceeded");

        dailySpent[agent][dayIndex] = uint96(newDailySpent);
        emit SpendRecorded(agent, dayIndex, amountWei);
    }
}
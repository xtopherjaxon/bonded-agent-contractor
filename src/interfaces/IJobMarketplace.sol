// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBondedTypes} from "./IBondedTypes.sol";

interface IJobMarketplace is IBondedTypes {
    event JobCreated(
        uint256 indexed jobId,
        uint256 indexed parentJobId,
        address indexed creator,
        bytes32 category,
        uint96 rewardWei,
        uint64 deadline,
        bool isSubtask
    );

    event JobAccepted(
        uint256 indexed jobId,
        address indexed agent,
        uint96 bondWeiRequired
    );

    event SubtaskCreated(
        uint256 indexed jobId,
        uint256 indexed parentJobId,
        address indexed preferredAgent
    );

    event ResultSubmitted(uint256 indexed jobId, address indexed agent, string resultURI);
    event JobCompleted(uint256 indexed jobId);
    event JobFailed(uint256 indexed jobId);

    function treasury() external view returns (address);
    function nextJobId() external view returns (uint256);

    function jobs(uint256 jobId) external view returns (
        uint256 id,
        uint256 parentJobId,
        address creator,
        address assignedAgent,
        address preferredAgent,
        bytes32 category,
        string memory specURI,
        string memory resultURI,
        uint96 rewardWei,
        uint96 bondWeiRequired,
        uint64 deadline,
        JobStatus status,
        bool isSubtask
    );

    function createJob(
        bytes32 category,
        string calldata specURI,
        uint96 rewardWei,
        uint64 deadline
    ) external payable returns (uint256 jobId);

    function acceptJob(uint256 jobId) external payable;

    function createSubtask(
        uint256 parentJobId,
        bytes32 category,
        string calldata specURI,
        uint96 rewardWei,
        uint64 deadline,
        address preferredAgent
    ) external payable returns (uint256 subtaskId);

    function submitResult(uint256 jobId, string calldata resultURI) external;
    function markCompleted(uint256 jobId) external;
    function markFailed(uint256 jobId) external;

    function getChildJobs(uint256 parentJobId) external view returns (uint256[] memory);
}
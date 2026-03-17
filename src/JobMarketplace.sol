// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IJobMarketplace} from "./interfaces/IJobMarketplace.sol";
import {IAgentDirectory} from "./interfaces/IAgentDirectory.sol";
import {IEscrowBond} from "./interfaces/IEscrowBond.sol";
import {ISpendingPolicy} from "./interfaces/ISpendingPolicy.sol";

contract JobMarketplace is IJobMarketplace {
    uint256 public nextJobId = 1;
    address public treasury;

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => uint256[]) public childJobs;

    IAgentDirectory public directory;
    IEscrowBond public escrow;
    ISpendingPolicy public policy;

    constructor(
        address _directory,
        address _escrow,
        address _policy,
        address _treasury
    ) {
        require(_directory != address(0), "zero directory");
        require(_escrow != address(0), "zero escrow");
        require(_policy != address(0), "zero policy");
        require(_treasury != address(0), "zero treasury");

        directory = IAgentDirectory(_directory);
        escrow = IEscrowBond(_escrow);
        policy = ISpendingPolicy(_policy);
        treasury = _treasury;
    }

    function createJob(
        bytes32 category,
        string calldata specURI,
        uint96 rewardWei,
        uint64 deadline
    ) external payable returns (uint256 jobId) {
        require(category != bytes32(0), "zero category");
        require(bytes(specURI).length > 0, "empty spec URI");
        require(msg.value == rewardWei, "incorrect reward funding");
        require(rewardWei > 0, "zero reward");
        require(deadline > block.timestamp, "invalid deadline");

        jobId = nextJobId++;

        jobs[jobId] = Job({
            id: jobId,
            parentJobId: 0,
            creator: msg.sender,
            assignedAgent: address(0),
            preferredAgent: address(0),
            category: category,
            specURI: specURI,
            resultURI: "",
            rewardWei: rewardWei,
            bondWeiRequired: 0,
            deadline: deadline,
            status: JobStatus.Open,
            isSubtask: false
        });

        escrow.fundJobReward{value: msg.value}(jobId);

        emit JobCreated(jobId, 0, msg.sender, category, rewardWei, deadline, false);
    }

    function acceptJob(uint256 jobId) external payable {
        Job storage job = jobs[jobId];
        require(job.id != 0, "job not found");
        require(job.status == JobStatus.Open, "job not open");
        require(block.timestamp <= job.deadline, "job expired");

        if (job.preferredAgent != address(0)) {
            require(msg.sender == job.preferredAgent, "not preferred agent");
        }

        uint96 bondRequired = 0;

        if (job.isSubtask) {
            require(directory.hasCategory(msg.sender, job.category), "agent not capable");

            uint16 bondBps = directory.getBondBps(msg.sender);
            bondRequired = uint96((uint256(job.rewardWei) * bondBps) / 10_000);

            require(msg.value == bondRequired, "incorrect bond");
            escrow.postBond{value: msg.value}(jobId, msg.sender);
        } else {
            require(msg.value == 0, "no bond required");
        }

        job.assignedAgent = msg.sender;
        job.bondWeiRequired = bondRequired;
        job.status = JobStatus.Accepted;

        emit JobAccepted(jobId, msg.sender, bondRequired);
    }

    function createSubtask(
        uint256 parentJobId,
        bytes32 category,
        string calldata specURI,
        uint96 rewardWei,
        uint64 deadline,
        address preferredAgent
    ) external payable returns (uint256 subtaskId) {
        Job storage parent = jobs[parentJobId];

        require(parent.id != 0, "parent not found");
        require(parent.status == JobStatus.Accepted, "parent not active");
        require(parent.assignedAgent == msg.sender, "not parent agent");
        require(category != bytes32(0), "zero category");
        require(bytes(specURI).length > 0, "empty spec URI");
        require(rewardWei > 0, "zero reward");
        require(msg.value == rewardWei, "incorrect subtask funding");
        require(deadline > block.timestamp, "invalid deadline");
        require(deadline <= parent.deadline, "subtask beyond parent deadline");

        (bool ok, string memory reason) = policy.checkSpend(msg.sender, address(this), rewardWei);
        require(ok, reason);

        policy.recordSpend(msg.sender, rewardWei);

        subtaskId = nextJobId++;

        jobs[subtaskId] = Job({
            id: subtaskId,
            parentJobId: parentJobId,
            creator: msg.sender,
            assignedAgent: address(0),
            preferredAgent: preferredAgent,
            category: category,
            specURI: specURI,
            resultURI: "",
            rewardWei: rewardWei,
            bondWeiRequired: 0,
            deadline: deadline,
            status: JobStatus.Open,
            isSubtask: true
        });

        childJobs[parentJobId].push(subtaskId);
        escrow.fundJobReward{value: msg.value}(subtaskId);

        emit JobCreated(subtaskId, parentJobId, msg.sender, category, rewardWei, deadline, true);
        emit SubtaskCreated(subtaskId, parentJobId, preferredAgent);
    }

    function submitResult(uint256 jobId, string calldata resultURI) external {
        Job storage job = jobs[jobId];

        require(job.id != 0, "job not found");
        require(job.status == JobStatus.Accepted, "job not accepted");
        require(job.assignedAgent == msg.sender, "not assigned agent");
        require(block.timestamp <= job.deadline, "job expired");
        require(bytes(resultURI).length > 0, "empty result");

        job.resultURI = resultURI;
        job.status = JobStatus.Submitted;

        emit ResultSubmitted(jobId, msg.sender, resultURI);
    }

    function markCompleted(uint256 jobId) external {
        Job storage job = jobs[jobId];

        require(job.id != 0, "job not found");
        require(job.status == JobStatus.Submitted, "job not submitted");
        require(_canResolve(jobId, msg.sender), "not resolver");

        job.status = JobStatus.Completed;

        escrow.releaseReward(jobId, payable(job.assignedAgent));

        if (job.isSubtask && job.bondWeiRequired > 0) {
            escrow.returnBond(jobId, payable(job.assignedAgent));
            directory.noteJobSuccess(job.assignedAgent);
        }

        emit JobCompleted(jobId);
    }

    function markFailed(uint256 jobId) external {
        Job storage job = jobs[jobId];

        require(job.id != 0, "job not found");
        require(
            job.status == JobStatus.Accepted || job.status == JobStatus.Submitted,
            "job not resolvable"
        );
        require(
            _canResolve(jobId, msg.sender) || block.timestamp > job.deadline,
            "not resolver"
        );

        job.status = JobStatus.Failed;

        escrow.refundReward(jobId, payable(job.creator));

        if (job.isSubtask && job.bondWeiRequired > 0 && job.assignedAgent != address(0)) {
            escrow.slashBond(jobId, payable(treasury));
            directory.noteJobFailure(job.assignedAgent);
        }

        emit JobFailed(jobId);
    }

    function getChildJobs(uint256 parentJobId) external view returns (uint256[] memory) {
        return childJobs[parentJobId];
    }

    function _canResolve(uint256 jobId, address caller) internal view returns (bool) {
        Job storage job = jobs[jobId];

        if (!job.isSubtask) {
            return caller == job.creator;
        }

        Job storage parent = jobs[job.parentJobId];
        return caller == parent.assignedAgent;
    }
}
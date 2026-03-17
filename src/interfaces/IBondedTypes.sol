// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBondedTypes {
    enum JobStatus {
        None,
        Open,
        Accepted,
        Submitted,
        Completed,
        Failed,
        Cancelled
    }

    struct AgentProfile {
        address operator;
        address payoutWallet;
        bytes32 erc8004Id;
        string manifestURI;
        uint96 basePriceWei;
        bool active;
    }

    struct TrustStats {
        uint32 bondedJobsCompleted;
        uint32 bondedJobsFailed;
        uint32 reputationScore;
    }

    struct Job {
        uint256 id;
        uint256 parentJobId;
        address creator;
        address assignedAgent;
        address preferredAgent;
        bytes32 category;
        string specURI;
        string resultURI;
        uint96 rewardWei;
        uint96 bondWeiRequired;
        uint64 deadline;
        JobStatus status;
        bool isSubtask;
    }

    struct Policy {
        address operator;
        uint96 maxSinglePaymentWei;
        uint96 dailySpendLimitWei;
        uint64 validAfter;
        uint64 validBefore;
        bool active;
    }

    struct RewardEscrow {
        uint96 amountWei;
        bool funded;
        bool released;
        bool refunded;
    }

    struct BondEscrow {
        address bondedAgent;
        uint96 amountWei;
        bool posted;
        bool settled;
    }
}
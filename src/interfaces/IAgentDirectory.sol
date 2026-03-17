// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBondedTypes} from "./IBondedTypes.sol";

interface IAgentDirectory is IBondedTypes {
    event AgentRegistered(
        address indexed agentWallet,
        address indexed operator,
        bytes32 indexed erc8004Id,
        string manifestURI
    );

    event AgentManifestUpdated(address indexed agentWallet, string manifestURI);
    event AgentActiveSet(address indexed agentWallet, bool active);
    event AgentCategoryAdded(address indexed agentWallet, bytes32 indexed category);

    event TrustStatsUpdated(
        address indexed agentWallet,
        uint32 bondedJobsCompleted,
        uint32 bondedJobsFailed,
        uint32 reputationScore
    );

    function marketplace() external view returns (address);

    function registerAgent(
        address agentWallet,
        address payoutWallet,
        bytes32 erc8004Id,
        string calldata manifestURI,
        bytes32[] calldata categories,
        uint96 basePriceWei
    ) external;

    function updateManifestURI(address agentWallet, string calldata manifestURI) external;
    function setActive(address agentWallet, bool active) external;
    function addCategory(address agentWallet, bytes32 category) external;

    function getAgent(address agentWallet) external view returns (AgentProfile memory);
    function getCategories(address agentWallet) external view returns (bytes32[] memory);
    function getAgentsByCategory(bytes32 category) external view returns (address[] memory);
    function getTrustStats(address agentWallet) external view returns (TrustStats memory);

    function hasCategory(address agentWallet, bytes32 category) external view returns (bool);
    function getBondBps(address agentWallet) external view returns (uint16);

    function noteJobSuccess(address agentWallet) external;
    function noteJobFailure(address agentWallet) external;
}
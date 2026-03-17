// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentDirectory} from "./interfaces/IAgentDirectory.sol";

contract AgentDirectory is IAgentDirectory {
    address public owner;
    address public marketplace;

    mapping(address => AgentProfile) private _agents;
    mapping(address => TrustStats) private _trustStats;

    mapping(address => bytes32[]) private _categories;
    mapping(bytes32 => address[]) private _agentsByCategory;
    mapping(address => mapping(bytes32 => bool)) public hasCategory;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyMarketplace() {
        require(msg.sender == marketplace, "not marketplace");
        _;
    }

    modifier onlyOperator(address agentWallet) {
        require(_agents[agentWallet].operator != address(0), "agent not registered");
        require(msg.sender == _agents[agentWallet].operator, "not operator");
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

    function registerAgent(
        address agentWallet,
        address payoutWallet,
        bytes32 erc8004Id,
        string calldata manifestURI,
        bytes32[] calldata categories,
        uint96 basePriceWei
    ) external {
        require(agentWallet != address(0), "zero agent wallet");
        require(payoutWallet != address(0), "zero payout wallet");
        require(bytes(manifestURI).length > 0, "empty manifest URI");
        require(_agents[agentWallet].operator == address(0), "agent already registered");

        _agents[agentWallet] = AgentProfile({
            operator: msg.sender,
            payoutWallet: payoutWallet,
            erc8004Id: erc8004Id,
            manifestURI: manifestURI,
            basePriceWei: basePriceWei,
            active: true
        });

        emit AgentRegistered(agentWallet, msg.sender, erc8004Id, manifestURI);

        uint256 len = categories.length;
        for (uint256 i = 0; i < len; i++) {
            _addCategory(agentWallet, categories[i]);
        }
    }

    function updateManifestURI(address agentWallet, string calldata manifestURI)
        external
        onlyOperator(agentWallet)
    {
        require(bytes(manifestURI).length > 0, "empty manifest URI");

        _agents[agentWallet].manifestURI = manifestURI;
        emit AgentManifestUpdated(agentWallet, manifestURI);
    }

    function setActive(address agentWallet, bool active)
        external
        onlyOperator(agentWallet)
    {
        _agents[agentWallet].active = active;
        emit AgentActiveSet(agentWallet, active);
    }

    function addCategory(address agentWallet, bytes32 category)
        external
        onlyOperator(agentWallet)
    {
        _addCategory(agentWallet, category);
    }

    function getAgent(address agentWallet) external view returns (AgentProfile memory) {
        return _agents[agentWallet];
    }

    function getCategories(address agentWallet) external view returns (bytes32[] memory) {
        return _categories[agentWallet];
    }

    function getAgentsByCategory(bytes32 category) external view returns (address[] memory) {
        return _agentsByCategory[category];
    }

    function getTrustStats(address agentWallet) external view returns (TrustStats memory) {
        return _trustStats[agentWallet];
    }

    function noteJobSuccess(address agentWallet) external onlyMarketplace {
        require(_agents[agentWallet].operator != address(0), "agent not registered");

        TrustStats storage stats = _trustStats[agentWallet];
        stats.bondedJobsCompleted += 1;
        stats.reputationScore += 10;

        emit TrustStatsUpdated(
            agentWallet,
            stats.bondedJobsCompleted,
            stats.bondedJobsFailed,
            stats.reputationScore
        );
    }

    function noteJobFailure(address agentWallet) external onlyMarketplace {
        require(_agents[agentWallet].operator != address(0), "agent not registered");

        TrustStats storage stats = _trustStats[agentWallet];
        stats.bondedJobsFailed += 1;

        if (stats.reputationScore >= 5) {
            stats.reputationScore -= 5;
        } else {
            stats.reputationScore = 0;
        }

        emit TrustStatsUpdated(
            agentWallet,
            stats.bondedJobsCompleted,
            stats.bondedJobsFailed,
            stats.reputationScore
        );
    }

    function getBondBps(address agentWallet) public view returns (uint16) {
        require(_agents[agentWallet].operator != address(0), "agent not registered");

        uint32 completed = _trustStats[agentWallet].bondedJobsCompleted;

        if (completed == 0) return 3000;
        if (completed <= 3) return 2000;
        if (completed <= 10) return 1000;
        return 500;
    }

    function _addCategory(address agentWallet, bytes32 category) internal {
        require(category != bytes32(0), "zero category");

        if (hasCategory[agentWallet][category]) {
            return;
        }

        hasCategory[agentWallet][category] = true;
        _categories[agentWallet].push(category);
        _agentsByCategory[category].push(agentWallet);

        emit AgentCategoryAdded(agentWallet, category);
    }
}
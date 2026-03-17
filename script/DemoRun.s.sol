// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {JobMarketplace} from "../src/JobMarketplace.sol";
import {AgentDirectory} from "../src/AgentDirectory.sol";
import {EscrowBond} from "../src/EscrowBond.sol";
import {SpendingPolicy} from "../src/SpendingPolicy.sol";

contract DemoRun is Script {

    JobMarketplace marketplace;
    AgentDirectory directory;
    EscrowBond escrow;
    SpendingPolicy policy;

    uint256 humanPk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 mainAgentPk = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 priceAgentPk = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 volumeAgentPk = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    uint256 yieldAgentPk = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;

    uint256 deployerPk = 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e;
    address deployer = vm.addr(deployerPk);

    address human = vm.addr(humanPk);
    address mainAgent = vm.addr(mainAgentPk);
    address priceAgent = vm.addr(priceAgentPk);
    address volumeAgent = vm.addr(volumeAgentPk);
    address yieldAgent = vm.addr(yieldAgentPk);

    bytes32 constant REPORT_CAT = keccak256("eth_market_report");
    bytes32 constant PRICE_CAT  = keccak256("price_data");
    bytes32 constant VOLUME_CAT = keccak256("volume_data");
    bytes32 constant YIELD_CAT  = keccak256("yield_data");

    function run() external {

        // --------------------------------------------------
        // DEPLOY CONTRACTS
        // --------------------------------------------------

        vm.broadcast(deployerPk);
        escrow = new EscrowBond();

        vm.broadcast(deployerPk);
        directory = new AgentDirectory();

        vm.broadcast(deployerPk);
        policy = new SpendingPolicy();

        vm.broadcast(deployerPk);
        marketplace = new JobMarketplace(
            address(directory),
            address(escrow),
            address(policy),
            deployer
        );

        // --------------------------------------------------
        // CONNECT CONTRACTS
        // --------------------------------------------------

        vm.broadcast(deployerPk);
        escrow.setMarketplace(address(marketplace));

        vm.broadcast(deployerPk);
        directory.setMarketplace(address(marketplace));

        vm.broadcast(deployerPk);
        policy.setMarketplace(address(marketplace));

        // --------------------------------------------------
        // CONFIGURE SPENDING POLICY FOR MAIN AGENT
        // --------------------------------------------------

        vm.broadcast(mainAgentPk);
        policy.setPolicy(
            mainAgent,
            1 ether,   // max single spend
            20 ether,   // daily limit
            uint64(block.timestamp),
            uint64(block.timestamp + 1 days)
        );

        vm.broadcast(mainAgentPk);
        policy.setApprovedTarget(mainAgent, address(marketplace), true);

        // --------------------------------------------------
        // REGISTER AGENTS
        // --------------------------------------------------

        bytes32[] memory categories = new bytes32[](1);

        // MAIN AGENT
        categories[0] = REPORT_CAT;

        vm.broadcast(mainAgentPk);
        directory.registerAgent(
            mainAgent,
            mainAgent,
            keccak256("main-agent"),
            "ipfs://main-agent-manifest",
            categories,
            0
        );

        // PRICE AGENT
        categories = new bytes32[](1);
        categories[0] = PRICE_CAT;

        vm.broadcast(priceAgentPk);
        directory.registerAgent(
            priceAgent,
            priceAgent,
            keccak256("price-agent"),
            "ipfs://price-agent-manifest",
            categories,
            0
        );

        // VOLUME AGENT
        categories = new bytes32[](1);
        categories[0] = VOLUME_CAT;

        vm.broadcast(volumeAgentPk);
        directory.registerAgent(
            volumeAgent,
            volumeAgent,
            keccak256("volume-agent"),
            "ipfs://volume-agent-manifest",
            categories,
            0
        );

        // YIELD AGENT
        categories = new bytes32[](1);
        categories[0] = YIELD_CAT;

        vm.broadcast(yieldAgentPk);
        directory.registerAgent(
            yieldAgent,
            yieldAgent,
            keccak256("yield-agent"),
            "ipfs://yield-agent-manifest",
            categories,
            0
        );

        // --------------------------------------------------
        // HUMAN CREATES JOB
        // --------------------------------------------------

        vm.broadcast(humanPk);
        uint256 jobId = marketplace.createJob{value: 1 ether}(
            REPORT_CAT,
            "ipfs://eth-market-job",
            1 ether,
            uint64(block.timestamp + 1 days)
        );

        // --------------------------------------------------
        // MAIN AGENT ACCEPTS JOB
        // --------------------------------------------------

        vm.broadcast(mainAgentPk);
        marketplace.acceptJob(jobId);

        // --------------------------------------------------
        // MAIN AGENT CREATES SUBTASKS
        // --------------------------------------------------

        vm.broadcast(mainAgentPk);
        uint256 priceJob = marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            PRICE_CAT,
            "ipfs://price-task",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            priceAgent
        );

        vm.broadcast(mainAgentPk);
        uint256 volumeJob = marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            VOLUME_CAT,
            "ipfs://volume-task",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            volumeAgent
        );

        vm.broadcast(mainAgentPk);
        uint256 yieldJob = marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            YIELD_CAT,
            "ipfs://yield-task",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            yieldAgent
        );

        // --------------------------------------------------
        // SPECIALISTS ACCEPT SUBTASKS
        // --------------------------------------------------

        vm.broadcast(priceAgentPk);
        marketplace.acceptJob{value: 0.06 ether}(priceJob);

        vm.broadcast(volumeAgentPk);
        marketplace.acceptJob{value: 0.06 ether}(volumeJob);

        vm.broadcast(yieldAgentPk);
        marketplace.acceptJob{value: 0.06 ether}(yieldJob);

        // --------------------------------------------------
        // SPECIALISTS SUBMIT RESULTS
        // --------------------------------------------------

        vm.broadcast(priceAgentPk);
        marketplace.submitResult(priceJob, "ipfs://price-result");

        vm.broadcast(volumeAgentPk);
        marketplace.submitResult(volumeJob, "ipfs://volume-result");

        vm.broadcast(yieldAgentPk);
        marketplace.submitResult(yieldJob, "ipfs://yield-result");

        // --------------------------------------------------
        // MAIN AGENT COMPLETES SUBTASKS
        // --------------------------------------------------

        vm.broadcast(mainAgentPk);
        marketplace.markCompleted(priceJob);

        vm.broadcast(mainAgentPk);
        marketplace.markCompleted(volumeJob);

        vm.broadcast(mainAgentPk);
        marketplace.markCompleted(yieldJob);

        // --------------------------------------------------
        // MAIN AGENT SUBMITS FINAL RESULT
        // --------------------------------------------------

        vm.broadcast(mainAgentPk);
        marketplace.submitResult(jobId, "ipfs://final-report");

        // --------------------------------------------------
        // HUMAN COMPLETES PARENT JOB
        // --------------------------------------------------

        vm.broadcast(humanPk);
        marketplace.markCompleted(jobId);
    }
}
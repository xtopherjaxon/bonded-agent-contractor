// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";

import {AgentDirectory} from "../src/AgentDirectory.sol";
import {SpendingPolicy} from "../src/SpendingPolicy.sol";

contract BootstrapAgents is Script {
    bytes32 constant REPORT_CAT = keccak256("eth_market_report");
    bytes32 constant PRICE_CAT  = keccak256("price_data");
    bytes32 constant VOLUME_CAT = keccak256("volume_data");
    bytes32 constant YIELD_CAT  = keccak256("yield_data");

    function run() external {
        address directoryAddr = vm.envAddress("AGENT_DIRECTORY_ADDRESS");
        address policyAddr = vm.envAddress("SPENDING_POLICY_ADDRESS");
        address marketplaceAddr = vm.envAddress("JOB_MARKETPLACE_ADDRESS");

        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        uint256 mainPk = vm.envUint("MAIN_AGENT_PK");
        uint256 pricePk = vm.envUint("PRICE_AGENT_PK");
        uint256 volumePk = vm.envUint("VOLUME_AGENT_PK");
        uint256 yieldPk = vm.envUint("YIELD_AGENT_PK");

        address mainAgent = vm.addr(mainPk);
        address priceAgent = vm.addr(pricePk);
        address volumeAgent = vm.addr(volumePk);
        address yieldAgent = vm.addr(yieldPk);

        AgentDirectory directory = AgentDirectory(directoryAddr);
        SpendingPolicy policy = SpendingPolicy(policyAddr);

        bytes32[] memory categories = new bytes32[](1);

        vm.startBroadcast(deployerPk);

        // main
        categories[0] = REPORT_CAT;
        directory.registerAgent(
            mainAgent,
            mainAgent,
            keccak256("main-agent"),
            "ipfs://main-agent-manifest",
            categories,
            0
        );
        policy.setPolicy(
            mainAgent,
            1 ether,
            20 ether,
            uint64(block.timestamp - 10),
            uint64(block.timestamp + 30 days)
        );
        policy.setApprovedTarget(mainAgent, marketplaceAddr, true);

        // price
        categories = new bytes32[](1);
        categories[0] = PRICE_CAT;
        directory.registerAgent(
            priceAgent,
            priceAgent,
            keccak256("price-agent"),
            "ipfs://price-agent-manifest",
            categories,
            0
        );

        // volume
        categories = new bytes32[](1);
        categories[0] = VOLUME_CAT;
        directory.registerAgent(
            volumeAgent,
            volumeAgent,
            keccak256("volume-agent"),
            "ipfs://volume-agent-manifest",
            categories,
            0
        );

        // yield
        categories = new bytes32[](1);
        categories[0] = YIELD_CAT;
        directory.registerAgent(
            yieldAgent,
            yieldAgent,
            keccak256("yield-agent"),
            "ipfs://yield-agent-manifest",
            categories,
            0
        );

        vm.stopBroadcast();

        console2.log("Main agent:", mainAgent);
        console2.log("Price agent:", priceAgent);
        console2.log("Volume agent:", volumeAgent);
        console2.log("Yield agent:", yieldAgent);
    }
}
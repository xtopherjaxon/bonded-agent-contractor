// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentDirectory} from "../src/AgentDirectory.sol";
import {IAgentDirectory} from "../src/interfaces/IAgentDirectory.sol";

contract AgentDirectoryTest is Test {
    AgentDirectory internal directory;

    address internal marketplace = address(0xA11CE);
    address internal operator = address(0xB0B);
    address internal agent = address(0xCAFE);
    address internal payout = address(0xD00D);
    address internal other = address(0xEEEE);

    bytes32 internal constant ERC8004_ID = keccak256("agent-identity");
    bytes32 internal constant PRICE_DATA = keccak256("price_data");
    bytes32 internal constant YIELD_DATA = keccak256("yield_data");

    function setUp() public {
        directory = new AgentDirectory();
        directory.setMarketplace(marketplace);
    }

    function testOnlyOwnerCanSetMarketplace() public {
        AgentDirectory newDirectory = new AgentDirectory();

        vm.expectRevert("not owner");
        vm.prank(other);
        newDirectory.setMarketplace(marketplace);
    }

    function testCannotSetMarketplaceTwice() public {
        AgentDirectory newDirectory = new AgentDirectory();
        newDirectory.setMarketplace(marketplace);

        vm.expectRevert("marketplace already set");
        newDirectory.setMarketplace(address(0x1234));
    }

    function testRegisterAgent() public {
        bytes32[] memory categories = new bytes32[](2);

        categories[0] = PRICE_DATA;
        categories[1] = YIELD_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        IAgentDirectory.AgentProfile memory profile = directory.getAgent(agent);

        assertEq(profile.operator, operator);
        assertEq(profile.payoutWallet, payout);
        assertEq(profile.erc8004Id, ERC8004_ID);
        assertEq(profile.manifestURI, "ipfs://manifest-1");
        assertEq(profile.basePriceWei, 0.01 ether);
        assertTrue(profile.active);
    }

    function testRegisterAddsCategories() public {
        bytes32[] memory categories = new bytes32[](2);

        categories[0] = PRICE_DATA;
        categories[1] = YIELD_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        bytes32[] memory stored = directory.getCategories(agent);
        assertEq(stored.length, 2);
        assertEq(stored[0], PRICE_DATA);
        assertEq(stored[1], YIELD_DATA);

        assertTrue(directory.hasCategory(agent, PRICE_DATA));
        assertTrue(directory.hasCategory(agent, YIELD_DATA));
    }

    function testGetAgentsByCategory() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        address[] memory agents = directory.getAgentsByCategory(PRICE_DATA);
        assertEq(agents.length, 1);
        assertEq(agents[0], agent);
    }

    function testCannotRegisterTwice() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.startPrank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        vm.expectRevert("agent already registered");
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-2",
            categories,
            0.02 ether
        );
        vm.stopPrank();
    }

    function testOnlyOperatorCanUpdateManifest() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        vm.expectRevert("not operator");
        vm.prank(other);
        directory.updateManifestURI(agent, "ipfs://manifest-2");

        vm.prank(operator);
        directory.updateManifestURI(agent, "ipfs://manifest-2");

        IAgentDirectory.AgentProfile memory profile = directory.getAgent(agent);
        assertEq(profile.manifestURI, "ipfs://manifest-2");
    }

    function testOnlyOperatorCanSetActive() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        vm.expectRevert("not operator");
        vm.prank(other);
        directory.setActive(agent, false);

        vm.prank(operator);
        directory.setActive(agent, false);

        IAgentDirectory.AgentProfile memory profile = directory.getAgent(agent);
        assertFalse(profile.active);
    }

    function testOnlyMarketplaceCanNoteSuccess() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        vm.expectRevert("not marketplace");
        directory.noteJobSuccess(agent);

        vm.prank(marketplace);
        directory.noteJobSuccess(agent);

        IAgentDirectory.TrustStats memory stats = directory.getTrustStats(agent);
        assertEq(stats.bondedJobsCompleted, 1);
        assertEq(stats.bondedJobsFailed, 0);
        assertEq(stats.reputationScore, 10);
    }

    function testOnlyMarketplaceCanNoteFailure() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        vm.expectRevert("not marketplace");
        directory.noteJobFailure(agent);

        vm.prank(marketplace);
        directory.noteJobFailure(agent);

        IAgentDirectory.TrustStats memory stats = directory.getTrustStats(agent);
        assertEq(stats.bondedJobsCompleted, 0);
        assertEq(stats.bondedJobsFailed, 1);
        assertEq(stats.reputationScore, 0);
    }

    function testBondTierProgression() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        assertEq(directory.getBondBps(agent), 3000);

        vm.prank(marketplace);
        directory.noteJobSuccess(agent);
        assertEq(directory.getBondBps(agent), 2000);

        vm.prank(marketplace);
        directory.noteJobSuccess(agent);
        vm.prank(marketplace);
        directory.noteJobSuccess(agent);
        assertEq(directory.getBondBps(agent), 2000);

        vm.prank(marketplace);
        directory.noteJobSuccess(agent);
        assertEq(directory.getBondBps(agent), 1000);

        for (uint256 i = 0; i < 6; i++) {
            vm.prank(marketplace);
            directory.noteJobSuccess(agent);
        }
        assertEq(directory.getBondBps(agent), 1000);

        vm.prank(marketplace);
        directory.noteJobSuccess(agent);
        assertEq(directory.getBondBps(agent), 500);
    }

    function testAddCategoryNoDuplicate() public {
        bytes32[] memory categories = new bytes32[](1);

        categories[0] = PRICE_DATA;

        vm.prank(operator);
        directory.registerAgent(
            agent,
            payout,
            ERC8004_ID,
            "ipfs://manifest-1",
            categories,
            0.01 ether
        );

        vm.prank(operator);
        directory.addCategory(agent, PRICE_DATA);

        bytes32[] memory stored = directory.getCategories(agent);
        assertEq(stored.length, 1);

        address[] memory agents = directory.getAgentsByCategory(PRICE_DATA);
        assertEq(agents.length, 1);
    }
}
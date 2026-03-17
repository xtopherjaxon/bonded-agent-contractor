// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EscrowBond} from "../src/EscrowBond.sol";
import {AgentDirectory} from "../src/AgentDirectory.sol";
import {SpendingPolicy} from "../src/SpendingPolicy.sol";
import {JobMarketplace} from "../src/JobMarketplace.sol";
import {IAgentDirectory} from "../src/interfaces/IAgentDirectory.sol";
import {IJobMarketplace} from "../src/interfaces/IJobMarketplace.sol";
import {IBondedTypes} from "../src/interfaces/IBondedTypes.sol";

contract JobMarketplaceTest is Test {
    EscrowBond internal escrow;
    AgentDirectory internal directory;
    SpendingPolicy internal policy;
    JobMarketplace internal marketplace;

    address internal owner = address(this);
    address internal treasury = address(0x9999);

    address internal client = address(0x1001);
    address internal mainAgent = address(0x1002);
    address internal specialist = address(0x1003);
    address internal payoutMain = address(0x2002);
    address internal payoutSpecialist = address(0x2003);

    bytes32 internal constant MAIN_ID = keccak256("main-agent");
    bytes32 internal constant SPECIALIST_ID = keccak256("specialist-agent");

    bytes32 internal constant REPORT_CAT = keccak256("eth_market_report");
    bytes32 internal constant PRICE_CAT = keccak256("price_data");
    bytes32 internal constant VOLUME_CAT = keccak256("volume_data");
    bytes32 internal constant YIELD_CAT  = keccak256("yield_data");

    function setUp() public {
        escrow = new EscrowBond();
        directory = new AgentDirectory();
        policy = new SpendingPolicy();

        marketplace = new JobMarketplace(
            address(directory),
            address(escrow),
            address(policy),
            treasury
        );

        escrow.setMarketplace(address(marketplace));
        directory.setMarketplace(address(marketplace));
        policy.setMarketplace(address(marketplace));

        _registerMainAgent();
        _registerSpecialist();
        _setMainAgentPolicy();
    }

    function testCreateTopLevelJob() public {
        vm.deal(client, 1 ether);

        vm.prank(client);
        uint256 jobId = marketplace.createJob{value: 1 ether}(
            REPORT_CAT,
            "ipfs://job-spec",
            1 ether,
            uint64(block.timestamp + 1 days)
        );

        (
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
            IJobMarketplace.JobStatus status,
            bool isSubtask
        ) = marketplace.jobs(jobId);

        assertEq(id, 1);
        assertEq(parentJobId, 0);
        assertEq(creator, client);
        assertEq(assignedAgent, address(0));
        assertEq(preferredAgent, address(0));
        assertEq(category, REPORT_CAT);
        assertEq(specURI, "ipfs://job-spec");
        assertEq(resultURI, "");
        assertEq(rewardWei, 1 ether);
        assertEq(bondWeiRequired, 0);
        assertEq(uint256(status), uint256(IBondedTypes.JobStatus.Open));
        assertFalse(isSubtask);
        assertGt(deadline, block.timestamp);
    }

    function testAcceptTopLevelJob() public {
        uint256 jobId = _createTopLevelJob();

        vm.prank(mainAgent);
        marketplace.acceptJob(jobId);

        (, , , address assignedAgent, , , , , , uint96 bondWeiRequired, , IJobMarketplace.JobStatus status, ) =
            marketplace.jobs(jobId);

        assertEq(assignedAgent, mainAgent);
        assertEq(bondWeiRequired, 0);
        assertEq(uint256(status), uint256(IBondedTypes.JobStatus.Accepted));
    }

    function testCreateSubtaskAndRecordSpend() public {
        uint256 jobId = _createTopLevelJob();

        vm.prank(mainAgent);
        marketplace.acceptJob(jobId);

        vm.deal(mainAgent, 0.2 ether);

        vm.prank(mainAgent);
        uint256 subtaskId = marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            PRICE_CAT,
            "ipfs://subtask-spec",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            specialist
        );

        uint256[] memory children = marketplace.getChildJobs(jobId);
        assertEq(children.length, 1);
        assertEq(children[0], subtaskId);

        (
            uint256 id,
            uint256 parentJobId,
            address creator,
            address assignedAgent,
            address preferredAgent,
            bytes32 category,
            string memory specURI,
            ,
            uint96 rewardWei,
            ,
            ,
            IJobMarketplace.JobStatus status,
            bool isSubtask
        ) = marketplace.jobs(subtaskId);

        assertEq(id, subtaskId);
        assertEq(parentJobId, jobId);
        assertEq(creator, mainAgent);
        assertEq(assignedAgent, address(0));
        assertEq(preferredAgent, specialist);
        assertEq(category, PRICE_CAT);
        assertEq(specURI, "ipfs://subtask-spec");
        assertEq(rewardWei, 0.2 ether);
        assertEq(uint256(status), uint256(IBondedTypes.JobStatus.Open));
        assertTrue(isSubtask);

        uint256 dayIndex = block.timestamp / 1 days;
        assertEq(policy.dailySpent(mainAgent, dayIndex), 0.2 ether);
    }

    function testAcceptSubtaskPostsBond() public {
        uint256 jobId = _createTopLevelJob();

        vm.prank(mainAgent);
        marketplace.acceptJob(jobId);

        vm.deal(mainAgent, 0.2 ether);

        vm.prank(mainAgent);
        uint256 subtaskId = marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            PRICE_CAT,
            "ipfs://subtask-spec",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            specialist
        );

        uint256 expectedBond = (0.2 ether * 3000) / 10_000;
        vm.deal(specialist, expectedBond);

        vm.prank(specialist);
        marketplace.acceptJob{value: expectedBond}(subtaskId);

        (, , , address assignedAgent, , , , , , uint96 bondWeiRequired, , IJobMarketplace.JobStatus status, ) =
            marketplace.jobs(subtaskId);

        assertEq(assignedAgent, specialist);
        assertEq(bondWeiRequired, expectedBond);
        assertEq(uint256(status), uint256(IBondedTypes.JobStatus.Accepted));

        (address bondedAgent, uint96 amountWei, bool posted, bool settled) = escrow.bonds(subtaskId);
        assertEq(bondedAgent, specialist);
        assertEq(amountWei, expectedBond);
        assertTrue(posted);
        assertFalse(settled);
    }

    function testCompleteSubtaskReturnsBondAndUpdatesReputation() public {
        uint256 jobId = _createTopLevelJob();

        vm.prank(mainAgent);
        marketplace.acceptJob(jobId);

        vm.deal(mainAgent, 0.2 ether);

        vm.prank(mainAgent);
        uint256 subtaskId = marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            PRICE_CAT,
            "ipfs://subtask-spec",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            specialist
        );

        uint256 expectedBond = (0.2 ether * 3000) / 10_000;
        vm.deal(specialist, expectedBond);

        vm.prank(specialist);
        marketplace.acceptJob{value: expectedBond}(subtaskId);

        uint256 specialistBefore = specialist.balance;

        vm.prank(specialist);
        marketplace.submitResult(subtaskId, "ipfs://subtask-result");

        vm.prank(mainAgent);
        marketplace.markCompleted(subtaskId);

        // reward + returned bond
        assertEq(specialist.balance, specialistBefore + 0.2 ether + expectedBond);

        IAgentDirectory.TrustStats memory stats = directory.getTrustStats(specialist);
        assertEq(stats.bondedJobsCompleted, 1);
        assertEq(stats.bondedJobsFailed, 0);
        assertEq(stats.reputationScore, 10);
    }

    function testSubtaskRefundsCreatorAndSlashesBond() public {
        uint256 jobId = _createTopLevelJob();

        vm.prank(mainAgent);
        marketplace.acceptJob(jobId);

        vm.deal(mainAgent, 0.2 ether);

        vm.prank(mainAgent);
        uint256 subtaskId = marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            PRICE_CAT,
            "ipfs://subtask-spec",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            specialist
        );

        uint256 expectedBond = (0.2 ether * 3000) / 10_000;
        vm.deal(specialist, expectedBond);

        vm.prank(specialist);
        marketplace.acceptJob{value: expectedBond}(subtaskId);

        uint256 mainAgentBefore = mainAgent.balance;
        uint256 treasuryBefore = treasury.balance;

        vm.prank(specialist);
        marketplace.submitResult(subtaskId, "ipfs://bad-result");

        vm.prank(mainAgent);
        marketplace.markFailed(subtaskId);

        assertEq(mainAgent.balance, mainAgentBefore + 0.2 ether);
        assertEq(treasury.balance, treasuryBefore + expectedBond);

        IAgentDirectory.TrustStats memory stats = directory.getTrustStats(specialist);
        assertEq(stats.bondedJobsCompleted, 0);
        assertEq(stats.bondedJobsFailed, 1);
        assertEq(stats.reputationScore, 0);
    }

    function testCreateSubtaskFailsWithoutApprovedTarget() public {
        uint256 jobId = _createTopLevelJob();

        vm.prank(mainAgent);
        marketplace.acceptJob(jobId);

        vm.prank(mainAgent);
        policy.setPolicy(
            mainAgent,
            1 ether,
            2 ether,
            uint64(block.timestamp - 1),
            uint64(block.timestamp + 1 days)
        );

        vm.prank(mainAgent);
        policy.setApprovedTarget(mainAgent, address(marketplace), false);

        vm.deal(mainAgent, 0.2 ether);

        vm.expectRevert(bytes("target not approved"));
        vm.prank(mainAgent);
        marketplace.createSubtask{value: 0.2 ether}(
            jobId,
            PRICE_CAT,
            "ipfs://subtask-spec",
            0.2 ether,
            uint64(block.timestamp + 12 hours),
            specialist
        );
    }

    function _createTopLevelJob() internal returns (uint256 jobId) {
        vm.deal(client, 1 ether);

        vm.prank(client);
        jobId = marketplace.createJob{value: 1 ether}(
            REPORT_CAT,
            "ipfs://job-spec",
            1 ether,
            uint64(block.timestamp + 1 days)
        );
    }

    function _registerMainAgent() internal {
        bytes32[] memory categories = new bytes32[](1);
        categories[0] = REPORT_CAT;

        vm.prank(mainAgent);
        directory.registerAgent(
            mainAgent,
            payoutMain,
            MAIN_ID,
            "ipfs://main-manifest",
            categories,
            0.1 ether
        );
    }

    function _registerSpecialist() internal {
        bytes32[] memory categories = new bytes32[](1);
        categories[0] = PRICE_CAT;

        vm.prank(specialist);
        directory.registerAgent(
            specialist,
            payoutSpecialist,
            SPECIALIST_ID,
            "ipfs://specialist-manifest",
            categories,
            0.02 ether
        );
    }

    function _setMainAgentPolicy() internal {
        vm.prank(mainAgent);
        policy.setPolicy(
            mainAgent,
            1 ether,
            2 ether,
            uint64(block.timestamp - 1),
            uint64(block.timestamp + 7 days)
        );

        vm.prank(mainAgent);
        policy.setApprovedTarget(mainAgent, address(marketplace), true);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SpendingPolicy} from "../src/SpendingPolicy.sol";

contract SpendingPolicyTest is Test {
    SpendingPolicy internal policy;

    address internal marketplace = address(0xA11CE);
    address internal operator = address(0xB0B);
    address internal agent = address(0xCAFE);
    address internal target = address(0xD00D);
    address internal other = address(0xEEEE);

    uint64 internal validAfter;
    uint64 internal validBefore;

    function setUp() public {
        policy = new SpendingPolicy();
        policy.setMarketplace(marketplace);
        validAfter = uint64(block.timestamp - 1);
        validBefore = uint64(block.timestamp + 7 days);
    }

    function testOnlyOwnerCanSetMarketplace() public {
        SpendingPolicy newPolicy = new SpendingPolicy();

        vm.expectRevert("not owner");
        vm.prank(other);
        newPolicy.setMarketplace(marketplace);
    }

    function testCannotSetMarketplaceTwice() public {
        SpendingPolicy newPolicy = new SpendingPolicy();
        newPolicy.setMarketplace(marketplace);

        vm.expectRevert("marketplace already set");
        newPolicy.setMarketplace(address(0x1234));
    }

    function testSetPolicy() public {
        vm.prank(operator);
        policy.setPolicy(
            agent,
            1 ether,
            3 ether,
            validAfter,
            validBefore
        );

        (
            address storedOperator,
            uint96 maxSingle,
            uint96 dailyLimit,
            uint64 storedValidAfter,
            uint64 storedValidBefore,
            bool active
        ) = policy.policies(agent);

        assertEq(storedOperator, operator);
        assertEq(maxSingle, 1 ether);
        assertEq(dailyLimit, 3 ether);
        assertEq(storedValidAfter, validAfter);
        assertEq(storedValidBefore, validBefore);
        assertTrue(active);
    }

    function testOnlyOperatorCanUpdatePolicy() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        vm.expectRevert("not operator");
        vm.prank(other);
        policy.setPolicy(agent, 2 ether, 4 ether, validAfter, validBefore);

        vm.prank(operator);
        policy.setPolicy(agent, 2 ether, 4 ether, validAfter, validBefore);

        (, uint96 maxSingle, uint96 dailyLimit, , , ) = policy.policies(agent);
        assertEq(maxSingle, 2 ether);
        assertEq(dailyLimit, 4 ether);
    }

    function testSetApprovedTarget() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        vm.prank(operator);
        policy.setApprovedTarget(agent, target, true);

        assertTrue(policy.approvedTargets(agent, target));
    }

    function testOnlyOperatorCanSetApprovedTarget() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        vm.expectRevert("not operator");
        vm.prank(other);
        policy.setApprovedTarget(agent, target, true);
    }

    function testCheckSpendPasses() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        vm.prank(operator);
        policy.setApprovedTarget(agent, target, true);

        (bool ok, string memory reason) = policy.checkSpend(agent, target, 0.5 ether);
        assertTrue(ok);
        assertEq(reason, "");
    }

    function testCheckSpendFailsUnapprovedTarget() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        (bool ok, string memory reason) = policy.checkSpend(agent, target, 0.5 ether);
        assertFalse(ok);
        assertEq(reason, "target not approved");
    }

    function testCheckSpendFailsMaxSingle() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        vm.prank(operator);
        policy.setApprovedTarget(agent, target, true);

        (bool ok, string memory reason) = policy.checkSpend(agent, target, 2 ether);
        assertFalse(ok);
        assertEq(reason, "amount exceeds max single");
    }

    function testRecordSpendOnlyMarketplace() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        vm.expectRevert("not marketplace");
        policy.recordSpend(agent, 0.5 ether);
    }

    function testRecordSpendAccumulates() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, validAfter, validBefore);

        uint256 dayIndex = block.timestamp / 1 days;

        vm.prank(marketplace);
        policy.recordSpend(agent, 1 ether);

        vm.prank(marketplace);
        policy.recordSpend(agent, 1 ether);

        assertEq(policy.dailySpent(agent, dayIndex), 2 ether);
    }

    function testRecordSpendFailsDailyLimit() public {
        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 2 ether, validAfter, validBefore);

        vm.prank(marketplace);
        policy.recordSpend(agent, 1 ether);

        vm.prank(marketplace);
        policy.recordSpend(agent, 1 ether);

        vm.expectRevert("daily limit exceeded");
        vm.prank(marketplace);
        policy.recordSpend(agent, 1 ether);
    }

    function testCheckSpendFailsWhenNotYetActive() public {
        uint64 futureAfter = uint64(block.timestamp + 1 days);
        uint64 futureBefore = uint64(block.timestamp + 8 days);

        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, futureAfter, futureBefore);

        vm.prank(operator);
        policy.setApprovedTarget(agent, target, true);

        (bool ok, string memory reason) = policy.checkSpend(agent, target, 0.5 ether);
        assertFalse(ok);
        assertEq(reason, "policy not active yet");
    }

    function testCheckSpendFailsWhenExpired() public {
        vm.warp(10 days);
        
        uint64 pastAfter = uint64(block.timestamp - 8 days);
        uint64 pastBefore = uint64(block.timestamp - 1 days);

        vm.prank(operator);
        policy.setPolicy(agent, 1 ether, 3 ether, pastAfter, pastBefore);

        vm.prank(operator);
        policy.setApprovedTarget(agent, target, true);

        (bool ok, string memory reason) = policy.checkSpend(agent, target, 0.5 ether);
        assertFalse(ok);
        assertEq(reason, "policy expired");
    }
}
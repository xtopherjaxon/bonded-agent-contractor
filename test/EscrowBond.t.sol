// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EscrowBond} from "../src/EscrowBond.sol";

contract EscrowBondTest is Test {
    EscrowBond internal escrow;

    address internal marketplace = address(0xA11CE);
    address internal recipient = address(0xBEEF);
    address internal treasury = address(0xCAFE);

    uint256 internal constant JOB_ID = 1;
    uint256 internal constant REWARD = 1 ether;
    uint256 internal constant BOND = 0.2 ether;

    function setUp() public {
        escrow = new EscrowBond();
        escrow.setMarketplace(marketplace);
    }

    function testOnlyOwnerCanSetMarketplace() public {
        EscrowBond newEscrow = new EscrowBond();

        vm.expectRevert("not owner");
        vm.prank(recipient);
        newEscrow.setMarketplace(marketplace);
    }

    function testCannotSetMarketplaceTwice() public {
        EscrowBond newEscrow = new EscrowBond();
        newEscrow.setMarketplace(marketplace);

        vm.expectRevert("marketplace already set");
        newEscrow.setMarketplace(address(0x1234));
    }

    function testFundJobReward() public {
        vm.deal(marketplace, REWARD);

        vm.prank(marketplace);
        escrow.fundJobReward{value: REWARD}(JOB_ID);

        (uint96 amountWei, bool funded, bool released, bool refunded) = escrow.rewards(JOB_ID);

        assertEq(amountWei, REWARD);
        assertTrue(funded);
        assertFalse(released);
        assertFalse(refunded);
    }

    function testCannotFundRewardTwice() public {
        vm.deal(marketplace, REWARD * 2);

        vm.prank(marketplace);
        escrow.fundJobReward{value: REWARD}(JOB_ID);

        vm.expectRevert("reward already funded");
        vm.prank(marketplace);
        escrow.fundJobReward{value: REWARD}(JOB_ID);
    }

    function testReleaseReward() public {
        vm.deal(marketplace, REWARD);

        vm.prank(marketplace);
        escrow.fundJobReward{value: REWARD}(JOB_ID);

        uint256 beforeBal = recipient.balance;

        vm.prank(marketplace);
        escrow.releaseReward(JOB_ID, payable(recipient));

        assertEq(recipient.balance, beforeBal + REWARD);

        (, , bool released, bool refunded) = escrow.rewards(JOB_ID);
        assertTrue(released);
        assertFalse(refunded);
    }

    function testRefundReward() public {
        vm.deal(marketplace, REWARD);

        vm.prank(marketplace);
        escrow.fundJobReward{value: REWARD}(JOB_ID);

        uint256 beforeBal = recipient.balance;

        vm.prank(marketplace);
        escrow.refundReward(JOB_ID, payable(recipient));

        assertEq(recipient.balance, beforeBal + REWARD);

        (, , bool released, bool refunded) = escrow.rewards(JOB_ID);
        assertFalse(released);
        assertTrue(refunded);
    }

    function testPostBond() public {
        vm.deal(marketplace, BOND);

        vm.prank(marketplace);
        escrow.postBond{value: BOND}(JOB_ID, recipient);

        (address bondedAgent, uint96 amountWei, bool posted, bool settled) = escrow.bonds(JOB_ID);

        assertEq(bondedAgent, recipient);
        assertEq(amountWei, BOND);
        assertTrue(posted);
        assertFalse(settled);
    }

    function testReturnBond() public {
        vm.deal(marketplace, BOND);

        vm.prank(marketplace);
        escrow.postBond{value: BOND}(JOB_ID, recipient);

        uint256 beforeBal = recipient.balance;

        vm.prank(marketplace);
        escrow.returnBond(JOB_ID, payable(recipient));

        assertEq(recipient.balance, beforeBal + BOND);

        (, , , bool settled) = escrow.bonds(JOB_ID);
        assertTrue(settled);
    }

    function testSlashBond() public {
        vm.deal(marketplace, BOND);

        vm.prank(marketplace);
        escrow.postBond{value: BOND}(JOB_ID, recipient);

        uint256 beforeBal = treasury.balance;

        vm.prank(marketplace);
        escrow.slashBond(JOB_ID, payable(treasury));

        assertEq(treasury.balance, beforeBal + BOND);

        (, , , bool settled) = escrow.bonds(JOB_ID);
        assertTrue(settled);
    }

    function testOnlyMarketplaceCanFundReward() public {
        vm.deal(address(this), REWARD);

        vm.expectRevert("not marketplace");
        escrow.fundJobReward{value: REWARD}(JOB_ID);
    }

    function testOnlyMarketplaceCanPostBond() public {
        vm.deal(address(this), BOND);

        vm.expectRevert("not marketplace");
        escrow.postBond{value: BOND}(JOB_ID, recipient);
    }

    function testCannotReleaseAfterRefund() public {
        vm.deal(marketplace, REWARD);

        vm.prank(marketplace);
        escrow.fundJobReward{value: REWARD}(JOB_ID);

        vm.prank(marketplace);
        escrow.refundReward(JOB_ID, payable(recipient));

        vm.expectRevert("reward already refunded");
        vm.prank(marketplace);
        escrow.releaseReward(JOB_ID, payable(recipient));
    }

    function testCannotSettleBondTwice() public {
        vm.deal(marketplace, BOND);

        vm.prank(marketplace);
        escrow.postBond{value: BOND}(JOB_ID, recipient);

        vm.prank(marketplace);
        escrow.returnBond(JOB_ID, payable(recipient));

        vm.expectRevert("bond already settled");
        vm.prank(marketplace);
        escrow.slashBond(JOB_ID, payable(treasury));
    }
}
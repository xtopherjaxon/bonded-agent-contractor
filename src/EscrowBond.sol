// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEscrowBond} from "./interfaces/IEscrowBond.sol";

contract EscrowBond is IEscrowBond {
    address public owner;
    address public marketplace;

    mapping(uint256 => RewardEscrow) public rewards;
    mapping(uint256 => BondEscrow) public bonds;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyMarketplace() {
        require(msg.sender == marketplace, "not marketplace");
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

    function fundJobReward(uint256 jobId) external payable onlyMarketplace {
        require(jobId != 0, "invalid job id");
        require(msg.value > 0, "no reward value");

        RewardEscrow storage reward = rewards[jobId];
        require(!reward.funded, "reward already funded");

        reward.amountWei = uint96(msg.value);
        reward.funded = true;
        reward.released = false;
        reward.refunded = false;

        emit RewardFunded(jobId, uint96(msg.value));
    }

    function postBond(uint256 jobId, address bondedAgent) external payable onlyMarketplace {
        require(jobId != 0, "invalid job id");
        require(bondedAgent != address(0), "zero bonded agent");
        require(msg.value > 0, "no bond value");

        BondEscrow storage bond = bonds[jobId];
        require(!bond.posted, "bond already posted");

        bond.bondedAgent = bondedAgent;
        bond.amountWei = uint96(msg.value);
        bond.posted = true;
        bond.settled = false;

        emit BondPosted(jobId, bondedAgent, uint96(msg.value));
    }

    function releaseReward(uint256 jobId, address payable to) external onlyMarketplace {
        require(to != address(0), "zero recipient");

        RewardEscrow storage reward = rewards[jobId];
        require(reward.funded, "reward not funded");
        require(!reward.released, "reward already released");
        require(!reward.refunded, "reward already refunded");

        reward.released = true;

        (bool ok, ) = to.call{value: reward.amountWei}("");
        require(ok, "reward transfer failed");

        emit RewardReleased(jobId, to, reward.amountWei);
    }

    function refundReward(uint256 jobId, address payable to) external onlyMarketplace {
        require(to != address(0), "zero recipient");

        RewardEscrow storage reward = rewards[jobId];
        require(reward.funded, "reward not funded");
        require(!reward.released, "reward already released");
        require(!reward.refunded, "reward already refunded");

        reward.refunded = true;

        (bool ok, ) = to.call{value: reward.amountWei}("");
        require(ok, "reward refund failed");

        emit RewardRefunded(jobId, to, reward.amountWei);
    }

    function returnBond(uint256 jobId, address payable to) external onlyMarketplace {
        require(to != address(0), "zero recipient");

        BondEscrow storage bond = bonds[jobId];
        require(bond.posted, "bond not posted");
        require(!bond.settled, "bond already settled");

        bond.settled = true;

        (bool ok, ) = to.call{value: bond.amountWei}("");
        require(ok, "bond return failed");

        emit BondReturned(jobId, to, bond.amountWei);
    }

    function slashBond(uint256 jobId, address payable treasury) external onlyMarketplace {
        require(treasury != address(0), "zero treasury");

        BondEscrow storage bond = bonds[jobId];
        require(bond.posted, "bond not posted");
        require(!bond.settled, "bond already settled");

        bond.settled = true;

        (bool ok, ) = treasury.call{value: bond.amountWei}("");
        require(ok, "bond slash failed");

        emit BondSlashed(jobId, treasury, bond.amountWei);
    }
}
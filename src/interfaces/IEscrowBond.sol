// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBondedTypes} from "./IBondedTypes.sol";

interface IEscrowBond is IBondedTypes {
    event RewardFunded(uint256 indexed jobId, uint96 amountWei);
    event BondPosted(uint256 indexed jobId, address indexed agent, uint96 amountWei);
    event RewardReleased(uint256 indexed jobId, address indexed to, uint96 amountWei);
    event RewardRefunded(uint256 indexed jobId, address indexed to, uint96 amountWei);
    event BondReturned(uint256 indexed jobId, address indexed to, uint96 amountWei);
    event BondSlashed(uint256 indexed jobId, address indexed treasury, uint96 amountWei);

    function marketplace() external view returns (address);

    function rewards(uint256 jobId) external view returns (
        uint96 amountWei,
        bool funded,
        bool released,
        bool refunded
    );

    function bonds(uint256 jobId) external view returns (
        address bondedAgent,
        uint96 amountWei,
        bool posted,
        bool settled
    );

    function fundJobReward(uint256 jobId) external payable;
    function postBond(uint256 jobId, address bondedAgent) external payable;

    function releaseReward(uint256 jobId, address payable to) external;
    function refundReward(uint256 jobId, address payable to) external;
    function returnBond(uint256 jobId, address payable to) external;
    function slashBond(uint256 jobId, address payable treasury) external;
}
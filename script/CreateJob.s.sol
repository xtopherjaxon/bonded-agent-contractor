// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";
import "../src/JobMarketplace.sol";

contract CreateJob is Script {
    uint256 humanPk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address human = vm.addr(humanPk);

    function run() external {
        address marketplace = 0x66Db6d191cd163F56197b767928A507dF8b47AA7;

        vm.broadcast(humanPk);
        JobMarketplace(marketplace).createJob{value: 1 ether}(
            keccak256("eth_market_report"),
            "ipfs://new-report",
            1 ether,
            uint64(block.timestamp + 1 days)
        );
    }
}


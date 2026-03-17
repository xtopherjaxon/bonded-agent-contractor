// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";

import {JobMarketplace} from "../src/JobMarketplace.sol";
import {AgentDirectory} from "../src/AgentDirectory.sol";
import {EscrowBond} from "../src/EscrowBond.sol";
import {SpendingPolicy} from "../src/SpendingPolicy.sol";

contract DeployContracts is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        EscrowBond escrow = new EscrowBond();
        AgentDirectory directory = new AgentDirectory();
        SpendingPolicy policy = new SpendingPolicy();

        JobMarketplace marketplace = new JobMarketplace(
            address(directory),
            address(escrow),
            address(policy),
            deployer
        );

        escrow.setMarketplace(address(marketplace));
        directory.setMarketplace(address(marketplace));
        policy.setMarketplace(address(marketplace));

        vm.stopBroadcast();

        console2.log("EscrowBond:", address(escrow));
        console2.log("AgentDirectory:", address(directory));
        console2.log("SpendingPolicy:", address(policy));
        console2.log("JobMarketplace:", address(marketplace));
    }
}
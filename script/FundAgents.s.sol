// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";

contract FundAgents is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        uint256 mainPk = vm.envUint("MAIN_AGENT_PK");
        uint256 pricePk = vm.envUint("PRICE_AGENT_PK");
        uint256 volumePk = vm.envUint("VOLUME_AGENT_PK");
        uint256 yieldPk = vm.envUint("YIELD_AGENT_PK");

        address mainAgent = vm.addr(mainPk);
        address priceAgent = vm.addr(pricePk);
        address volumeAgent = vm.addr(volumePk);
        address yieldAgent = vm.addr(yieldPk);

        vm.startBroadcast(deployerPk);

        _send(payable(mainAgent), 0.00002 ether);
        _send(payable(priceAgent), 0.00001 ether);
        _send(payable(volumeAgent), 0.00001 ether);
        _send(payable(yieldAgent), 0.00001 ether);

        vm.stopBroadcast();

        console2.log("Funded main:", mainAgent);
        console2.log("Funded price:", priceAgent);
        console2.log("Funded volume:", volumeAgent);
        console2.log("Funded yield:", yieldAgent);
    }

    function _send(address payable to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "funding failed");
    }
}
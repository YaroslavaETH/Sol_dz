// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/script.sol";
import {CloneWeValue} from "src/CloneWeValue.sol";

/**
 * @title DeployCloneWeValue
 * @notice Скрипт для развертывания фабрики клонов CloneWeValue в сети.
 *
 * Запуск:
 * forge script script/DeployCloneWeValue.s.sol:DeployCloneWeValue --rpc-url mainnet/sepolia --broadcast --verify -vv
 */
contract DeployCloneWeValue is Script {
    function run() external {
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployerAddress = vm.addr(uint256(deployerPrivateKeyBytes));

        console.log("Deploying CloneWeValue factory ...");
        console.log("Deployer address:", deployerAddress);

        vm.startBroadcast(uint256(deployerPrivateKeyBytes));
        CloneWeValue factory = new CloneWeValue(deployerAddress);
        vm.stopBroadcast();

        console.log("CloneWeValue factory deployed at:", address(factory));
    }
}

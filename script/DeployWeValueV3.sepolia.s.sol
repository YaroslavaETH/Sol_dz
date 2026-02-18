// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {WeValue} from "src/WeValue_v3.sol";


/**
 * @title UpgradeWeValueSepolia
 * @notice Скрипт для обновления реализации существующего прокси-контракта WeValue.
 *
 * Запуск:
 * forge script script/DeployWeValueV3.sepolia.s.sol:DeployWeValueV3 --rpc-url sepolia --broadcast --verify -vv
 */
contract DeployWeValueV3 is Script {
    function run() external {
        // Адреса из .env или прямо здесь
        address multiSigAddress = vm.envAddress("MULTISIG_ADDRESS");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployer = vm.addr(uint256(deployerPrivateKeyBytes));
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(uint256(deployerPrivateKeyBytes));
        
        // ========== Деплоим новую имплементацию ==========
        console.log("\n--- Deploying new implementation ---");
        WeValue newImplementation = new WeValue();
        console.log("New implementation:", address(newImplementation));
        
        vm.stopBroadcast();
    }
}
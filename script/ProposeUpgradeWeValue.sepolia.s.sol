// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {WeValue} from "src/WeValue_v3.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

/**
 * @title ProposeUpgradeWeValue
 * @notice Предложить upgrade WeValue через MultiSig
 * 
 * Запуск (создает транзакцию в мультисиге):
 * forge script script/ProposeUpgradeWeValue.sepolia.s.sol:ProposeUpgradeWeValue --rpc-url sepolia --broadcast -vv
 */
contract ProposeUpgradeWeValue is Script {
    function run() external {
        // Адреса из .env или прямо здесь
        address multiSigAddress = vm.envAddress("MULTISIG_ADDRESS");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployer = vm.addr(uint256(deployerPrivateKeyBytes));
        
        console.log("=== Propose Upgrade WeValue via MultiSig ===");
        console.log("MultiSig:", multiSigAddress);
        console.log("Proxy:", proxyAddress);
        console.log("Proposer:", deployer);
        
        // Проверяем что deployer - владелец мультисига
        MultiSigWallet multiSig = MultiSigWallet(payable(multiSigAddress));
        require(multiSig.isOwner(deployer), "Not a MultiSig owner");
        
        vm.startBroadcast(uint256(deployerPrivateKeyBytes));
        
        // ========== Деплоим новую имплементацию ==========
        console.log("\n--- Deploying new implementation ---");
        WeValue newImplementation = new WeValue();
        console.log("New implementation:", address(newImplementation));
        
        // ========== Подготавливаем данные для upgrade ==========
        bytes memory upgradeData = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(newImplementation),
            "" // Пустые данные если не нужна реинициализация
        );
        
        // ========== Предлагаем транзакцию в мультисиг ==========
        console.log("\n--- Proposing transaction to MultiSig ---");
        uint256 txId = multiSig.proposeTransaction(
            proxyAddress,
            0, // value
            upgradeData,
            string(abi.encodePacked(
                "Upgrade WeValue to ",
                vm.toString(address(newImplementation))
            ))
        );
        
        console.log("Transaction proposed with ID:", txId);
        console.log("Confirmations needed:", multiSig.required());
        
        vm.stopBroadcast();
        
        console.log("\n Upgrade transaction proposed!");
        console.log("Other owners must confirm transaction ID:", txId);
    }
}

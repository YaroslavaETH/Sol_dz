// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {WeValue as WeValueV1} from "src/WeValue_v1.sol";
import {WeValue} from "src/WeValue_v2.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


/**
 * @title UpgradeWeValueSepolia
 * @notice Скрипт для обновления реализации существующего прокси-контракта WeValue.
 *
 * Запуск:
 * forge script script/UpgradeWeValue.sepolia.s.sol:UpgradeWeValueToV2Sepolia --rpc-url sepolia --broadcast --verify -vv
 */
contract UpgradeWeValueToV2Sepolia is Script {
    // Адрес существующего прокси в Sepolia
    address constant PROXY_ADDRESS = 0x9dECFb688Cc336442A581D280e748a0909348A45;
    
    // Адреса контрактов Uniswap в Sepolia
    address constant UNISWAP_ROUTER_SEPOLIA = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b; 
    address constant PERMIT2_SEPOLIA = 0x000000000022D473030F116dDEE9F6B43aC78BA3; 

    function run() external {
        // Получаем приватный ключ владельца из переменных окружения
        bytes32 ownerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address ownerAddress = vm.addr(uint256(ownerPrivateKeyBytes));

        console.log("=== Upgrade WeValue to V2 on Sepolia ===");
        console.log("Owner address:", ownerAddress);
        console.log("Proxy address:", PROXY_ADDRESS);
        console.log("Uniswap Router:", UNISWAP_ROUTER_SEPOLIA);
        console.log("Permit2:", PERMIT2_SEPOLIA);

        // Проверяем текущую версию
        WeValue proxy = WeValue(payable(PROXY_ADDRESS));
        string memory currentVersion = proxy.version();
        console.log("Current version:", currentVersion);

        // Проверяем, что мы владельцы
        address currentOwner = proxy.owner();
        require(currentOwner == ownerAddress, "You are not the owner of the proxy");
        console.log("Owner verified!");

        // Начинаем трансляцию транзакций в сеть
        vm.startBroadcast(uint256(ownerPrivateKeyBytes));

        // 1. Деплоим новую реализацию v2
        console.log("\n--- Step 1: Deploying WeValue V2 implementation ---");
        WeValue implementationV2 = new WeValue();
        console.log("Implementation V2 deployed at:", address(implementationV2));

        // 2. Обновляем прокси на новую реализацию
        console.log("\n--- Step 2: Upgrading proxy to V2 ---");
        // upgradeToAndCall позволяет обновить и сразу вызвать функцию инициализации
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initializeV2.selector,
            UNISWAP_ROUTER_SEPOLIA,
            PERMIT2_SEPOLIA
        );
        
        proxy.upgradeToAndCall(address(implementationV2), initData);
        console.log("Proxy upgraded to V2!");

        // 3. Проверяем новую версию
        console.log("\n--- Step 3: Verifying upgrade ---");
        string memory newVersion = proxy.version();
        console.log("New version:", newVersion);
        
        // Проверяем, что роутер установлен
        address routerAddress = address(proxy.router());
        console.log("Router address:", routerAddress);
        require(routerAddress == UNISWAP_ROUTER_SEPOLIA, "Router not set correctly");
        
        // Проверяем, что permit2 установлен
        address permit2Address = address(proxy.permit2());
        console.log("Permit2 address:", permit2Address);
        require(permit2Address == PERMIT2_SEPOLIA, "Permit2 not set correctly");

        console.log("\n=== Upgrade completed successfully! ===");
        console.log("Proxy:", PROXY_ADDRESS);
        console.log("New Implementation:", address(implementationV2));
        console.log("Version:", newVersion);

        // Завершаем трансляцию
        vm.stopBroadcast();
    }
}
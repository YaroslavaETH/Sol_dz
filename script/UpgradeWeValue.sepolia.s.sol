// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {WeValue} from "src/WeValue_v2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/**
 * @title UpgradeWeValueSepolia
 * @notice Скрипт для обновления реализации существующего прокси-контракта WeValue.
 *
 * Запуск:
 * forge script script/UpgradeWeValue.sepolia.s.sol:UpgradeWeValueSepolia --rpc-url sepolia --broadcast --verify -vv
 */
contract UpgradeWeValueSepolia is Script {
    // Адреса из деплоя (замените на актуальные, если нужно)
    address payable constant PROXY_ADDRESS = payable(0x9dECFb688Cc336442A581D280e748a0909348A45);  // ваш прокси
    address payable constant CURRENT_IMPLEMENTATION_ADDRESS = payable(0x768e550f12ab040bc2A5EC86Ac6335B3396F4975);  // текущая имплементация V1


    function run() external {
        // Получаем приватный ключ из переменных окружения
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployer = vm.addr(uint256(deployerPrivateKeyBytes));

        console.log("Deployer address: ", deployer);

        vm.startBroadcast(uint256(deployerPrivateKeyBytes));

        // Читаем текущую имплементацию
        address currentImpl = getImplementation(PROXY_ADDRESS);
        console.log("Current proxy implementation: ", currentImpl);

        // Проверки безопасности
        require(currentImpl == CURRENT_IMPLEMENTATION_ADDRESS, "Current implementation is wrong");

        console.log("Deploying new WeValue implementation for Sepolia...");
        WeValue newImplementation = new WeValue();
        address newImplAddress = address(newImplementation);
        console.log("New implementation deployed at: ", newImplAddress);

        // Проверка: новая имплементация ≠ текущая
        require(newImplAddress != currentImpl, "New implementation equals current");

        // Обновляем прокси через low-level call (надёжнее, чем ABI)
        console.log("Upgrading proxy to new implementation...");
        // (bool success, ) = PROXY_ADDRESS.call(
        //     abi.encodeWithSelector(
        //     UUPSUpgradeable.upgradeToAndCall.selector,
        //     newImplAddress, new bytes(0)));
        WeValue proxy = WeValue(PROXY_ADDRESS);
        proxy.upgradeToAndCall(newImplAddress, new bytes(0));
        

        vm.stopBroadcast();

        // Проверка после транзакций
        address updatedImpl = getImplementation(PROXY_ADDRESS);
        require(updatedImpl == newImplAddress, "Upgrade verification failed");
        console.log("Proxy upgraded successfully!");
        console.log("New implementation: ", updatedImpl);
    }

    /**
     * @notice Читает адрес имплементации из слота ERC1967 прокси.
     * @param proxy Адрес прокси-контракта
     * @return Адрес текущей имплементации
     */
    function getImplementation(address proxy) private view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        return address(uint160(uint256(vm.load(proxy, slot))));
    }
}
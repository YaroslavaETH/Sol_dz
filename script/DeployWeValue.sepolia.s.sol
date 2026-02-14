// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/script.sol";
import {WeValue} from "src/WeValue_v1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployWeValueSepolia
 * @notice Скрипт для развертывания контракта WeValue и его прокси в сети Sepolia.
 *
 * Запуск:
 * forge script script/DeployWeValue.sepolia.s.sol:DeployWeValueSepolia --rpc-url sepolia --broadcast --verify -vv
 */
contract DeployWeValueSepolia is Script {
    function run() external {
        // Получаем приватный ключ деплоера из переменных окружения
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployerAddress = vm.addr(uint256(deployerPrivateKeyBytes));

        // Адреса контрактов в сети Sepolia
        // ВНИМАНИЕ: Некоторые адреса являются заглушками, т.к. реальных аналогов в Sepolia нет.
        address aavePool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Aave V3 Pool в Sepolia
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC (Protected Asset)
        address dai = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;  // DAI (Safe Asset)
        address usdcUsdOracle = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E; // Chainlink USDC/USD
        address daiUsdOracle = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;  // Chainlink DAI/USD

        // Порог отвязки, например, $0.95 с 8 знаками после запятой
        uint256 depegThreshold = 95_000_000;

        // Начинаем трансляцию транзакций в сеть
        vm.startBroadcast(uint256(deployerPrivateKeyBytes));

        // Деплоим контракт реализации
        console.log("Deploying WeValue implementation for Sepolia...");
        WeValue implementation = new WeValue();
        console.log("Implementation deployed at:", address(implementation));

        // Готовим данные для инициализации прокси
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            deployerAddress, 
            aavePool,
            usdcUsdOracle,
            usdc,
            daiUsdOracle,
            dai,
            depegThreshold
        );

        // Деплоим прокси и инициализируем его
        console.log("Deploying ERC1967Proxy for Sepolia...");
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy for WeValue deployed at:", address(proxy));

        // Завершаем трансляцию
        vm.stopBroadcast();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/script.sol";
import {WeValue} from "src/WeValue.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployWeValueMainnet
 * @notice Скрипт для развертывания контракта WeValue и его прокси в сети Mainnet.
 *
 * Запуск:
 * forge script script/DeployWeValue.s.sol:DeployWeValue --rpc-url mainnet --broadcast --verify
 */
contract DeployWeValueMainnet is Script {
    function run() external {
        // Получаем приватный ключ деплоера из переменных окружения
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployerAddress = vm.addr(uint256(deployerPrivateKeyBytes));

        // Адреса контрактов в сети Mainnet
        address aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Aave V3 Pool
        address oneInchRouter = 0x1111111254EEB25477B68fb85Ed929f73A960582; // 1inch Aggregation Router v5
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (Protected Asset)
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;  // DAI (Safe Asset)
        address usdcUsdOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // Chainlink USDC/USD
        address daiUsdOracle = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;  // Chainlink DAI/USD
        address trustedForwarder = deployerAddress; // Для примера используем адрес деплоера

        // Порог отвязки, например, $0.95 с 8 знаками после запятой
        uint256 depegThreshold = 95_000_000;

        // Начинаем трансляцию транзакций в сеть
        vm.startBroadcast(uint256(deployerPrivateKeyBytes));

        // Деплоим контракт реализации
        console.log("Deploying WeValue implementation...");
        WeValue implementation = new WeValue();
        console.log("Implementation deployed at:", address(implementation));

        // Готовим данные для инициализации прокси
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            deployerAddress, // initialOwner
            trustedForwarder,
            aavePool,
            oneInchRouter,
            usdcUsdOracle,
            usdc,
            daiUsdOracle,
            dai,
            depegThreshold
        );

        // Деплоим прокси и инициализируем его
        console.log("Deploying ERC1967Proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy for WeValue deployed at:", address(proxy));

        // Завершаем трансляцию
        vm.stopBroadcast();
    }
}
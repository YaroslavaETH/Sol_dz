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
 * forge script script/UpgradeWeValue.sepolia.s.sol:UpgradeWeValueSepolia --rpc-url sepolia --broadcast --verify -vv
 */
contract UpgradeWeValueSepolia is Script {

    // address payable constant PROXY_ADDRESS = payable(0x9dECFb688Cc336442A581D280e748a0909348A45);  // прокси
    // address payable constant CURRENT_IMPLEMENTATION_ADDRESS = payable(0x768e550f12ab040bc2A5EC86Ac6335B3396F4975);  // текущая имплементация V1
    address constant UNISWAP_4_ROUTER = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b; 
    bytes public constant DATA_INIT_V2 = abi.encodeWithSelector(
            WeValue.initializeV2.selector,
            UNISWAP_4_ROUTER);


        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployer = vm.addr(uint256(deployerPrivateKeyBytes));
        // Адреса контрактов в сети Sepolia
        address aavePool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Aave V3 Pool е развернут в Sepolia
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC (Protected Asset)
        address dai = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;  // DAI (Safe Asset)
        address usdcUsdOracle = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E; // Chainlink USDC/USD
        address daiUsdOracle = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;  // Chainlink DAI/USD
          // Порог отвязки, например, $0.95 с 8 знаками после запятой
        uint256 depegThreshold = 95_000_000;

    function run() external {
        // // Получаем приватный ключ из переменных окружения
        // bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        // address deployer = vm.addr(uint256(deployerPrivateKeyBytes));

        console.log("Deployer address: ", deployer);

        vm.startBroadcast(uint256(deployerPrivateKeyBytes));
        // Деплоим контракт реализации
        console.log("Deploying WeValue implementation for Sepolia...");
        WeValueV1 implementation = new WeValueV1();
        console.log("Implementation deployed at:", address(implementation));

        // Готовим данные для инициализации прокси
        bytes memory initData = abi.encodeWithSelector(
            WeValueV1.initialize.selector,
            deployer, 
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
        address payable PROXY_ADDRESS = payable(address(proxy));


        // Читаем текущую имплементацию
        address currentImpl = getImplementation(PROXY_ADDRESS);
        console.log("Current proxy implementation: ", currentImpl);

        // Проверки безопасности
        // require(currentImpl == CURRENT_IMPLEMENTATION_ADDRESS, "Current implementation is wrong");

        console.log("Deploying new WeValue implementation for Sepolia...");
        WeValue newImplementation = new WeValue();
        address newImplAddress = address(newImplementation);

        console.log("New implementation deployed at: ", newImplAddress);

        // Проверка: новая имплементация ≠ текущая
        require(newImplAddress != currentImpl, "New implementation equals current");

        console.log("Current owner proxy: ", WeValue(PROXY_ADDRESS).owner());

        // Обновляем прокси через low-level call (надёжнее, чем ABI)
        console.log("Upgrading proxy to new implementation...");
        // (bool success, ) = PROXY_ADDRESS.call(
        //     abi.encodeWithSelector(
        //     UUPSUpgradeable.upgradeToAndCall.selector,
        //     newImplAddress, new bytes(0)));
        
        UUPSUpgradeable(PROXY_ADDRESS).upgradeToAndCall(newImplAddress, DATA_INIT_V2);
        

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
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/script.sol";
import {WeValue} from "src/WeValue_v2.sol";
import {CloneWeValue} from "src/CloneWeValue.sol";

/**
 * @title CreateCloneSepolia
 * @notice Скрипт для создания нового клона WeValue через фабрику и его инициализации.
 *
 * Запуск:
 * forge script script/CreateClone.sepolia.s.sol:CreateCloneSepolia --rpc-url sepolia --broadcast -vv
 */
contract CreateCloneSepolia is Script {
    address private constant FACTORY_ADDRESS = 0x0CD517ba2C211BB1bA3a33CC959FF8764EaE39af;
    // address private constant IMPLEMENTATION_ADDRESS = 0x768e550f12ab040bc2A5EC86Ac6335B3396F4975;
    bytes32 private constant SALT = keccak256("MyFirstFund");
    address private constant AAVE_POOL = address(0);
    address private constant ONE_INCH_ROUTER = address(0);
    address private constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address private constant DAI = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
    address private constant USDC_USD_ORACLE = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
    address private constant DAI_USD_ORACLE = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    uint256 private constant DEPEG_THRESHOLD = 95_000_000;

    function run() external {
        // Параметры для инициализации нового фонда
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address newOwner = vm.addr(uint256(deployerPrivateKeyBytes)); // Владелец нового фонда
        address trustedForwarder = newOwner; // Для примера используем адрес деплоера

        // Выполнение
        console.log("Creating a new WeValue clone...");
        CloneWeValue factory = CloneWeValue(FACTORY_ADDRESS);

        vm.startBroadcast(uint256(deployerPrivateKeyBytes));
 
        // т.к. не удается пока задеплоить новую версию имплементации через прокси, задеплоим ее отдельно
        address IMPLEMENTATION_ADDRESS = address(new WeValue());
        console.log("Implementation deployed at:", IMPLEMENTATION_ADDRESS);

        // Создаем клон
        address cloneAddress = factory.deployWeValue(IMPLEMENTATION_ADDRESS, SALT);

        // Инициализируем клон
        WeValue newClone = WeValue(payable(cloneAddress));
        newClone.initialize(
            "My First WeValue Fund", // Новое имя
            "MFWF",                  // Новый символ
            newOwner,
            trustedForwarder,
            AAVE_POOL,
            ONE_INCH_ROUTER,
            USDC_USD_ORACLE,
            USDC,
            DAI_USD_ORACLE,
            DAI,
            DEPEG_THRESHOLD
        );

        vm.stopBroadcast();

        console.log("Successfully deployed and initialized new WeValue clone at:", cloneAddress);
    }
}
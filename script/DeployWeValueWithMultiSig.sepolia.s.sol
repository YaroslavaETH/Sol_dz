// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {WeValue} from "src/WeValue_v2.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployWeValueWithMultiSig
 * @notice Скрипт для развертывания WeValue с мультисиг управлением в Sepolia
 * 
 * Запуск:
 * forge script script/DeployWeValueWithMultiSig.sepolia.s.sol:DeployWeValueWithMultiSig --rpc-url sepolia --broadcast --verify -vv
 */
contract DeployWeValueWithMultiSig is Script {
    function run() external {
        bytes32 deployerPrivateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        address deployerAddress = vm.addr(uint256(deployerPrivateKeyBytes));

        console.log("=== Deploy WeValue with MultiSig (Sepolia) ===");
        console.log("Deployer:", deployerAddress);
        console.log("Block:", block.number);

        // ========== НАСТРОЙКА ВЛАДЕЛЬЦЕВ МУЛЬТИСИГА ==========
        address[] memory multisigOwners = new address[](3);
        multisigOwners[0] = deployerAddress;
        multisigOwners[1] = 0x0054A08c2ee3de66a5cF10e3a348fc4C38e2352d;
        multisigOwners[2] = 0x33D74Ef78b83cE41FA98F7B987a48FD174e68eA9;
        
        uint256 requiredConfirmations = 2; // 2 из 3
        
        console.log("\nMultiSig configuration:");
        console.log("Owners count:", multisigOwners.length);
        console.log("Required confirmations:", requiredConfirmations);
        for (uint256 i = 0; i < multisigOwners.length; i++) {
            console.log("  Owner", i + 1, ":", multisigOwners[i]);
        }
        
        // ========== АДРЕСА SEPOLIA ==========
        address aavePool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC Sepolia
        address wbtc = 0xD0684a311F47AD7fdFf03951d7b91996Be9326E1;  // wbtc Sepolia
        address usdcUsdOracle = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
        address btcUsdOracle = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        address uniswapRouter = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b; // Universal Router
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        
        uint256 depegThreshold = 95_000_000; // $0.95

        vm.startBroadcast(uint256(deployerPrivateKeyBytes));

        // ========== ШАГ 1: MultiSigWallet ==========
        console.log("\n--- Deploying MultiSigWallet ---");
        MultiSigWallet multiSig = new MultiSigWallet(multisigOwners, requiredConfirmations);
        console.log("MultiSigWallet:", address(multiSig));

        // ========== ШАГ 2: WeValue Implementation ==========
        console.log("\n--- Deploying WeValue implementation ---");
        WeValue implementation = new WeValue();
        console.log("WeValue implementation:", address(implementation));

        // ========== ШАГ 3: Initialize data ==========
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            address(multiSig), // Owner = MultiSig!
            aavePool,
            usdcUsdOracle,
            usdc,
            btcUsdOracle,
            wbtc,
            depegThreshold,
            uniswapRouter,
            permit2
        );

        // ========== ШАГ 4: Proxy ==========
        console.log("\n--- Deploying ERC1967Proxy ---");
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy (WeValue):", address(proxy));

        // ========== ШАГ 5: Verify ==========
        console.log("\n--- Verifying setup ---");
        WeValue weValue = WeValue(payable(address(proxy)));
        
        console.log("WeValue owner:", weValue.owner());
        console.log("Is owner MultiSig?", weValue.owner() == address(multiSig));
        console.log("Protected asset:", address(weValue.protectedAsset()));
        console.log("Safe asset:", address(weValue.safeAsset()));

        vm.stopBroadcast();

        // ========== SUMMARY ==========
        console.log("\n=== Deployment Summary ===");
        console.log("MultiSigWallet:", address(multiSig));
        console.log("WeValue Implementation:", address(implementation));
        console.log("WeValue Proxy:", address(proxy));
          console.log("\n Deployment successful!");
    }
}

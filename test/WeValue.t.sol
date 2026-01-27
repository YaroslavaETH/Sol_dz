// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Test, console} from "forge-std/Test.sol";
import {WeValue} from "../src/WeValue.sol";
import {MockERC20, MockAggregatorV3, MockOneInchRouter, MockAavePool} from "test/mocks/Mocks.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WeValueTest is Test {
    // --- Пользователи ---
    address owner;
    uint256 keyOwner;
    address alice;
    uint256 keyAlice;
    address bob;
    uint256 keyBob;
    address trustedForwarder;

    // --- Контракты ---
    WeValue weValue; // Это будет адрес прокси
    WeValue implementation; // Контракт реализации

    // --- Моки ---
    MockAavePool mockAavePool;
    MockOneInchRouter mockOneInchRouter;
    MockAggregatorV3 mockPriceOracle;
    MockAggregatorV3 mockSafeAssetPriceOracle;
    MockERC20 mockProtectedAsset; 
    MockERC20 mockSafeAsset; 
    MockERC20 mockSafeAsset2;      

    /// @dev Настраивает тестовое окружение перед каждым тест-кейсом.
    function setUp() public {
        // Инициализируем пользователей
        (owner, keyOwner) = makeAddrAndKey("owner");
        (alice, keyAlice) = makeAddrAndKey("alice");
        (bob, keyBob) = makeAddrAndKey("bob");
        trustedForwarder = makeAddr("trustedForwarder");

        // 1. Развертывание моков
        mockProtectedAsset = new MockERC20("Mock USDC", "mUSDC");
        mockSafeAsset = new MockERC20("Mock DAI", "mDAI");
        mockSafeAsset2 = new MockERC20("Mock PAXG", "mPAXG");
        mockAavePool = new MockAavePool();
        // Для мока 1inch нам не нужен реальный WETH, просто любой адрес
        mockOneInchRouter = new MockOneInchRouter(address(0), address(mockProtectedAsset));
        mockPriceOracle = new MockAggregatorV3();
        mockSafeAssetPriceOracle = new MockAggregatorV3();
        
        
        // 2. Развертывание реализации и прокси
        implementation = new WeValue();
        
        // Подготовка данных для инициализации
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            owner,
            trustedForwarder,
            address(mockAavePool),
            address(mockOneInchRouter),
            address(mockPriceOracle),
            address(mockProtectedAsset),
            address(mockSafeAssetPriceOracle),
            address(mockSafeAsset),
            95_000_000 // depegThreshold (порог отвязки, например, $0.95 с 8 знаками после запятой)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        weValue = WeValue(payable(address(proxy)));

        // Устанавливаем начальный баланс ETH для пользователей
        vm.deal(alice, 10 ether);
        vm.deal(bob, 1 ether); // Даем Бобу немного ETH на газ
        vm.deal(trustedForwarder, 1 ether); // Даем доверенному отправителю ETH на газ
    }

    // --- Тест-кейсы ---

    /// @dev Тестирует, что контракт инициализирован с правильными значениями.
    function test_Initialization() public view {
        assertEq(weValue.name(), "WeValue", "Incorrect token name");
        assertEq(weValue.symbol(), "WEVALUE", "Incorrect token symbol");
        assertEq(weValue.owner(), owner, "Incorrect owner");
        assertEq(weValue.trustedForwarder(), trustedForwarder, "Incorrect trusted forwarder");
        assertEq(address(weValue.AAVE_POOL()), address(mockAavePool), "Incorrect Aave pool address");
        assertEq(address(weValue.ONE_INCH_ROUTER()), address(mockOneInchRouter), "Incorrect 1inch router address");
        assertEq(address(weValue.PRICE_ORACLE()), address(mockPriceOracle), "Incorrect price oracle address");
        assertEq(address(weValue.PROTECTED_ASSET()), address(mockProtectedAsset), "Incorrect protected asset address");
        assertEq(address(weValue.SAFE_ASSET_PRICE_ORACLE()), address(mockSafeAssetPriceOracle), "Incorrect safe asset price oracle address");
        assertEq(address(weValue.SAFE_ASSET()), address(mockSafeAsset), "Incorrect safe asset address");
        assertEq(weValue.depegThreshold(), 95_000_000, "Incorrect depeg threshold");
        assertEq(weValue.version(), "1.0", "Incorrect version");
    }

    /// @dev Тестирует успешное пожертвование.
    function test_Donation_Success() public {
        uint256 donationAmount = 1 ether;
        
        // Ожидаем событие Donation.
        vm.expectEmit();
        emit WeValue.Donation(alice, donationAmount);

        // Алиса делает пожертвование
        vm.prank(alice);
        weValue.donation{value: donationAmount}();

        // Проверяем балансы
        assertEq(weValue.balanceOf(alice), donationAmount, "Alice's balance should match donation amount");
        assertEq(address(weValue).balance, donationAmount, "Contract ETH balance should match donation amount");
    }

    /// @dev Тестирует, что пожертвование 0 ETH вызывает revert.
    function test_Donation_RevertNull() public {
        // Ожидаем revert с пользовательской ошибкой NullDonation
        vm.expectRevert(abi.encodeWithSelector(WeValue.NullDonation.selector, alice));
        
        // Алиса пытается пожертвовать 0 ETH
        vm.prank(alice);
        weValue.donation{value: 0}();
    }

    /// @dev Тестирует мета-транзакцию для функции donation.
    function test_donation_MetaTX() public {
        uint256 donationAmount = 1 ether;

        // Ожидаем событие Donation, где account это Алиса.
        vm.expectEmit();
        emit WeValue.Donation(alice, donationAmount);

        // trustedForwarder отправляет транзакцию от имени Алисы.
        bytes memory data = abi.encodePacked(weValue.donation.selector, alice);
        vm.prank(trustedForwarder);
        (bool success, ) = address(weValue).call{value: donationAmount}(data);
        assertTrue(success, "Meta-transaction call failed");

        // Токены должны быть зачислены на счет Алисы.
        assertEq(weValue.balanceOf(alice), donationAmount, "Alice should receive tokens in meta-tx");
        assertEq(weValue.balanceOf(bob), 0, "Bob (relayer) should not receive any tokens");
        assertEq(address(weValue).balance, donationAmount, "Contract ETH balance should match meta-tx donation");
    }
    
    /// @dev Тестирует успешную конвертацию ETH в защищенный актив.
    function test_ConvertEthToProtectedAsset_Success() public {
        // --- Подготовка ---
        uint256 ethToConvert = 2 ether;
        uint256 expectedProtectedAssetAmount = 2000 * 1e6; // Ожидаем 2000 USDC (6 знаков)

        // 1. Отправляем ETH на контракт WeValue
        vm.deal(address(weValue), ethToConvert);
        assertEq(address(weValue).balance, ethToConvert, "Initial ETH balance on contract is incorrect");

        // 2. Выпускаем токены для мока 1inch, чтобы он мог их "вернуть"
        mockProtectedAsset.mint(address(mockOneInchRouter), expectedProtectedAssetAmount);

        // --- Действие ---
        // Ожидаем событие EthConverted
        vm.expectEmit();
        emit WeValue.EthConverted(ethToConvert, expectedProtectedAssetAmount);

        vm.prank(owner);
        weValue.convertEthToProtectedAsset(new address[](0), expectedProtectedAssetAmount);

        // --- Проверки ---
        // 1. Баланс ETH контракта должен быть 0
        assertEq(address(weValue).balance, 0, "Contract ETH balance should be zero after conversion");

        // 2. Баланс PROTECTED_ASSET контракта должен увеличиться
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), expectedProtectedAssetAmount, "Contract protected asset balance is incorrect");

        // 3. Баланс PROTECTED_ASSET у роутера должен быть 0
        assertEq(mockProtectedAsset.balanceOf(address(mockOneInchRouter)), 0, "Mock router should have zero protected assets after swap");
    }

    /// @dev Тестирует, что вызов convertEthToProtectedAsset не от имени владельца отменяется.
    function test_ConvertEthToProtectedAsset_RevertNotOwner() public {
        // Ожидаем ошибку, специфичную для Ownable
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));

        // Алиса (не владелец) пытается вызвать функцию
        vm.prank(alice);
        weValue.convertEthToProtectedAsset(new address[](0), 0);
    }

    /// @dev Тестирует, что вызов convertEthToProtectedAsset отменяется, если нет ETH для конвертации.
    function test_ConvertEthToProtectedAsset_RevertIfNoEth() public {
        // Убедимся, что баланс ETH равен 0
        assertEq(address(weValue).balance, 0, "Contract ETH balance should be zero initially");

        // Ожидаем нашу пользовательскую ошибку
        vm.expectRevert(WeValue.NoEthToConvert.selector);

        // Владелец пытается вызвать функцию при нулевом балансе
        vm.prank(owner);
        weValue.convertEthToProtectedAsset(new address[](0), 0);
    }

    /**
     * @dev Внутренняя функция для создания подписи EIP-2612 (Permit).
     * @return v Компонент v подписи.
     * @return r Компонент r подписи.
     * @return s Компонент s подписи.
     */
    function _createPermitSignature(
        address tokenOwner,
        address spender,
        uint256 keyTokenOwner,
        uint256 value,
        uint256 deadline
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = weValue.DOMAIN_SEPARATOR();
        uint256 nonce = weValue.nonces(tokenOwner);

        bytes32 permitHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                tokenOwner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, permitHash));

        (v, r, s) = vm.sign(keyTokenOwner, digest);
    }

    /// @dev Тестирует успешный перевод с использованием подписи (EIP-2612).
    function test_TransferWithPermit_Success() public {
        // --- 1. Подготовка ---
        uint256 donationAmount = 1 ether;
        vm.prank(alice);
        weValue.donation{value: donationAmount}();
        assertEq(weValue.balanceOf(alice), donationAmount, "Alice's initial balance is incorrect");

        uint256 valueToTransfer = donationAmount / 2;
        uint256 deadline = block.timestamp + 1 hours;

        // --- 2. Создание подписи ---
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(alice, bob, keyAlice, valueToTransfer, deadline);

        // --- 3. Действие и Проверки ---
        vm.prank(bob); // Боб вызывает функцию
        bool success = weValue.transferWithPermit(alice, bob, valueToTransfer, deadline, v, r, s);
        assertTrue(success, "transferWithPermit should return true");
        assertEq(weValue.balanceOf(alice), donationAmount - valueToTransfer, "Owner's balance should decrease");
        assertEq(weValue.balanceOf(bob), valueToTransfer, "Spender's balance should increase");
    }

    /// @dev Тестирует корректность функции isTrustedForwarder
    function test_isTrustedForwarder() public {
        assertTrue(weValue.isTrustedForwarder(trustedForwarder), "Initial trusted forwarder should be trusted");
        assertFalse(weValue.isTrustedForwarder(alice), "Alice should not be a trusted forwarder");
    }

    /// @dev Тестирует успешную установку нового доверенного отправителя.
    function test_setTrustedForwarder_Success() public {
        vm.expectEmit();
        emit WeValue.TrustedForwarderChanged(alice);
        vm.prank(owner);
        weValue.setTrustedForwarder(alice);
        assertTrue(weValue.isTrustedForwarder(alice));    
    }

    /// @dev Тестирует отмену установки доверенного отправителя не от имени владельца.
    function test_setTrustedForwarder_RevertNotOwner() public {
        // Ожидаем ошибку, специфичную для Ownable
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        // Боб (не владелец) пытается вызвать функцию
        weValue.setTrustedForwarder(alice);
    }

    /// @dev Тестирует успешную установку нового безопасного актива.
    function test_setSafeAsset_Success() public {
        vm.expectEmit();
        emit WeValue.SafeAssetChanged(address(mockSafeAsset2));
        vm.prank(owner);
        weValue.setSafeAsset(address(mockSafeAsset2));
        assertEq(address(weValue.SAFE_ASSET()), address(mockSafeAsset2), "SAFE_ASSET was not updated correctly");
    }

    /// @dev Тестирует отмену установки нового безопасного актива не от имени владельца.
    function test_setSafeAsset_RevertNotOwner() public {
        // Ожидаем ошибку, специфичную для Ownable
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        // Боб (не владелец) пытается вызвать функцию        
        weValue.setSafeAsset(address(mockSafeAsset2));
    }

}

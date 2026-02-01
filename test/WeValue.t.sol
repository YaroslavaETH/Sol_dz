// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Test, console} from "forge-std/Test.sol"; 
import {WeValue} from "src/WeValue_v2.sol";
import {MockERC20, MockAggregatorV3, MockOneInchRouter, MockAavePool} from "test/mocks/Mocks.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WeValueTest is Test {
    // Пользователи
    address owner;
    uint256 keyOwner;
    address alice;
    uint256 keyAlice;
    address bob;
    uint256 keyBob;
    address trustedForwarder;

    // Контракты
    WeValue weValue; // Это будет адрес прокси
    WeValue implementation; // Контракт реализации

    // Моки
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

        // Развертывание моков
        mockProtectedAsset = new MockERC20("Mock USDC", "mUSDC");
        mockSafeAsset = new MockERC20("Mock DAI", "mDAI");
        mockSafeAsset2 = new MockERC20("Mock PAXG", "mPAXG");
        mockAavePool = new MockAavePool(); // Инициализируем без аргументов, настроим позже
        mockOneInchRouter = new MockOneInchRouter(address(mockProtectedAsset), address(mockSafeAsset));
        mockPriceOracle = new MockAggregatorV3();
        mockSafeAssetPriceOracle = new MockAggregatorV3();
        
        
        // Развертывание реализации и прокси
        implementation = new WeValue();
        
        // Подготовка данных для инициализации
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
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

        // Устанавливаем ссылки в моках после развертывания weValue
        mockAavePool.setWeValueContract(address(weValue));
        mockAavePool.setSafeAssetMock(mockSafeAsset);

        // Устанавливаем начальный баланс ETH для пользователей
        vm.deal(alice, 10 ether);
        vm.deal(bob, 1 ether); // Даем Бобу немного ETH на газ
        vm.deal(trustedForwarder, 1 ether); // Даем доверенному отправителю ETH на газ
    }

    /// @dev Тестирует, что контракт инициализирован с правильными значениями.
    function test_Initialization() public view {
        assertEq(weValue.name(), "WeValue", "Incorrect token name");
        assertEq(weValue.symbol(), "WEVALUE", "Incorrect token symbol");
        assertEq(weValue.owner(), owner, "Incorrect owner");
        assertEq(weValue.trustedForwarder(), trustedForwarder, "Incorrect trusted forwarder");
        assertEq(address(weValue.aavePool()), address(mockAavePool), "Incorrect Aave pool address");
        assertEq(address(weValue.oneInchRouter()), address(mockOneInchRouter), "Incorrect 1inch router address");
        assertEq(address(weValue.priceOracle()), address(mockPriceOracle), "Incorrect price oracle address");
        assertEq(address(weValue.protectedAsset()), address(mockProtectedAsset), "Incorrect protected asset address");
        assertEq(address(weValue.safeAssetPriceOracle()), address(mockSafeAssetPriceOracle), "Incorrect safe asset price oracle address");
        assertEq(address(weValue.safeAsset()), address(mockSafeAsset), "Incorrect safe asset address");
        assertEq(weValue.depegThreshold(), 95_000_000, "Incorrect depeg threshold");
        assertEq(weValue.version(), "0.2", "Incorrect version");
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
        uint256 ethToConvert = 2 ether;
        uint256 expectedProtectedAssetAmount = 2000 * 1e6; // Ожидаем 2000 USDC (6 знаков)

        // Отправляем ETH на контракт WeValue
        vm.deal(address(weValue), ethToConvert);
        assertEq(address(weValue).balance, ethToConvert, "Initial ETH balance on contract is incorrect");

        // Ожидаем событие EthConverted
        vm.expectEmit();
        emit WeValue.EthConverted(ethToConvert, expectedProtectedAssetAmount);

        vm.prank(owner);
        weValue.convertEthToProtectedAsset("0x", expectedProtectedAssetAmount);

        // Баланс ETH контракта должен быть 0
        assertEq(address(weValue).balance, 0, "Contract ETH balance should be zero after conversion");
        // Баланс protectedAsset контракта должен увеличиться
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), expectedProtectedAssetAmount, "Contract protected asset balance is incorrect");
        // Баланс protectedAsset у роутера должен быть 0
        assertEq(mockProtectedAsset.balanceOf(address(mockOneInchRouter)), 0, "Mock router should have zero protected assets after swap");
    }

    /// @dev Тестирует, что вызов convertEthToProtectedAsset не от имени владельца отменяется.
    function test_ConvertEthToProtectedAsset_RevertNotOwner() public {
        // Ожидаем ошибку, специфичную для Ownable
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));

        // Алиса (не владелец) пытается вызвать функцию
        vm.prank(alice);
        weValue.convertEthToProtectedAsset("0x", 0);
    }

    /// @dev Тестирует, что вызов convertEthToProtectedAsset отменяется, если нет ETH для конвертации.
    function test_ConvertEthToProtectedAsset_RevertIfNoEth() public {
        // Убедимся, что баланс ETH равен 0
        assertEq(address(weValue).balance, 0, "Contract ETH balance should be zero initially");

        // Ожидаем нашу пользовательскую ошибку
        vm.expectRevert(WeValue.NoEthToConvert.selector);

        // Владелец пытается вызвать функцию при нулевом балансе
        vm.prank(owner);
        weValue.convertEthToProtectedAsset("0x", 0);
    }

    /**
     * @dev Внутренняя функция для создания подписи EIP-2612 (Permit).
     * @return v Компонент v подписи.
     * @return r Компонент r подписи.
     * @return s Компонент s подписи.
     */
    function _createPermitSignature (
        address tokenOwner,
        address spender,
        uint256 keyTokenOwner,
        uint256 value,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
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
        uint256 donationAmount = 1 ether;
        vm.prank(alice);
        weValue.donation{value: donationAmount}();
        assertEq(weValue.balanceOf(alice), donationAmount, "Alice's initial balance is incorrect");

        uint256 valueToTransfer = donationAmount / 2;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(alice, bob, keyAlice, valueToTransfer, deadline);

        vm.prank(bob);
        bool success = weValue.transferWithPermit(alice, bob, valueToTransfer, deadline, v, r, s);
        assertTrue(success, "transferWithPermit should return true");
        assertEq(weValue.balanceOf(alice), donationAmount - valueToTransfer, "Owner's balance should decrease");
        assertEq(weValue.balanceOf(bob), valueToTransfer, "Spender's balance should increase");
    }

    /// @dev Тестирует корректность функции isTrustedForwarder
    function test_isTrustedForwarder() view public {
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
        assertEq(address(weValue.safeAsset()), address(mockSafeAsset2), "safeAsset was not updated correctly");
    }

    /// @dev Тестирует отмену установки нового безопасного актива не от имени владельца.
    function test_setSafeAsset_RevertNotOwner() public {
        // Ожидаем ошибку, специфичную для Ownable
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob); 
        // Боб (не владелец) пытается вызвать функцию        
        weValue.setSafeAsset(address(mockSafeAsset2));
    }

    /// @dev Тестирует, что evacuateIfDepegged отменяется, если цена стабильна.
    function test_EvacuateIfDepegged_RevertIfStablePrice() public {
        // Устанавливаем цену выше порога отвязки
        mockPriceOracle.setLatestAnswer(100_000_000); // $1.00 (8 decimals)

        // Ожидаем ошибку PriceIsStable
        vm.expectRevert(WeValue.PriceIsStable.selector);

        // Вызываем функцию
        weValue.evacuateIfDepegged("0x", "0x", 0, 0, 0, 0);
    }

    /// @dev Тестирует, что evacuateIfDepegged отменяется, если эвакуация уже идет.
    function test_EvacuateIfDepegged_RevertIfEvacuationInProgress() public {
        // Устанавливаем цену ниже порога отвязки
        mockPriceOracle.setLatestAnswer(90_000_000); // $0.90 (8 decimals)

        // Искусственно устанавливаем флаг evacuating в true
        // evacuating находится в слоте 7 (см. WeValue.sol)
        bytes32 slot = bytes32(uint256(7));
        vm.store(address(weValue), slot, bytes32(uint256(1))); // Устанавливаем evacuating в true

        // Ожидаем ошибку EvacuationInProgress
        vm.expectRevert(WeValue.EvacuationInProgress.selector);

        // Вызываем функцию
        weValue.evacuateIfDepegged("0x", "0x", 0, 0, 0, 0);
    }

    /// @dev Тестирует успешную смену защитного актива, если баланс protectedAsset = 0.
    function test_EvacuateIfDepegged_SuccessWithoutFlashloan() public {
        // Устанавливаем цену ниже порога отвязки
        mockPriceOracle.setLatestAnswer(90_000_000); // $0.90 (8 decimals)
        // Убеждаемся, что баланс protectedAsset контракта равен 0
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), 0, "Protected asset balance should be 0 initially");

        // Ожидаем событие ProtectedAssetRotated
        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(address(mockProtectedAsset), address(mockSafeAsset));

        weValue.evacuateIfDepegged("0x", "0x", 0, 0, 0, 0);

        // Проверяем, что активы ротированы
        assertEq(address(weValue.protectedAsset()), address(mockSafeAsset), "protectedAsset should be rotated to safeAsset");
        assertEq(address(weValue.priceOracle()), address(mockSafeAssetPriceOracle), "priceOracle should be rotated to safeAssetPriceOracle");
    }

    /// @dev Тестирует успешную эвакуацию с флеш-кредитом и обменом.
    function test_EvacuateIfDepegged_SuccessWithFlashloan() public {
        // Устанавливаем цену ниже порога отвязки
        mockPriceOracle.setLatestAnswer(90_000_000); // $0.90 (8 decimals)

        // Контракт WeValue имеет protectedAsset
        uint256 initialProtectedAssetBalance = 1000 * 1e6; // 1000 USDC (6 decimals)
        mockProtectedAsset.mint(address(weValue), initialProtectedAssetBalance);
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialProtectedAssetBalance, "Initial protected asset balance is incorrect");

        // Параметры для флеш-кредита и обмена
        uint256 flashLoanAmount = 500 * 1e18; // 500 DAI (18 decimals)
        uint256 manipulationMinReturn = 490 * 1e6; // 490 USDC from 500 DAI
        uint256 evacuationMinReturn = 1450 * 1e18; // 1450 DAI from USDC
        uint256 simpleSwapMinReturn = 1300 * 1e18; // 1300 DAI if no manipulation

        // Настраиваем мок 1inch router для обменов
        // Манипуляция: safeAsset - protectedAsset 
        mockOneInchRouter.setExpectedSwapReturn(address(mockSafeAsset), address(mockProtectedAsset), manipulationMinReturn);
        // Эвакуация: protectedAsset - safeAsset
        mockOneInchRouter.setExpectedSwapReturn(address(mockProtectedAsset), address(mockSafeAsset), evacuationMinReturn);

        // Ожидаем события
        vm.expectEmit();
        emit WeValue.AssetsEvacuated(initialProtectedAssetBalance, evacuationMinReturn);
        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(address(mockProtectedAsset), address(mockSafeAsset));

        weValue.evacuateIfDepegged("0x", "0x", flashLoanAmount, manipulationMinReturn, evacuationMinReturn, simpleSwapMinReturn);

        assertEq(mockProtectedAsset.balanceOf(address(weValue)), 0, "Protected asset balance should be 0 after evacuation");
        assertEq(mockSafeAsset.balanceOf(address(weValue)), evacuationMinReturn-flashLoanAmount, "Safe asset balance should be evacuationMinReturn - flashLoanAmount");
        assertEq(address(weValue.protectedAsset()), address(mockSafeAsset), "protectedAsset should be rotated to safeAsset");
        assertEq(address(weValue.priceOracle()), address(mockSafeAssetPriceOracle), "priceOracle should be rotated to safeAssetPriceOracle");
    }

    /// @dev Тестирует отмену эвакуации, если не хватает средств для погашения флеш-кредита и комиссии.
    function test_EvacuateIfDepegged_RevertIfRepaymentFails() public {
        // Устанавливаем цену ниже порога отвязки
        mockPriceOracle.setLatestAnswer(90_000_000); // $0.90 (8 decimals)

        // Контракт WeValue имеет protectedAsset
        uint256 initialProtectedAssetBalance = 1000 * 1e6; // 1000 USDC (6 decimals)
        mockProtectedAsset.mint(address(weValue), initialProtectedAssetBalance);
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialProtectedAssetBalance, "Initial protected asset balance is incorrect");

        // Параметры для флеш-кредита и обмена
        uint256 flashLoanAmount = 500 * 1e18; // 500 DAI (18 decimals)
        uint256 premium = 10 * 1e18; // 10 DAI комиссия
        uint256 manipulationMinReturn = 490 * 1e6; // 490 USDC from 500 DAI
        uint256 evacuationMinReturn = 500 * 1e18; // 500 DAI from (1000+490) USDC - недостаточно для погашения
        uint256 simpleSwapMinReturn = 1300 * 1e18; // 1300 DAI if no manipulation

        // Настраиваем мок 1inch router для обменов
        mockOneInchRouter.setExpectedSwapReturn(address(mockSafeAsset), address(mockProtectedAsset), manipulationMinReturn);
        mockOneInchRouter.setExpectedSwapReturn(address(mockProtectedAsset), address(mockSafeAsset), evacuationMinReturn);
        mockAavePool.setPremium(premium);

        // Ожидаем ошибку SwapFailed, так как не хватает средств для погашения
        vm.expectRevert(WeValue.SwapFailed.selector);

        weValue.evacuateIfDepegged("0x", "0x", flashLoanAmount, manipulationMinReturn, evacuationMinReturn, simpleSwapMinReturn);

        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialProtectedAssetBalance, "Protected asset balance should be unchanged");
        assertEq(mockSafeAsset.balanceOf(address(weValue)), 0, "Safe asset balance should be 0");
        assertEq(address(weValue.protectedAsset()), address(mockProtectedAsset), "protectedAsset should not be rotated");
        assertEq(address(weValue.priceOracle()), address(mockPriceOracle), "priceOracle should not be rotated");
    }

    /// @dev Тестирует отмену эвакуации, если манипуляция ценой оказалась невыгодной.
    function test_EvacuateIfDepegged_RevertIfManipulationUnprofitable() public {
        // Устанавливаем цену ниже порога отвязки
        mockPriceOracle.setLatestAnswer(90_000_000); // $0.90 (8 decimals)

        // Контракт WeValue имеет protectedAsset
        uint256 initialProtectedAssetBalance = 1000 * 1e6; // 1000 USDC (6 decimals)
        mockProtectedAsset.mint(address(weValue), initialProtectedAssetBalance);
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialProtectedAssetBalance, "Initial protected asset balance is incorrect");

        // Параметры для флеш-кредита и обмена
        uint256 flashLoanAmount = 500 * 1e18; // 500 DAI (18 decimals)
        uint256 manipulationMinReturn = 490 * 1e6; // 490 USDC from 500 DAI
        // Устанавливаем evacuationMinReturn так, чтобы она была <= simpleSwapMinReturn
        uint256 evacuationMinReturn = 1200 * 1e18; // 1200 DAI from (1000+490) USDC
        uint256 simpleSwapMinReturn = 1300 * 1e18; // 1300 DAI if no manipulation

        // Настраиваем мок 1inch router для обменов
        // Манипуляция: safeAsset  -protectedAsset
        mockOneInchRouter.setExpectedSwapReturn(address(mockSafeAsset), address(mockProtectedAsset), manipulationMinReturn);
        // Эвакуация: protectedAsset - safeAsset 
        mockOneInchRouter.setExpectedSwapReturn(address(mockProtectedAsset), address(mockSafeAsset), evacuationMinReturn);

        // Ожидаем ошибку SwapFailed, так как стратегия не была прибыльной
        vm.expectRevert(WeValue.SwapFailed.selector);

        weValue.evacuateIfDepegged("0x", "0x", flashLoanAmount, manipulationMinReturn, evacuationMinReturn, simpleSwapMinReturn);

        // Проверки (убеждаемся, что ничего не изменилось, так как транзакция откатилась)
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialProtectedAssetBalance, "Protected asset balance should be unchanged");
        assertEq(mockSafeAsset.balanceOf(address(weValue)), 0, "Safe asset balance should be 0");
        assertEq(address(weValue.protectedAsset()), address(mockProtectedAsset), "protectedAsset should not be rotated");
        assertEq(address(weValue.priceOracle()), address(mockPriceOracle), "priceOracle should not be rotated");
    }

    // =================================================================
    // ========================== FORK TESTS ===========================
    // =================================================================
    // forge test --fork-url mainnet --match-test test_EvacuateIfDepegged_Fork_Success -vv

    /// @dev Тестирует успешную эвакуацию в форке mainnet. Только для варианта 3, когда не нужен обмен,но цена упала. 
    /// Не получается сделать fork на 1inch, проверяет Chainlink
    function test_EvacuateIfDepegged_Fork_Success() public {
        // Проверяем, что тест запущен в режиме форка
        uint256 forkBlock = block.number;
        if (forkBlock == 0) {
            // Пропускаем тест, если это не форк
            return;
        }

        // Адреса контрактов в Mainnet
        address aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Aave V3 Pool
        address oneInchRouter = 0x1111111254EEB25477B68fb85Ed929f73A960582; // 1inch Aggregation Router v5
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (Protected Asset)
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;  // DAI (Safe Asset)
        address usdcUsdOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // Chainlink USDC/USD
        address daiUsdOracle = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;  // Chainlink DAI/USD

        // Развертывание реализации и прокси
        WeValue forkImplementation = new WeValue();
        
        // Устанавливаем depegThreshold ВЫШЕ текущей цены, чтобы симулировать отвязку
        // Цена USDC/USD имеет 8 знаков. 101_000_000 = $1.01
        uint256 depegThreshold = 101_000_000; 

        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            owner,
            trustedForwarder,
            aavePool,
            oneInchRouter,
            usdcUsdOracle,
            usdc,
            daiUsdOracle,
            dai,
            depegThreshold
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(forkImplementation), initData);
        WeValue forkWeValue = WeValue(payable(address(proxy)));

        // Не будем заводить на контракт токены, чтобы пройти по варианту 3
        // uint256 usdcAmountToEvacuate = 1000 * 1e6; // 1,000 USDC
        // // Используем чит-код deal для "печати" USDC на баланс нашего контракта
        // deal(usdc, address(forkWeValue), usdcAmountToEvacuate);
        // assertEq(IERC20(usdc).balanceOf(address(forkWeValue)), usdcAmountToEvacuate, "Initial USDC balance is incorrect");
        console.log("USDC balance to evacuate:", IERC20(usdc).balanceOf(address(forkWeValue)));

        // Логирование для отладки
        ( , int256 price, , , ) = AggregatorV3Interface(usdcUsdOracle).latestRoundData();
        // casting to 'uint256' is safe because price is a non-negative value
        // forge-lint: disable-next-line(unsafe-typecast)
        console.log("Current USDC/USD Price (from Chainlink):", uint256(price));
        console.log("Depeg Threshold set in contract:", depegThreshold);

        // // Ожидаем событие AssetsEvacuated.
        // // Мы не можем точно предсказать amountOut, поэтому проверяем только amountIn.
        // vm.expectEmit(true, false, false, false);
        // emit WeValue.AssetsEvacuated(usdcAmountToEvacuate, 0); // amountOut здесь игнорируется
        // // Ожидаем, что контракт USDC сгенерирует событие Approval. Указываем адрес usdc в vm.expectEmit.
        // vm.expectEmit();
        // emit IERC20.Approval(address(forkWeValue), oneInchRouter, usdcAmountToEvacuate);
        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(usdc, dai);

        // Вызываем эвакуацию без флеш-кредита (flashLoanAmount = 0).
        // Контракт должен использовать логику простого обмена.
        // Для простого обмена нужен только simpleSwapMinReturn.
        uint256 simpleSwapMinReturn = 1; // Гарантируем, что обмен произошел.
        vm.prank(owner);
        forkWeValue.evacuateIfDepegged("0x", "0x", 0, 0, 0, simpleSwapMinReturn);

        // // Баланс USDC должен обнулиться.
        // assertEq(IERC20(usdc).balanceOf(address(forkWeValue)), 0, "USDC balance should be 0 after evacuation");

        // // Баланс DAI должен стать больше нуля.
        // uint256 finalDaiBalance = IERC20(dai).balanceOf(address(forkWeValue));
        // assertTrue(finalDaiBalance > 0, "DAI balance should be greater than 0 after evacuation");
        // console.log("Final DAI balance:", finalDaiBalance);

        // Защищенный актив и его оракул должны измениться на DAI.
        assertEq(address(forkWeValue.protectedAsset()), dai, "protectedAsset should be rotated to DAI");
        assertEq(address(forkWeValue.priceOracle()), daiUsdOracle, "priceOracle should be rotated to DAI oracle");

        // Флаг эвакуации должен быть сброшен.
        assertFalse(forkWeValue.evacuating(), "Evacuating flag should be false after completion");

    }
}

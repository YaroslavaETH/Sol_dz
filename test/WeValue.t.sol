// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Test, console} from "forge-std/Test.sol"; 
import {WeValue} from "src/WeValue_v3.sol"; 
import {MultiSigWallet} from "src/MultiSigWallet.sol";
import {MockERC20, MockAggregatorV3, MockAavePool, MockUniswapRouter, MockPermit2} from "test/mocks/Mocks.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract WeValueTest is Test {
    // Пользователи
    address owner;
    address owner1;
    address owner2;
    uint256 keyOwner;
    uint256 keyOwner1;
    address ownerWallet;
    address alice;
    uint256 keyAlice;
    address bob;
    uint256 keyBob;
    // Контракты
    WeValue weValue; // Это будет адрес прокси
    WeValue implementation; // Контракт реализации

    // Моки
    MockAavePool mockAavePool;
    MockAggregatorV3 mockPriceOracle;
    MockAggregatorV3 mockSafeAssetPriceOracle;
    MockERC20 mockProtectedAsset; 
    MockERC20 mockSafeAsset; 
    MockERC20 mockSafeAsset2;
    MockUniswapRouter mockUniswapRouter;
    MockPermit2 mockPermit2;

    /// @dev Настраивает тестовое окружение перед каждым тест-кейсом.
    function setUp() public {
        // Инициализируем пользователей
        (owner, keyOwner) = makeAddrAndKey("owner");
        (owner1, keyOwner1) = makeAddrAndKey("owner1");
        owner2 = makeAddr("owner2");
        (alice, keyAlice) = makeAddrAndKey("alice");
        (bob, keyBob) = makeAddrAndKey("bob");

        // Развертывание моков
        mockProtectedAsset = new MockERC20("Mock USDC", "mUSDC");
        mockSafeAsset = new MockERC20("Mock DAI", "mDAI");
        mockSafeAsset2 = new MockERC20("Mock PAXG", "mPAXG");
        mockAavePool = new MockAavePool(); // Инициализируем без аргументов, настроим позже
        mockPriceOracle = new MockAggregatorV3();
        mockSafeAssetPriceOracle = new MockAggregatorV3();
        mockUniswapRouter = new MockUniswapRouter();
        mockPermit2 = new MockPermit2();
        
        
        // Развертывание реализации и прокси
        implementation = new WeValue();

        // Развертывание мультисиг кошелька
        address[] memory multisigOwners = new address[](3);
        multisigOwners[0] = owner;
        multisigOwners[1] = owner1;
        multisigOwners[2] = owner2;
        ownerWallet = address(new MultiSigWallet(multisigOwners, 2));
        
        // Подготовка данных для инициализации
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            ownerWallet,
            address(mockAavePool), // _aavePool
            address(mockPriceOracle), // _priceOracle
            address(mockProtectedAsset), // _protectedAsset
            address(mockSafeAssetPriceOracle), // _safeAssetPriceOracle
            address(mockSafeAsset), // _safeAsset
            95_000_000, // _depegThreshold
            address(mockUniswapRouter), // _router
            address(mockPermit2) // _permit2
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        weValue = WeValue(payable(address(proxy)));

        // Устанавливаем ссылки в моках после развертывания weValue
        mockAavePool.setWeValueContract(address(weValue));
        mockAavePool.setSafeAssetMock(mockSafeAsset);

        // Устанавливаем начальный баланс ETH для пользователей
        vm.deal(alice, 10 ether);
        vm.deal(bob, 1 ether); // Даем Бобу немного ETH на газ
    }

    /// @dev Тестирует, что контракт инициализирован с правильными значениями.
    function test_Initialization() public view {
        assertEq(weValue.name(), "WeValue", "Incorrect token name");
        assertEq(weValue.symbol(), "WEVALUE", "Incorrect token symbol");
        assertEq(weValue.owner(), ownerWallet, "Incorrect owner");
        assertEq(address(weValue.aavePool()), address(mockAavePool), "Incorrect Aave pool address");
        assertEq(address(weValue.router()), address(mockUniswapRouter), "Incorrect Uniswap router address");
        assertEq(address(weValue.priceOracle()), address(mockPriceOracle), "Incorrect price oracle address");
        assertEq(address(weValue.protectedAsset()), address(mockProtectedAsset), "Incorrect protected asset address");
        assertEq(address(weValue.safeAssetPriceOracle()), address(mockSafeAssetPriceOracle), "Incorrect safe asset price oracle address");
        assertEq(address(weValue.safeAsset()), address(mockSafeAsset), "Incorrect safe asset address");
        assertEq(weValue.depegThreshold(), 95_000_000, "Incorrect depeg threshold");
        assertEq(weValue.version(), "0.3", "Incorrect version");
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

    /// @dev Тестирует успешную конвертацию ETH в защищенный актив через Uniswap4.
    function test_ConvertEthToProtectedAsset_Uniswap4_Success() public {
        uint256 ethToConvert = 2 ether;
        uint128 expectedProtectedAssetAmount = 2000 * 10 ** 6; // Ожидаем 2000 USDC (6 знаков)

        // Отправляем ETH на контракт WeValue
        vm.deal(address(weValue), ethToConvert);
        assertEq(address(weValue).balance, ethToConvert, "Initial ETH balance on contract is incorrect");

        // Настраиваем мок роутера, чтобы он вернул ожидаемое количество токенов
        mockUniswapRouter.setExpectedSwapReturn(address(0), address(mockProtectedAsset), expectedProtectedAssetAmount);

        // Ожидаем событие EthConverted
        vm.expectEmit();
        emit WeValue.EthConverted(ethToConvert, expectedProtectedAssetAmount);

        // Вызываем функцию
        vm.prank(ownerWallet);
        weValue.convertEthToProtectedAsset(expectedProtectedAssetAmount);

        // Баланс ETH контракта должен быть 0
        assertEq(address(weValue).balance, 0, "Contract ETH balance should be zero after conversion");
        // Баланс protectedAsset контракта должен увеличиться
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), expectedProtectedAssetAmount, "Contract protected asset balance is incorrect");
    }

    /// @dev Тестирует, что вызов convertEthToProtectedAsset через Uniswap4 не от имени владельца отменяется.
    function test_ConvertEthToProtectedAsset_Uniswap4_RevertNotOwner() public {
        // Ожидаем ошибку, специфичную для Ownable
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));

        // Алиса (не владелец) пытается вызвать функцию
        vm.prank(alice);
        weValue.convertEthToProtectedAsset(0);
    }

    /// @dev Тестирует, что вызов convertEthToProtectedAsset через Uniswap4 отменяется, если нет ETH для конвертации.
    function test_ConvertEthToProtectedAsset_Uniswap4_RevertIfNoEth() public {
        // Убедимся, что баланс ETH равен 0
        assertEq(address(weValue).balance, 0, "Contract ETH balance should be zero initially");

        // Ожидаем нашу пользовательскую ошибку
        vm.expectRevert(WeValue.NoEthToConvert.selector);

        // Владелец пытается вызвать функцию при нулевом балансе
        vm.prank(ownerWallet);
        weValue.convertEthToProtectedAsset(0);
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

    /// @dev Тестирует успешную установку нового безопасного актива.
    function test_setSafeAsset_Success() public {
        vm.expectEmit();
        emit WeValue.SafeAssetChanged(address(mockSafeAsset2));
        vm.prank(ownerWallet);
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
        vm.prank(owner);
        weValue.evacuateIfDepegged(0, 0, 0, 0);
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
        vm.prank(owner);
        weValue.evacuateIfDepegged(0, 0, 0, 0);
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

        vm.prank(owner);
        weValue.evacuateIfDepegged(0, 0, 0, 0);

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
        uint256 evacuationMinReturn = 1900 * 1e18; // 1450 DAI from USDC
        uint256 simpleSwapMinReturn = 1300 * 1e18; // 1300 DAI if no manipulation        
        uint256 premium = 5 * 1e18; // 5 DAI комиссия

        // Настраиваем мок Uniswap router для обменов
        // Манипуляция: safeAsset - protectedAsset 
        mockUniswapRouter.setExpectedSwapReturn(address(mockSafeAsset), address(mockProtectedAsset), manipulationMinReturn);
        // Эвакуация: protectedAsset - safeAsset
        mockUniswapRouter.setExpectedSwapReturn(address(mockProtectedAsset), address(mockSafeAsset), evacuationMinReturn);
        // Устанавливаем комиссию в моке Aave
        mockAavePool.setPremium(premium);

        // Ожидаем события
        vm.expectEmit();
        emit WeValue.AssetsEvacuated(initialProtectedAssetBalance, evacuationMinReturn);
        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(address(mockProtectedAsset), address(mockSafeAsset));
        
        vm.prank(owner);
        weValue.evacuateIfDepegged(evacuationMinReturn, flashLoanAmount, manipulationMinReturn, simpleSwapMinReturn);

        assertEq(mockProtectedAsset.balanceOf(address(weValue)), 0, "Protected asset balance should be 0 after evacuation");
        assertEq(mockSafeAsset.balanceOf(address(weValue)), evacuationMinReturn - flashLoanAmount - premium, "Safe asset balance should be (evacuated - flashLoan - premium)");
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

        // Настраиваем мок Uniswap router для обменов
        mockUniswapRouter.setExpectedSwapReturn(address(mockSafeAsset), address(mockProtectedAsset), manipulationMinReturn);
        mockUniswapRouter.setExpectedSwapReturn(address(mockProtectedAsset), address(mockSafeAsset), evacuationMinReturn);
        mockAavePool.setPremium(premium);

        // Ожидаем ошибку EvacuationWithCreditFailed, так как не хватает средств для погашения
        vm.expectRevert(
            abi.encodeWithSelector(WeValue.EvacuationWithCreditFailed.selector, 
                evacuationMinReturn, flashLoanAmount + simpleSwapMinReturn + premium)
        );

        vm.prank(owner);
        weValue.evacuateIfDepegged(evacuationMinReturn, flashLoanAmount, manipulationMinReturn, simpleSwapMinReturn);

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

        // Настраиваем мок Uniswap router для обменов
        // Манипуляция: safeAsset  - protectedAsset
        mockUniswapRouter.setExpectedSwapReturn(address(mockSafeAsset), address(mockProtectedAsset), manipulationMinReturn);
        // Эвакуация: protectedAsset - safeAsset 
        mockUniswapRouter.setExpectedSwapReturn(address(mockProtectedAsset), address(mockSafeAsset), evacuationMinReturn);

        // Ожидаем ошибку EvacuationWithCreditFailed, так как стратегия не была прибыльной
        vm.expectRevert(abi.encodeWithSelector(WeValue.EvacuationWithCreditFailed.selector, evacuationMinReturn, flashLoanAmount + simpleSwapMinReturn));

        vm.prank(owner);
        weValue.evacuateIfDepegged(evacuationMinReturn, flashLoanAmount, manipulationMinReturn, simpleSwapMinReturn);

        // Проверки (убеждаемся, что ничего не изменилось, так как транзакция откатилась)
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialProtectedAssetBalance, "Protected asset balance should be unchanged");
        assertEq(mockSafeAsset.balanceOf(address(weValue)), 0, "Safe asset balance should be 0");
        assertEq(address(weValue.protectedAsset()), address(mockProtectedAsset), "protectedAsset should not be rotated");
        assertEq(address(weValue.priceOracle()), address(mockPriceOracle), "priceOracle should not be rotated");
    }
   /// @dev Тестирует успешный вывод средств.
    function test_WithdrawalProtectedAsset_Offchain_Success() public {
        uint256 initialContractBalance = 1000 ether; 
        mockProtectedAsset.mint(address(weValue), initialContractBalance);

        uint256 amountToWithdraw = 400 ether; 
        address recipient = bob;
        string memory description = "Help zooclinic";

        // Ожидаем событие вывода
        vm.expectEmit();
        emit WeValue.WithdrawalProtectedAsset(1, amountToWithdraw, address(mockProtectedAsset), recipient, true, description);

        // Вывод средств
        vm.prank(owner);
        // Указываем, что это off-chain операция
        weValue.withdrawalProtectedAsset(recipient, amountToWithdraw, true, description);

        // Проверяем счетчики и списки
        assertEq(weValue.withdrawalCount(), 1, "Count of withdrawals should increase");
        // Проверяем, что операция добавлена в список неподтвержденных
        assertEq(weValue.getUnconfirmedOperationsCount(), 1, "Unconfirmed operations count should be 1");
        assertEq(weValue.unconfirmedOperations(0), 1, "Operation ID should be added to unconfirmedOperations");

        // Проверяем созданную запись
        (uint256 amountRecord, address recipientRecord, bool offchainRecord, uint256 timestampRecord) = weValue.withdrawalOperations(1);
        assertEq(amountRecord, amountToWithdraw, "Amount in withdrawal record is incorrect");
        assertEq(recipientRecord, recipient, "Recipient in withdrawal record is incorrect");
        assertTrue(offchainRecord, "Offchain flag in withdrawal record should be true");
        assertEq(timestampRecord, block.timestamp, "Timestamp in withdrawal record is incorrect");

        // Проверяем балансы токенов
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialContractBalance - amountToWithdraw, "Balance of the contract should decrease");
        assertEq(mockProtectedAsset.balanceOf(recipient), amountToWithdraw, "Balance of the recipient should increase");
    }

    /// @dev Тестирует, что вызов withdrawalProtectedAsset не от имени владельца отменяется.
    function test_WithdrawalProtectedAsset_RevertNotOwner() public {
        // Ожидаем ошибку, специфичную для Ownable
        vm.expectRevert(abi.encodeWithSelector(WeValue.NotMultiSigOwner.selector, alice));

        // Алиса (не владелец) пытается вызвать функцию
        vm.prank(alice);
        weValue.withdrawalProtectedAsset(bob, 100 ether, true, "Attempt by Alice");
    }

    /// @dev Тестирует, что транзакция отменяется, если на балансе контракта недостаточно средств для перевода.
    function test_WithdrawalProtectedAsset_RevertOnTransferFail() public {
        uint256 initialContractBalance = 100 ether;
        mockProtectedAsset.mint(address(weValue), initialContractBalance);

        // Пытаемся вывести больше, чем есть на балансе
        uint256 amountToWithdraw = 200 ether;

        // Ожидаем ошибку ERC20InsufficientBalance из контракта токена.
        // Эта ошибка возникает раньше, чем наша кастомная ошибка.
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(weValue), // Адрес, у которого не хватает баланса
                initialContractBalance, // Его текущий баланс
                amountToWithdraw // Сумма, которую пытались списать
            )
        );
        vm.prank(owner);
        weValue.withdrawalProtectedAsset(bob, amountToWithdraw, true, "This should fail");

        // Проверяем что состояние не изменилось
        assertEq(weValue.withdrawalCount(), 0, "Count of withdrawals should not change");
        assertEq(weValue.getUnconfirmedOperationsCount(), 0, "List of unconfirmed operations should not change");
        assertEq(mockProtectedAsset.balanceOf(address(weValue)), initialContractBalance, "Balance of the contract should not change");
        assertEq(mockProtectedAsset.balanceOf(bob), 0, "Balance of the recipient should not change");
    }

    /// @dev Тестирует успешнон добавление чека расходной операции.
    function test_AddCheck_Success() public {
        // Создаем успешный вывод
        uint256 initialContractBalance = 1000 ether; 
        mockProtectedAsset.mint(address(weValue), initialContractBalance);

        vm.prank(owner);
        weValue.withdrawalProtectedAsset(bob, 400 ether, true, "Withdrawal for check test");
        
        assertEq(weValue.getUnconfirmedOperationsCount(), 1, "There should be one unconfirmed operation");
        uint256 operationId = weValue.unconfirmedOperations(0);
        assertEq(operationId, 1, "Operation ID should be 1");

        // Сохраняем состояние операции до подтверждения
        (uint256 amountBefore, address recipientBefore, bool offchainBefore, uint256 timestampBefore) = weValue.withdrawalOperations(operationId);

        // Добавляем чек
        uint64 date = 202602072138;
        uint64 fn = 7380440902747045;
        uint32 fd = 78415;
        uint32 fpd = 3194281987;

        // Ожидаем событие добавления чека
        vm.expectEmit();
        emit WeValue.AddCheckToWithdrawal(operationId, date, fn, fd, fpd);
        vm.prank(owner);
        weValue.addCheckToWithdrawal(operationId, date, fn, fd, fpd);


        // Проверяем, что чек сохранился в маппинге чеков
        bytes32 checkHash = weValue.getReceiptHash(fn, fd, fpd);
        (uint64 savedDate, uint64 savedFn, uint32 savedFd, uint32 savedFpd) = weValue.checks(checkHash);
        assertEq(savedDate, date, "Date in check record is incorrect");
        assertEq(savedFn, fn, "Fn in check record is incorrect");
        assertEq(savedFd, fd, "Fd in check record is incorrect");
        assertEq(savedFpd, fpd, "Fpd in check record is incorrect");

        // Проверяем запись о выводе. Основные данные не изменились, но добавился хеш чека
        (uint256 amount, address recipient, bool offchain, uint256 timestamp) = weValue.withdrawalOperations(operationId);
        assertEq(amount, amountBefore, "Amount in check record should not change");
        assertEq(recipient, recipientBefore, "Recipient in check record should not change");
        assertEq(offchain, offchainBefore, "Offchain in check record should not change");
        assertEq(timestamp, timestampBefore, "Timestamp in check record should not change");
        // Проверяем, что хэш чека добавился в массив операции
        assertEq(weValue.getWithdrawalChecksCount(operationId), 1, "Checks array should contain one element");
        bytes32 savedCheckHash = weValue.getWithdrawalCheckAtIndex(operationId, 0);
        assertEq(savedCheckHash, checkHash, "Incorrect check hash in checks array");
    }

    /// @dev Тестирует добавление второго чека к той же операции вывода.
    function test_AddSecondCheckToWithdrawal_Success() public {
        uint256 initialContractBalance = 1000 ether; 
        mockProtectedAsset.mint(address(weValue), initialContractBalance);
        // Создаем вывод и добавляем первый чек
        vm.prank(owner);
        weValue.withdrawalProtectedAsset(bob, 400 ether, true, "Withdrawal for second check test");
        uint256 operationId = 1;
        vm.prank(owner);
        weValue.addCheckToWithdrawal(operationId, 202401010000, 111, 1, 1);

        assertEq(weValue.getWithdrawalChecksCount(operationId), 1, "Should have one check");

        // Добавляем второй чек
        vm.prank(owner);
        uint64 date2 = 202401020000;
        uint64 fn2 = 222;
        uint32 fd2 = 2;
        uint32 fpd2 = 2;
        weValue.addCheckToWithdrawal(operationId, date2, fn2, fd2, fpd2);

        assertEq(weValue.getWithdrawalChecksCount(operationId), 2, "Should have two checks");

        bytes32 checkHash2 = weValue.getReceiptHash(fn2, fd2, fpd2);
        bytes32 savedCheckHash2 = weValue.getWithdrawalCheckAtIndex(operationId, 1);
        assertEq(savedCheckHash2, checkHash2, "Hash of second check should match");
    }

    /// @dev Тестирует отмену добавления чека к несуществующей операции.
    function test_AddCheck_RevertIfOperationNotFound() public {
        uint256 nonExistentOperationId = 999;

        // Ожидаем ошибку OperationNotFound
        vm.expectRevert(WeValue.OperationNotFound.selector);

        // Пытаемся добавить чек к операции, которой нет
        vm.prank(owner);
        weValue.addCheckToWithdrawal(nonExistentOperationId, 202401010000, 111, 1, 1);
    }

    /// @dev Тестирует отмену добавления чека, который уже был использован.
    function test_AddCheck_RevertIfCheckAlreadyUsed() public {
        uint256 initialContractBalance = 1000 ether; 
        mockProtectedAsset.mint(address(weValue), initialContractBalance);
        // Создаем две операции и используем чек в первой
        vm.prank(owner);
        weValue.withdrawalProtectedAsset(bob, 100 ether, true, "First withdrawal"); // opId = 1
        vm.prank(owner);
        weValue.withdrawalProtectedAsset(alice, 200 ether, true, "Second withdrawal"); // opId = 2

        uint64 date = 202401010000;
        uint64 fn = 111;
        uint32 fd = 1;
        uint32 fpd = 1;

        // Добавляем чек к первой операции
        vm.prank(owner);
        weValue.addCheckToWithdrawal(1, date, fn, fd, fpd);

        // Пытаемся добавить тот же чек ко второй операции
        // Ожидаем ошибку CheckAlreadyUsed
        vm.expectRevert(WeValue.CheckAlreadyUsed.selector);
        vm.prank(owner);
        weValue.addCheckToWithdrawal(2, date, fn, fd, fpd);
    }

    /// @dev Тестирует отмену подтверждения операции, если к ней не добавлено ни одного чека.
    function test_ConfirmWithdrawal_RevertIfNoChecks() public {
        uint256 initialContractBalance = 1000 ether; 
        mockProtectedAsset.mint(address(weValue), initialContractBalance);
        // Создаем операцию вывода, но не добавляем чеков
        vm.prank(owner);
        weValue.withdrawalProtectedAsset(bob, 100 ether, true, "Withdrawal with no checks");
        uint256 operationId = 1;

        assertEq(weValue.getUnconfirmedOperationsCount(), 1, "Should have one unconfirmed operation");

        // Ожидаем ошибку OperationHasNoChecks
        vm.expectRevert(WeValue.OperationHasNoChecks.selector);

        vm.prank(ownerWallet);
        weValue.confirmWithdrawal(operationId);

        // Убеждаемся, что операция все еще в списке неподтвержденных
        assertEq(weValue.getUnconfirmedOperationsCount(), 1, "The operation should still be in the unconfirmed list");
    }
    // =================================================================
    // ========================== FORK TESTS ===========================
    // =================================================================
    // forge test --fork-url mainnet --match-test test_EvacuateIfDepegged_Fork -vv

    /// @dev Тестирует успешную эвакуацию в форке mainnet. Варианта 3, когда не нужен обмен,но цена упала. 
    function test_EvacuateIfDepegged_Fork_OnlyRotateAsset_Success() public {
        // Проверяем, что тест запущен в режиме форка
        uint256 forkBlock = block.number;
        if (forkBlock == 0) {
            // Пропускаем тест, если это не форк
            return;
        }

        // Адреса контрактов в Mainnet
        address aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Aave V3 Pool
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (Protected Asset)
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;  // DAI (Safe Asset)
        address usdcUsdOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // Chainlink USDC/USD
        address daiUsdOracle = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;  // Chainlink DAI/USD
        address uniswapRouter = 0x000000000004444c5dc75cB358380D2e3dE08A90; // Uniswap V4: Pool Manager
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Permit2

        // Развертывание реализации и прокси
        WeValue forkImplementation = new WeValue();

        // Устанавливаем depegThreshold ВЫШЕ текущей цены, чтобы симулировать отвязку
        // Цена USDC/USD имеет 8 знаков. 101_000_000 = $1.01
        uint256 depegThreshold = 101_000_000; 

        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            ownerWallet,
            aavePool,
            usdcUsdOracle,
            usdc,
            daiUsdOracle,
            dai,
            depegThreshold,
            uniswapRouter,
            permit2
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(forkImplementation), initData);
        WeValue forkWeValue = WeValue(payable(address(proxy)));

        // Не будем заводить на контракт токены, чтобы пройти по варианту 3
        console.log("USDC balance to evacuate:", MockERC20(usdc).balanceOf(address(forkWeValue)));

        // Логирование для отладки
        ( , int256 price, , , ) = AggregatorV3Interface(usdcUsdOracle).latestRoundData();
        // casting to 'uint256' is safe because price is a non-negative value
        // forge-lint: disable-next-line(unsafe-typecast)
        console.log("Current USDC/USD Price (from Chainlink):", uint256(price));
        console.log("Depeg Threshold set in contract:", depegThreshold);

        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(usdc, dai);

        vm.prank(owner);
        forkWeValue.evacuateIfDepegged(0, 0, 0, 0);

        // Защищенный актив и его оракул должны измениться на DAI.
        assertEq(address(forkWeValue.protectedAsset()), dai, "protectedAsset should be rotated to DAI");
        assertEq(address(forkWeValue.priceOracle()), daiUsdOracle, "priceOracle should be rotated to DAI oracle");

        // Флаг эвакуации должен быть сброшен.
        assertFalse(forkWeValue.evacuating(), "Evacuating flag should be false after completion");

    }

    /// @dev Тестирует успешную эвакуацию в форке mainnet. Вариант 2, простой обмен без флеш-кредита.
    function test_EvacuateIfDepegged_Fork_SimpleSwap_Success() public {
        uint256 forkBlock = block.number;
        if (forkBlock == 0) return;

        // Адреса контрактов в Mainnet
        address aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address usdcUsdOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
        address daiUsdOracle = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
        address uniswapRouter = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Permit2

        WeValue forkImplementation = new WeValue();
        uint256 depegThreshold = 101_000_000;

        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            ownerWallet,
            aavePool,
            usdcUsdOracle,
            usdc,
            daiUsdOracle,
            dai,
            depegThreshold,
            uniswapRouter,
            permit2
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(forkImplementation), initData);
        WeValue forkWeValue = WeValue(payable(address(proxy)));

        uint256 usdcAmountToEvacuate = 1_000 * 10**6; // 1,000 USDC (6 decimals)
        // Используем cheatcode `deal` для зачисления токенов на баланс контракта в форке
        deal(usdc, address(forkWeValue), usdcAmountToEvacuate);
        assertEq(IERC20(usdc).balanceOf(address(forkWeValue)), usdcAmountToEvacuate, "Initial USDC balance is incorrect");

        ( , int256 price, , , ) = AggregatorV3Interface(usdcUsdOracle).latestRoundData();
        console.log("Current USDC/USD Price (from Chainlink):", uint256(price));
        console.log("Depeg Threshold set in contract:", depegThreshold);
        console.log("Before balance protectedAsset:", IERC20(usdc).balanceOf(address(forkWeValue)));

        // Проверяем события нестрого, так как Uniswap может генерировать свои
        vm.expectEmit(true, true, true, false); // Не проверяем amountOut, так как он заранее неизвестен
        emit WeValue.AssetsEvacuated(usdcAmountToEvacuate, 0); // amountOut здесь игнорируется при нестрогой проверке
        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(usdc, dai);

        uint256 evacuationMinReturn = 1; // Гарантируем, что обмен произошел.
        vm.prank(owner);
        forkWeValue.evacuateIfDepegged(evacuationMinReturn, 0, 0, 0);

        assertEq(IERC20(usdc).balanceOf(address(forkWeValue)), 0, "USDC balance should be 0 after evacuation");
        console.log("After balance protectedAsset:", IERC20(usdc).balanceOf(address(forkWeValue)));

        uint256 finalDaiBalance = IERC20(dai).balanceOf(address(forkWeValue));
        assertTrue(finalDaiBalance > 0, "DAI balance should be greater than 0 after evacuation");
        console.log("Final DAI balance:", finalDaiBalance);

        assertEq(address(forkWeValue.protectedAsset()), dai, "protectedAsset should be rotated to DAI");
        assertEq(address(forkWeValue.priceOracle()), daiUsdOracle, "priceOracle should be rotated to DAI oracle");
        assertFalse(forkWeValue.evacuating(), "Evacuating flag should be false after completion");
    }

    /// @dev Тестирует успешную эвакуацию в форке mainnet. Вариант 2, простой обмен без флеш-кредита.
    function test_EvacuateIfDepegged_Fork_SimpleSwap_wbtc_Success() public {
        uint256 forkBlock = block.number;
        if (forkBlock == 0) return;

        // Адреса контрактов в Mainnet
        address aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address usdcUsdOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
        address wbtcUsdOracle = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;
        address uniswapRouter = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

        WeValue forkImplementation = new WeValue();
        uint256 depegThreshold = 101_000_000;

        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            ownerWallet,
            aavePool,
            usdcUsdOracle,
            usdc,
            wbtcUsdOracle,
            wbtc,
            depegThreshold,
            uniswapRouter,
            permit2
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(forkImplementation), initData);
        WeValue forkWeValue = WeValue(payable(address(proxy)));

        uint256 usdcAmountToEvacuate = 1_000_000_000 * 10**6; // 1,000 USDC (6 decimals)
        // Используем cheatcode `deal` для зачисления токенов на баланс контракта в форке
        deal(usdc, address(forkWeValue), usdcAmountToEvacuate);
        assertEq(IERC20(usdc).balanceOf(address(forkWeValue)), usdcAmountToEvacuate, "Initial USDC balance is incorrect");

        ( , int256 price, , , ) = AggregatorV3Interface(usdcUsdOracle).latestRoundData();
        console.log("Current USDC/USD Price (from Chainlink):", uint256(price));
        console.log("Depeg Threshold set in contract:", depegThreshold);
        console.log("Before balance protectedAsset:", IERC20(usdc).balanceOf(address(forkWeValue)));

        // Проверяем события нестрого, так как Uniswap может генерировать свои
        vm.expectEmit(true, true, true, false); // Не проверяем amountOut, так как он заранее неизвестен
        emit WeValue.AssetsEvacuated(usdcAmountToEvacuate, 0); // amountOut здесь игнорируется при нестрогой проверке
        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(usdc, wbtc);

        uint256 evacuationMinReturn = 1; // Гарантируем, что обмен произошел.
        vm.prank(owner);
        forkWeValue.evacuateIfDepegged(evacuationMinReturn, 0, 0, 0);

        assertEq(IERC20(usdc).balanceOf(address(forkWeValue)), 0, "USDC balance should be 0 after evacuation");
        console.log("After balance protectedAsset:", IERC20(usdc).balanceOf(address(forkWeValue)));

        uint256 finalWbtcBalance = IERC20(wbtc).balanceOf(address(forkWeValue));
        assertTrue(finalWbtcBalance > 0, "WBTC balance should be greater than 0 after evacuation");
        console.log("Final WBTC balance:", finalWbtcBalance);

        assertEq(address(forkWeValue.protectedAsset()), wbtc, "protectedAsset should be rotated to WBTC");
        assertEq(address(forkWeValue.priceOracle()), wbtcUsdOracle, "priceOracle should be rotated to WBTC oracle");
        assertFalse(forkWeValue.evacuating(), "Evacuating flag should be false after completion");
    }

    /// @dev Тестирует успешную эвакуацию в форке mainnet. Вариант 1, с флеш-кредитом.
    function test_EvacuateIfDepegged_Fork_Flashloan_Success() public {
        uint256 forkBlock = block.number;
        if (forkBlock == 0) return;

        console.log("=== AGGRESSIVE FLASH LOAN TEST: WETH/USDC ===");

        // Адреса контрактов в Mainnet
        address aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        
        // WETH - protectedAsset (то что эвакуируем)
        // USDC - safeAsset (то во что конвертируем)
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        
        // Оракулы
        address wethUsdOracle = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD
        address usdcUsdOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // USDC/USD
        
        address uniswapRouter = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

        WeValue forkImplementation = new WeValue();
        
        // Порог депега для WETH: $2900
        uint256 depegThreshold = 2900 * 10**8;

        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            ownerWallet,
            aavePool,
            wethUsdOracle,      // protectedAsset oracle (WETH)
            weth,               // protectedAsset (WETH)
            usdcUsdOracle,      // safeAsset oracle (USDC)
            usdc,               // safeAsset (USDC)
            depegThreshold,
            uniswapRouter,
            permit2
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(forkImplementation), initData);
        WeValue forkWeValue = WeValue(payable(address(proxy)));

        // СТРАТЕГИЯ МАНИПУЛЯЦИИ:
        // 1. Берем safeAsset (USDC) в флеш-кредит
        // 2. Продаем USDC → WETH (цена USDC падает, WETH растет)
        // 3. Теперь наш WETH стоит ДОРОЖЕ в терминах USDC!
        // 4. Продаем наши 500 WETH → USDC по улучшенному курсу
        // 5. Возвращаем флеш-кредит USDC + премия Aave (0.05%)
        // 6. Остаток USDC - наша прибыль от манипуляции!
        
        uint256 wethAmountToEvacuate = 500 * 10**18; // 500 WETH
        deal(weth, address(forkWeValue), wethAmountToEvacuate);
        
        console.log("Initial WETH to evacuate:", wethAmountToEvacuate / 1e18, "WETH");
        
        assertEq(
            IERC20(weth).balanceOf(address(forkWeValue)), 
            wethAmountToEvacuate, 
            "Initial WETH balance is incorrect"
        );

        // flashLoanAmount - берем USDC в кредит для манипуляции
        uint256 flashLoanAmount = 1_450_000 * 10**6; 
        
        // manipulationMinReturn - минимум WETH за проданный USDC
        uint256 manipulationMinReturn = 485 * 10**18;
        
        // simpleSwapMinReturn - сколько USDC получили бы БЕЗ манипуляции
        uint256 simpleSwapMinReturn = 1_450_000 * 10**6; 
        
        // evacuationMinReturn - минимум USDC после ВСЕЙ операции
        uint256 evacuationMinReturn = 1_500_000 * 10**6; 


        // Проверяем цену WETH
        ( , int256 wethPrice, , , ) = AggregatorV3Interface(wethUsdOracle).latestRoundData();
        console.log("Current WETH/USD Price:", uint256(wethPrice) / 1e8, "USD");
        console.log("Depeg Threshold:", depegThreshold / 1e8, "USD");

        // Ожидаем события
        vm.expectEmit(true, false, false, false);
        emit WeValue.AssetsEvacuated(wethAmountToEvacuate, 0);
        
        vm.expectEmit();
        emit WeValue.ProtectedAssetRotated(weth, usdc);

        console.log("");
        console.log("=== Executing evacuation ===");

        // Вызываем эвакуацию с флеш-кредитом
        vm.prank(owner);
        forkWeValue.evacuateIfDepegged(
            evacuationMinReturn,      // Минимум USDC на выходе
            flashLoanAmount,          // Сколько USDC берем в кредит
            manipulationMinReturn,    // Минимум WETH от продажи USDC
            simpleSwapMinReturn       // Базовая линия (для сравнения)
        );


        // Проверяем результаты
        uint256 finalWethBalance = IERC20(weth).balanceOf(address(forkWeValue));
        uint256 finalUsdcBalance = IERC20(usdc).balanceOf(address(forkWeValue));
        
        console.log("Final WETH balance:", finalWethBalance);
        console.log("Final USDC balance:", finalUsdcBalance / 1e6, "USDC");
        
        // WETH должен быть полностью эвакуирован
        assertEq(finalWethBalance, 0, "WETH should be fully evacuated");
        
        // USDC должен быть >= минимума
        assertTrue(finalUsdcBalance > 0, "Should have USDC");
        assertTrue(
            finalUsdcBalance >= evacuationMinReturn,
            "USDC should meet minimum requirement"
        );

        // Анализ прибыли
        console.log("");
        console.log("=== Profit Analysis ===");
        console.log("Expected without manipulation:", simpleSwapMinReturn / 1e6, "USDC");
        console.log("Actually received:", finalUsdcBalance / 1e6, "USDC");
        
        if (finalUsdcBalance > simpleSwapMinReturn) {
            uint256 profit = finalUsdcBalance - simpleSwapMinReturn;
            uint256 profitBps = (profit * 10000) / simpleSwapMinReturn;
            console.log("Profit from manipulation:", profit / 1e6, "USDC");
            console.log("Profit (basis points):", profitBps);
            
            // Должна быть прибыль минимум 1%
            assertTrue(profit > 0, "Should have profit from manipulation");
            assertTrue(profitBps >= 100, "Profit should be at least 1%");
        }

        // Проверяем ротацию активов
        assertEq(
            address(forkWeValue.protectedAsset()),
            usdc,
            "protectedAsset should be rotated to USDC"
        );
        assertEq(
            address(forkWeValue.priceOracle()),
            usdcUsdOracle,
            "priceOracle should be rotated to USDC oracle"
        );
        assertFalse(forkWeValue.evacuating(), "Evacuating flag should be reset");
        
        console.log("");
        console.log("=== SUCCESS! ===");
        console.log("Flash loan strategy successfully improved evacuation!");
    }

}
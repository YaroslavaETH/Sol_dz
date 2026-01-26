// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IOneInchRouter} from "./interfaces/IOneInchRouter.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

/**
 * @title Контракт благотворительного фонда WeValue
 * @author YaroslavaETH
 * @notice Этот контракт представляет собой токен для благотворительного фонда.
 * Он поддерживает пожертвования, обновляемость (UUPS), мета-транзакции,
 * а также имеет механизм защиты активов от обесценивания стейблкоинов.
 */
contract WeValue is Initializable, ERC20PermitUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    /// @dev Специальный адрес, используемый 1inch для обозначения нативного ETH.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // --- Переменные для интеграции ---
    IPool public AAVE_POOL;                 /// @notice Адрес пула Aave для флеш-кредитов.
    IOneInchRouter public ONE_INCH_ROUTER;  /// @notice Адрес роутера 1inch для обмена токенов.
    AggregatorV3Interface public PRICE_ORACLE; /// @notice Адрес оракула Chainlink для получения цены актива.
    AggregatorV3Interface public SAFE_ASSET_PRICE_ORACLE; /// @notice Адрес оракула Chainlink для получения цены безопасного актива.
    IERC20 public PROTECTED_ASSET; /// @notice Токен, в котором храним средства фонда (напр. USDC)
    IERC20 public SAFE_ASSET;      /// @notice Токен, в который эвакуируемся (напр. DAI)

    // --- Параметры безопасности ---
    uint256 public depegThreshold; /// @notice Порог цены для срабатывания защиты
    bool private _evacuating;      /// @dev Флаг для защиты от повторного входа (re-entrancy) в функцию эвакуации.

    // --- Основные переменные ---
    /// @notice Адрес доверенного отправителя для мета-транзакций (GSN).
    address private _trustedForwarder;

    // --- События ---
    /// @notice Событие, возникающее при изменении адреса доверенного отправителя.
    event TrustedForwarderChanged(address indexed newTrustedForwarder);

    /// @notice Событие, возникающее при получении пожертвования.
    event Donation(address indexed account, uint256 indexed amount);

    /// @notice Событие, возникающее при оказании помощи (для будущего функционала).
    event Help(address indexed account_to, uint256 indexed amount);

    /// @notice Событие, возникающее после успешной эвакуации активов.
    event AssetsEvacuated(uint256 amountIn, uint256 amountOut);
    
    /// @notice Событие, возникающее при изменении адреса безопасного актива.
    event SafeAssetChanged(address indexed newSafeAsset);

    /// @notice Событие, возникающее после конвертации ETH баланса контракта в PROTECTED_ASSET.
    event EthConverted(uint256 ethAmount, uint256 protectedAssetAmount);

    /// @notice Событие, возникающее после ротации активов, когда SAFE_ASSET становится новым PROTECTED_ASSET.
    event ProtectedAssetRotated(address indexed oldProtectedAsset, address indexed newProtectedAsset);
    
    /// @dev Вызывается при попытке пожертвовать 0 ETH.
    error NullDonation(address account);

    /// @dev Вызывается, когда цена защищаемого актива все еще стабильна и выше порогового значения.
    error PriceIsStable();

    /// @dev Вызывается при попытке повторного входа в функцию эвакуации, пока она уже выполняется.
    error EvacuationInProgress();

    /// @dev Вызывается, если колбэк флеш-кредита вызван не пулом Aave или произошла другая ошибка, связанная с займом.
    error FlashloanFailed();

    /// @dev Вызывается, если обмен на DEX не принес достаточно средств для погашения флеш-кредита и комиссии.
    error SwapFailed();
    
    /// @dev Вызывается при попытке конвертировать ETH, когда баланс равен нулю.
    error NoEthToConvert();
    
    /**
     * @dev Инициализирует контракт после его развертывания через прокси.
     * Этот метод вызывается только один раз.
     * @param initialOwner Адрес начального владельца контракта.
     * @param _trustedForwarderAddress Адрес доверенного отправителя.
     */
    function initialize(
        address initialOwner,
        address _trustedForwarderAddress,
        // --- Новые параметры для механизма защиты ---
        address aavePool,
        address oneInchRouter,
        address priceOracle,
        address protectedAsset,
        address safeAssetPriceOracle,
        address safeAsset,
        uint256 _depegThreshold
    ) public virtual initializer {
        __WeValue_init(recipient, initialOwner, _trustedForwarderAddress, aavePool, oneInchRouter, priceOracle, protectedAsset, safeAssetPriceOracle, safeAsset, _depegThreshold);
    }

    /**
     * @dev Внутренний инициализатор, который может быть вызван дочерними контрактами.
     */
    function __WeValue_init(
        address initialOwner,
        address _trustedForwarderAddress,
        address aavePool,
        address oneInchRouter,
        address priceOracle,
        address protectedAsset,
        address safeAssetPriceOracle,
        address safeAsset,
        uint256 _depegThreshold
    ) internal onlyInitializing {
        // Инициализация базовых контрактов OpenZeppelin.
        __ERC20_init("WeValue", "WEVALUE");
        __ERC20Permit_init("WeValue");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        // Установка основных параметров
        _setTrustedForwarder(_trustedForwarderAddress);

        // Установка параметров для механизма защиты
        AAVE_POOL = IPool(aavePool);
        ONE_INCH_ROUTER = IOneInchRouter(oneInchRouter);
        PRICE_ORACLE = AggregatorV3Interface(priceOracle);
        PROTECTED_ASSET = IERC20(protectedAsset);
        SAFE_ASSET_PRICE_ORACLE = AggregatorV3Interface(safeAssetPriceOracle);
        SAFE_ASSET = IERC20(safeAsset);
        depegThreshold = _depegThreshold;

    }
   
    /**
     * @dev Функция, вызываемая при попытке обновления контракта UUPS.
     * Только владелец контракта может авторизовать обновление.
     * @param newImplementation Адрес новой реализации контракта.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @notice Принимает пожертвования в ETH и выпускает токены WEVALUE в соотношении 1:1.
     */
    function donation() external payable virtual {
        if (msg.value == 0) {
            revert NullDonation(msg.sender);
        }
        
        // Выпускаем токены благотворителю, курс 1 к 1.
        _mint(_msgSender(), msg.value);
        emit Donation(_msgSender(), msg.value);
    }
    
    /**
     * @notice Конвертирует весь ETH баланс контракта в PROTECTED_ASSET.
     * @dev Доступна только владельцу. Требует данные для обмена от 1inch API.
     * @param pools Массив пулов для обмена, полученный от 1inch API.
     * @param minReturn Минимальное количество PROTECTED_ASSET, которое мы ожидаем получить.
     */
    function convertEthToProtectedAsset(address[] calldata pools, uint256 minReturn) external onlyOwner {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) {
            revert NoEthToConvert();
        }

        // Вызываем 1inch для обмена ETH на PROTECTED_ASSET
        uint256 receivedAmount = ONE_INCH_ROUTER.swap{value: ethBalance}(
            ETH_ADDRESS,
            ethBalance,
            minReturn,
            pools
        );

        emit EthConverted(ethBalance, receivedAmount);
    }

    /**
     * @notice Позволяет контракту принимать прямые переводы ETH.
     */
    receive() external payable {}
    
    /**
     * @dev Возвращает текущую версию контракта.
     * @return string memory Строка с номером версии.
     */
    function version()  external pure virtual returns (string memory) {
        return "1.0";   
    }
    
    /**
     * @notice Позволяет `spender` перевести `value` токенов от имени `owner`, используя подпись.
     * @dev Эта функция объединяет `permit` и `transferFrom` для удобства.
     * @param owner Адрес владельца токенов.
     * @param spender Адрес, который получит право на перевод и сами токены.
     * @param value Количество токенов для перевода.
     * @param deadline Срок действия подписи.
     * @return bool true, если перевод прошел успешно.
     */
    function transferWithPermit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (bool) {
        permit(owner, spender, value, deadline, v, r, s);
        // После успешного permit, spender (вызывающий эту функцию) имеет allowance.
        // Теперь он может перевести токены от имени owner на свой адрес.
        return transferFrom(owner, spender, value);
    }

    /**
     * @dev Проверяет, является ли адрес доверенным отправителем.
     * @param forwarder Адрес для проверки.
     * @return bool true, если адрес является доверенным отправителем.
     */
    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder == _trustedForwarder;
    }

    /**
     * @dev Возвращает адрес текущего доверенного отправителя.
     */
    function trustedForwarder() external view returns (address) {
        return _trustedForwarder;
    }

    /**
     * @dev Позволяет владельцу изменить адрес доверенного отправителя.
     * @param newTrustedForwarder Адрес нового доверенного отправителя.
     */
    function setTrustedForwarder(address newTrustedForwarder) public virtual onlyOwner {
        _setTrustedForwarder(newTrustedForwarder);
    }

    /**
     * @notice Позволяет владельцу изменить адрес безопасного актива (SAFE_ASSET).
     * @dev Это может быть полезно, если владелец решит, что другой стейблкоин является более надежным.
     * @param newSafeAsset Адрес нового безопасного актива.
     */
    function setSafeAsset(address newSafeAsset) external onlyOwner {
        SAFE_ASSET = IERC20(newSafeAsset);
        emit SafeAssetChanged(newSafeAsset);
    }

    /**
     * @dev Внутренняя функция для установки нового доверенного отправителя. Генерирует событие.
     * @param newTrustedForwarder Адрес нового доверенного отправителя.
     */
    function _setTrustedForwarder(address newTrustedForwarder) internal {
        _trustedForwarder = newTrustedForwarder;
        emit TrustedForwarderChanged(newTrustedForwarder);
    }

    /**
     * @dev Переопределение _msgSender для поддержки мета-транзакций.
     * Эта функция гарантирует, что все вызовы `_msgSender()` (например, в `OwnableUpgradeable`)
     * будут возвращать адрес исходного пользователя, а не адрес доверенного форвардера.
     */
    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return msg.sender;
        }
    }

    /**
     * @notice Запускает эвакуацию активов, если цена защищаемого токена упала ниже порога.
     * @dev Может быть вызвана кем угодно, но требует данные для обмена от 1inch API.
     * @param manipulationPools Пулы для манипулятивного обмена (SAFE_ASSET -> PROTECTED_ASSET).
     * @param evacuationPools Пулы для основного обмена (PROTECTED_ASSET -> SAFE_ASSET).
     * @param flashLoanAmount Сумма SAFE_ASSET, которую нужно занять для манипуляции.
     * @param manipulationMinReturn Минимальное количество PROTECTED_ASSET, ожидаемое от манипулятивного обмена.
     * @param evacuationMinReturn Минимальное количество SAFE_ASSET, ожидаемое от основного обмена.
     * @param simpleSwapMinReturn Ожидаемый результат от простого обмена (для проверки прибыльности).
     */
    function evacuateIfDepegged(
        address[] calldata manipulationPools,
        address[] calldata evacuationPools,
        uint256 flashLoanAmount,
        uint256 manipulationMinReturn,
        uint256 evacuationMinReturn,
        uint256 simpleSwapMinReturn
    ) external {
        if (_evacuating) {
            revert EvacuationInProgress();
        }

        // 1. Проверяем оракул
        (, int256 price, , , ) = PRICE_ORACLE.latestRoundData();

        // 2. Проверяем порог
        if (uint256(price) >= depegThreshold) {
            revert PriceIsStable();
        }

        _evacuating = true;

        // 3. Запрашиваем Flash Loan
        uint256 amountToEvacuate = PROTECTED_ASSET.balanceOf(address(this));
        if (amountToEvacuate > 0) {
            // Передаем все необходимые параметры в колбэк
            bytes memory params = abi.encode(amountToEvacuate, manipulationPools, evacuationPools, manipulationMinReturn, evacuationMinReturn, simpleSwapMinReturn);
            AAVE_POOL.flashLoanSimple(
                address(this),
                address(SAFE_ASSET),
                flashLoanAmount,
                params,
                0
            );
        }

        // После успешной эвакуации, производим ротацию активов:
        // бывший "безопасный" актив становится новым "защищаемым".
        address oldProtectedAsset = address(PROTECTED_ASSET);
        PROTECTED_ASSET = SAFE_ASSET;
        PRICE_ORACLE = SAFE_ASSET_PRICE_ORACLE;

        emit ProtectedAssetRotated(oldProtectedAsset, address(PROTECTED_ASSET));

        _evacuating = false;
    }

    /**
     * @dev Callback-функция, которую вызывает Aave после выдачи флеш-кредита.
     * В этой функции мы должны выполнить нашу логику и вернуть заемные средства с комиссией.
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // 1. Проверяем, что вызов пришел от пула Aave и мы являемся инициатором
        if (msg.sender != address(AAVE_POOL) || initiator != address(this)) {
            revert FlashloanFailed();
        }

        // 2. Декодируем параметры, которые мы передали в flashLoanSimple
        (uint256 amountToEvacuate, address[] memory manipulationPools, address[] memory evacuationPools, uint256 manipulationMinReturn, uint256 evacuationMinReturn, uint256 simpleSwapMinReturn) = abi.decode(params, (uint256, address[], address[], uint256, uint256, uint256));

        // 3. Манипуляция: Продаем заемные SAFE_ASSET, чтобы купить PROTECTED_ASSET и поднять его цену.
        // Даем разрешение 1inch потратить заемные SAFE_ASSET.
        IERC20(asset).approve(address(ONE_INCH_ROUTER), amount);
        ONE_INCH_ROUTER.swap(
            asset,
            amount,
            manipulationMinReturn,
            manipulationPools
        );

        // 4. Основной обмен: Продаем наши PROTECTED_ASSET по искусственно завышенной цене.
        // Вычисляем ВЕСЬ текущий баланс PROTECTED_ASSET (наши старые + купленные на шаге 3)
        uint256 totalProtectedAssetBalance = PROTECTED_ASSET.balanceOf(address(this));
        // Даем точечное разрешение 1inch потратить все эти токены.
        PROTECTED_ASSET.approve(address(ONE_INCH_ROUTER), totalProtectedAssetBalance);
        uint256 evacuatedAmount = ONE_INCH_ROUTER.swap(
            address(PROTECTED_ASSET),
            totalProtectedAssetBalance,
            evacuationMinReturn,
            evacuationPools
        );

        // Дополнительная проверка: убеждаемся, что основной обмен принес ожидаемое количество токенов.
        // Хотя роутер 1inch должен сам отменить транзакцию, если это условие не выполнено,
        // явная проверка в нашем коде добавляет дополнительный уровень безопасности.
        if (evacuatedAmount < evacuationMinReturn) revert SwapFailed();

        // 5. Проверка прибыльности: убеждаемся, что сложная стратегия принесла больше, чем принес бы простой обмен.
        // Если это не так, вся операция была бессмысленной.
        if (evacuatedAmount <= simpleSwapMinReturn) {
            revert SwapFailed(); // Стратегия не была прибыльной
        }

        // 6. Рассчитываем общую сумму к возврату (кредит + комиссия Aave)
        uint256 amountToRepay = amount + premium;

        // 7. Главная проверка безопасности: убеждаемся, что сумма, полученная от эвакуации,
        // достаточна для полного погашения флеш-кредита с комиссией.
        if (evacuatedAmount < amountToRepay) {
            revert SwapFailed();
        }

        emit AssetsEvacuated(amountToEvacuate, evacuatedAmount);

        // 8. Даем разрешение Aave забрать долг с комиссией.
        return IERC20(asset).approve(address(AAVE_POOL), amountToRepay);
    }

}

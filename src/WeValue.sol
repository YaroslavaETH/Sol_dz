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
    IPool public aavePool;                 /// @notice Адрес пула Aave для флеш-кредитов.
    IOneInchRouter public oneInchRouter;  /// @notice Адрес роутера 1inch для обмена токенов.
    AggregatorV3Interface public priceOracle; /// @notice Адрес оракула Chainlink для получения цены актива.
    AggregatorV3Interface public safeAssetPriceOracle; /// @notice Адрес оракула Chainlink для получения цены безопасного актива.
    IERC20 public protectedAsset; /// @notice Токен, в котором храним средства фонда (напр. USDC)
    IERC20 public safeAsset;      /// @notice Токен, в который эвакуируемся (напр. DAI)

    // --- Параметры безопасности ---
    uint256 public depegThreshold; /// @notice Порог цены для срабатывания защиты
    bool public evacuating;      /// @dev Флаг для защиты от повторного входа (re-entrancy) в функцию эвакуации.

    // --- Основные переменные ---
    /// @notice Адрес доверенного отправителя для мета-транзакций (GSN).
    address private _trustedForwarder;

    // --- События ---
    /// @notice Событие, возникающее при изменении адреса доверенного отправителя.
    event TrustedForwarderChanged(address indexed newTrustedForwarder);

    /// @notice Событие, возникающее при получении пожертвования.
    event Donation(address indexed account, uint256 indexed amount);

    /// @notice Событие, возникающее при оказании помощи (для будущего функционала).
    event Help(address indexed accountTo, uint256 indexed amount);

    /// @notice Событие, возникающее после успешной эвакуации активов.
    event AssetsEvacuated(uint256 amountIn, uint256 amountOut);
    
    /// @notice Событие, возникающее при изменении адреса безопасного актива.
    event SafeAssetChanged(address indexed newSafeAsset);

    /// @notice Событие, возникающее после конвертации ETH баланса контракта в protectedAsset.
    event EthConverted(uint256 ethAmount, uint256 protectedAssetAmount);

    /// @notice Событие, возникающее после ротации активов, когда safeAsset становится новым protectedAsset.
    event ProtectedAssetRotated(address indexed oldProtectedAsset, address indexed newProtectedAsset);
    
    // --- Ошибки ---
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
        address _aavePool,
        address _oneInchRouter,
        address _priceOracle,
        address _protectedAsset,
        address _safeAssetPriceOracle,
        address _safeAsset,
        uint256 _depegThreshold
    ) public virtual initializer {
        __WeValue_init(initialOwner, _trustedForwarderAddress, _aavePool, _oneInchRouter, _priceOracle, _protectedAsset, _safeAssetPriceOracle, _safeAsset, _depegThreshold);
    }

    /**
     * @dev Внутренний инициализатор, который может быть вызван дочерними контрактами.
     */
    function __WeValue_init(
        address initialOwner,
        address _trustedForwarderAddress,
        address _aavePool,
        address _oneInchRouter,
        address _priceOracle,
        address _protectedAsset,
        address _safeAssetPriceOracle,
        address _safeAsset,
        uint256 _depegThreshold
    ) internal onlyInitializing {
        // Сначала устанавливаем _trustedForwarder, так как от него зависит _msgSender,
        // который используется в инициализаторах родительских контрактов.
        _setTrustedForwarder(_trustedForwarderAddress);

        // Инициализация базовых контрактов OpenZeppelin.
        __ERC20_init("WeValue", "WEVALUE");
        __ERC20Permit_init("WeValue");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        // Установка параметров для механизма защиты
        aavePool = IPool(_aavePool);
        oneInchRouter = IOneInchRouter(_oneInchRouter);
        priceOracle = AggregatorV3Interface(_priceOracle);
        protectedAsset = IERC20(_protectedAsset);
        safeAssetPriceOracle = AggregatorV3Interface(_safeAssetPriceOracle);
        safeAsset = IERC20(_safeAsset);
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
            revert NullDonation(_msgSender());
        }
        
        // Выпускаем токены благотворителю, курс 1 к 1.
        _mint(_msgSender(), msg.value);
        emit Donation(_msgSender(), msg.value);
    }
    
    /**
     * @notice Конвертирует весь ETH баланс контракта в protectedAsset.
     * @dev Доступна только владельцу. Требует данные для обмена от 1inch API.
     * @param data Данные для обмена, полученный от 1inch API.
     * @param minReturn Минимальное количество protectedAsset, которое мы ожидаем получить.
     */
    function convertEthToProtectedAsset(bytes calldata data, uint256 minReturn) external onlyOwner {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) {
            revert NoEthToConvert();
        }

        // Вызываем 1inch для обмена ETH на protectedAsset
        uint256 receivedAmount = oneInchRouter.swap{value: ethBalance}(
            ETH_ADDRESS,
            address(protectedAsset), // Целевой токен
            ethBalance,
            minReturn,
            data
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
     * @notice Позволяет владельцу изменить адрес безопасного актива (safeAsset).
     * @dev Это может быть полезно, если владелец решит, что другой стейблкоин является более надежным.
     * @param newSafeAsset Адрес нового безопасного актива.
     */
    function setSafeAsset(address newSafeAsset) external onlyOwner {
        safeAsset = IERC20(newSafeAsset);
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
     * @dev Внутренняя функция для сменя токена, в котором храним средства фонда на защищенный.
     * Должна вызываться строго после успешной эвакуации.
     * Новый безопасный актив должен будет установить владелец.
     */
    function _rotateAsset() internal {
        address oldProtectedAsset = address(protectedAsset);
        protectedAsset = safeAsset;
        priceOracle = safeAssetPriceOracle;
        emit ProtectedAssetRotated(oldProtectedAsset, address(protectedAsset));
    }

    /**
     * @notice Запускает эвакуацию активов, если цена защищаемого токена упала ниже порога.
     * @dev Может быть вызвана кем угодно, но требует данные для обмена от 1inch API.
     * @param manipulationData Данные для манипулятивного обмена (safeAsset -> protectedAsset).
     * @param evacuationData Данные для основного обмена (protectedAsset -> safeAsset).
     * @param flashLoanAmount Сумма safeAsset, которую нужно занять для манипуляции.
     * @param manipulationMinReturn Минимальное количество protectedAsset, ожидаемое от манипулятивного обмена.
     * @param evacuationMinReturn Минимальное количество safeAsset, ожидаемое от основного обмена.
     * @param simpleSwapMinReturn Ожидаемый результат от простого обмена (для проверки прибыльности).
     */
    function evacuateIfDepegged(
        bytes calldata manipulationData,
        bytes calldata evacuationData,
        uint256 flashLoanAmount,
        uint256 manipulationMinReturn,
        uint256 evacuationMinReturn,
        uint256 simpleSwapMinReturn
    ) external {
        if (evacuating) {
            revert EvacuationInProgress();
        }

        // Проверяем цену защищаемого актива через оракул.
        (, int256 price, , , ) = priceOracle.latestRoundData();

        // Если цена выше или равна порогу, эвакуация не требуется.
        // casting to 'uint256' is safe because price is a non-negative value
        // forge-lint: disable-next-line(unsafe-typecast)
        if (uint256(price) >= depegThreshold) {
            revert PriceIsStable();
        }

        evacuating = true;

        // Если на балансе есть защищаемый актив, начинаем процесс эвакуации.
        uint256 amountToEvacuate = protectedAsset.balanceOf(address(this));
        if (amountToEvacuate > 0) {
            if(flashLoanAmount > 0){
            // Вариант 1: Флеш-кредит для манипуляции ценой
            // Кодируем параметры для передачи в колбэк флеш-кредита.
            bytes memory params = abi.encode(amountToEvacuate, manipulationData, evacuationData, manipulationMinReturn, evacuationMinReturn, simpleSwapMinReturn);
            aavePool.flashLoanSimple(
                address(this),
                address(safeAsset),
                flashLoanAmount,
                params,
                0
            );
            } else {
            // Вариант 2: Простой обмен без флеш-кредита
            protectedAsset.approve(address(oneInchRouter), amountToEvacuate);
            uint256 evacuatedAmount = oneInchRouter.swap(address(protectedAsset), address(safeAsset), amountToEvacuate, simpleSwapMinReturn, evacuationData);
            emit AssetsEvacuated(amountToEvacuate, evacuatedAmount);
            
            // Ротируем активы и сбрасываем флаг
            _rotateAsset();
            evacuating = false;
            }
        } else {
            // Вариант 3: Нет активов для эвакуации, просто ротируем и сбрасываем флаг
            _rotateAsset();
            evacuating = false;
        }
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
        // Проверяем, что колбэк вызван именно пулом Aave и для нашего контракта.
        if (msg.sender != address(aavePool) || initiator != address(this)) {
            revert FlashloanFailed();
        }

        // Декодируем параметры, переданные из основной функции.
        (uint256 amountToEvacuate, bytes memory manipulationData, bytes memory evacuationData, uint256 manipulationMinReturn, uint256 evacuationMinReturn, uint256 simpleSwapMinReturn) = abi.decode(params, (uint256, bytes, bytes, uint256, uint256, uint256));

        // Манипулятивный обмен: продаем заемный safeAsset, чтобы купить protectedAsset.
        // Даем разрешение роутеру 1inch потратить заемные средства.
        IERC20(asset).approve(address(oneInchRouter), amount);
        oneInchRouter.swap(
            asset,
            address(protectedAsset), // Целевой токен
            amount,
            manipulationMinReturn,
            manipulationData
        );

        // Основной обмен: продаем все protectedAsset по новой, более высокой цене.
        // Баланс включает как исходные активы, так и купленные на предыдущем шаге.
        uint256 totalProtectedAssetBalance = protectedAsset.balanceOf(address(this));
        // Даем разрешение роутеру 1inch на обмен.
        protectedAsset.approve(address(oneInchRouter), totalProtectedAssetBalance);
        uint256 evacuatedAmount = oneInchRouter.swap(
            address(protectedAsset),
            address(safeAsset), // Целевой токен
            totalProtectedAssetBalance,
            evacuationMinReturn,
            evacuationData
        );

        // Проверяем прибыльность: стратегия с флеш-кредитом должна быть выгоднее простого обмена.
        if (evacuatedAmount <= simpleSwapMinReturn) {
            revert SwapFailed(); // Стратегия не была прибыльной
        }

        // Рассчитываем сумму для погашения флеш-кредита с комиссией.
        uint256 amountToRepay = amount + premium;

        // Главная проверка: убеждаемся, что вырученных средств достаточно для погашения долга.
        if (evacuatedAmount < amountToRepay) {
            revert SwapFailed();
        }
        
        emit AssetsEvacuated(amountToEvacuate, evacuatedAmount);

        // Даем разрешение пулу Aave забрать сумму долга.
        IERC20(asset).approve(address(aavePool), amountToRepay);
        _rotateAsset();
        evacuating = false;

        return true;
    }

}

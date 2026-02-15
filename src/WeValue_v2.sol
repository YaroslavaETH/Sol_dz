// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";

/**
 * @title Контракт благотворительного фонда WeValue
 * @author YaroslavaETH
 * @notice Этот контракт представляет собой токен для благотворительного фонда.
 * Он поддерживает пожертвования, обновляемость (UUPS), мета-транзакции,
 * а также имеет механизм защиты активов от обесценивания стейблкоинов.
 */
contract WeValue is
    Initializable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    IPool public aavePool; /// @notice Адрес пула Aave для флеш-кредитов.
    IUniversalRouter public router; /// @notice Интерфейс для обмена Uniswap v4
    AggregatorV3Interface public priceOracle; /// @notice Адрес оракула Chainlink для получения цены актива.
    AggregatorV3Interface public safeAssetPriceOracle; /// @notice Адрес оракула Chainlink для получения цены безопасного актива.

    IERC20 public protectedAsset; /// @notice Токен, в котором храним средства фонда (напр. USDC)
    IERC20 public safeAsset; /// @notice Токен, в который эвакуируемся (напр. DAI)

    uint256 public depegThreshold; /// @notice Порог цены для срабатывания защиты
    bool public evacuating; /// @dev Флаг для защиты от повторного входа (re-entrancy) в функцию эвакуации.

    IPermit2 public permit2; /// @notice Адрес Permit2

    /// @notice Структура для хранения данных о выводе
    struct WithdrawalOperation {
        uint256 amount; // Сумма вывода
        address recipient; // Получатель
        bool offchain; // true - дальнейшя оплата вне сети и требуется подтверждение чеками, false - recipient и есть конечный получатель
        uint256 timestamp; // Время создания
        bytes32[] checks; // массив hash чеков
    }

    /// @notice Структура для хранения данных чека.
    struct Check {
        uint64 date; // Дата чека в формате YYYYMMDDHHSS
        uint64 fn; // ФН (Фискальный накопитель) чека
        uint32 fd; // ФД (Порядковый номер документа) чека
        uint32 fpd; // ФПД (Фискальный признак документа) чека
    }

    /// @notice маппинг всех чеков
    mapping(bytes32 hashCheck => Check check) public checks;

    /// @notice маппинг все операций вывода
    mapping(uint256 id => WithdrawalOperation) public withdrawalOperations;

    /// @notice Список ID неподтверждённых операций
    uint256[] public unconfirmedOperations;

    /// @notice Индекс для быстрого поиска позиции ID в массиве unconfirmedOperations. mapping(id операции => index в массиве unconfirmedOperations)
    mapping(uint256 => uint256) private unconfirmedOperationIndex;

    /// @notice Счетчик выводов
    uint256 public withdrawalCount;

    // --- События ---

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
    event ProtectedAssetRotated(
        address indexed oldProtectedAsset,
        address indexed newProtectedAsset
    );

    /// @notice Событие, возникающее при выводе средств
    event WithdrawalProtectedAsset(uint256 indexed operationId, uint256 amount, address token, address recipient, bool offchain);
    
    /// @notice Событие, возникающее при подтверждении операции вывода.
    event WithdrawalConfirmed(uint256 indexed operationId);

    /// @notice Событие, возникающее при добавлении чека.
    event AddCheckToWithdrawal(uint256 indexed operationId, uint64 date, uint64 fn, uint32 fd, uint32 fpd);

    // --- Ошибки ---
    /// @dev Вызывается при попытке пожертвовать 0 ETH.
    error NullDonation(address account);

    /// @dev Вызывается, когда цена защищаемого актива все еще стабильна и выше порогового значения.
    error PriceIsStable();

    /// @dev Вызывается при попытке повторного входа в функцию эвакуации, пока она уже выполняется.
    error EvacuationInProgress();

    /// @dev Вызывается, если колбэк флеш-кредита вызван не пулом Aave или произошла другая ошибка, связанная с займом.
    error FlashloanFailed();

    /// @dev Вызывается, если обмен на DEX через кредит оказался не выгоднее простого обмена 
    error EvacuationWithCreditFailed(uint256, uint256);

    /// @dev Вызывается при попытке конвертировать ETH, когда баланс равен нулю.
    error NoEthToConvert();

    error WithdrawalProtectedAssetFailed();

    /// @dev Вызывается при попытке подтвердить несуществующую операцию.
    error OperationNotFound();

    /// @dev Вызывается при попытке внести чек, который уже используется.
    error CheckAlreadyUsed();

    /// @dev Вызывается при попытке подтвердить операцию без единого чека.
    error OperationHasNoChecks();

    /// @dev Вызывается при попытке эвакуации, если не был установлен безопасный актив.
    error NeedSetSafeAsset();

    /// @dev Вызывается при попытке обмена, когда получили меньше чем хотели.
    error InsufficientOutputAmount(uint256, uint256);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Инициализирует контракт после его развертывания через прокси.
     * Этот метод вызывается только один раз.
     * @param name Имя токена.
     * @param symbol Символ токена.
     * @param initialOwner Адрес начального владельца контракта.
     * @param _aavePool Адрес пула Aave для флеш-кредитов.
     * @param _priceOracle Адрес оракула Chainlink для `protectedAsset`.
     * @param _protectedAsset Адрес токена `protectedAsset`.
     * @param _safeAssetPriceOracle Адрес оракула Chainlink для `safeAsset`.
     * @param _safeAsset Адрес токена `safeAsset`.
     * @param _depegThreshold Порог отвязки цены для `protectedAsset`.
     * @param _router Адрес роутера Uniswap.
     */
    function initialize(
        string memory name,
        string memory symbol,
        address initialOwner,
        address _aavePool,
        address _priceOracle,
        address _protectedAsset,
        address _safeAssetPriceOracle,
        address _safeAsset,
        uint256 _depegThreshold,
        address _router,
        address _permit2
    ) public virtual initializer {
        __WeValue_init(
            name,
            symbol,
            initialOwner,
            _aavePool,
            _priceOracle,
            _protectedAsset,
            _safeAssetPriceOracle,
            _safeAsset,
            _depegThreshold,
            _router,
            _permit2
        );
    }

    /**
     * @dev Внутренний инициализатор, который может быть вызван дочерними контрактами.
     */
    function __WeValue_init(
        string memory name,
        string memory symbol,
        address initialOwner,
        address _aavePool,
        address _priceOracle,
        address _protectedAsset,
        address _safeAssetPriceOracle,
        address _safeAsset,
        uint256 _depegThreshold,
        address _router,
        address _permit2
    ) internal onlyInitializing {

        // Инициализация базовых контрактов OpenZeppelin.
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        // Установка параметров для механизма защиты
        aavePool = IPool(_aavePool);
        priceOracle = AggregatorV3Interface(_priceOracle);
        protectedAsset = IERC20(_protectedAsset);
        safeAssetPriceOracle = AggregatorV3Interface(_safeAssetPriceOracle);
        safeAsset = IERC20(_safeAsset);
        depegThreshold = _depegThreshold;
        router = IUniversalRouter(_router);
        permit2 = IPermit2(_permit2);
    }

    /**
     * @dev Функция инициализации новых параметров второй версии
     * Вызывается при обновлении контракта для установки адресов, связанных с Uniswap.
     * @param _router Адрес роутера Uniswap.
     */
    function initializeV2(
        address _router,
        address _permit2
    ) public reinitializer(2) {
        router = IUniversalRouter(_router);
        permit2 = IPermit2(_permit2);
    }

    /**
     * @dev Функция, вызываемая при попытке обновления контракта UUPS.
     * Только владелец контракта может авторизовать обновление.
     * @param newImplementation Адрес новой реализации контракта.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    /**
     * @notice Позволяет контракту принимать прямые переводы ETH.
     */
    receive() external payable {}

    /**
     * @dev Возвращает текущую версию контракта.
     * @return string memory Строка с номером версии.
     */
    function version() external pure virtual returns (string memory) {
        return "0.2";
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
    function transferWithPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bool) {
        permit(owner, spender, value, deadline, v, r, s);
        // После успешного permit, spender (вызывающий эту функцию) имеет allowance.
        // Теперь он может перевести токены от имени owner на свой адрес.
        return transferFrom(owner, spender, value);
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
     * @dev Только для владельца.
     * @param evacuationMinReturn Минимальное количество safeAsset, ожидаемое от основного обмена.
     * @param flashLoanAmount Сумма safeAsset, которую нужно занять для манипуляции.
     * @param manipulationMinReturn Минимальное количество protectedAsset, ожидаемое от манипулятивного обмена.
     * @param simpleSwapMinReturn Ожидаемый результат от простого обмена (для проверки прибыльности).
     */
    function evacuateIfDepegged(
        uint256 evacuationMinReturn,
        uint256 flashLoanAmount,
        uint256 manipulationMinReturn,
        uint256 simpleSwapMinReturn
    ) external onlyOwner {
        if (evacuating) {
            revert EvacuationInProgress();
        }

        if(protectedAsset == safeAsset || address(safeAsset) == address(0)){
            revert NeedSetSafeAsset();
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
        uint128 amountToEvacuate = uint128(protectedAsset.balanceOf(address(this)));
        if (amountToEvacuate > 0) {
            if (flashLoanAmount > 0) {
                // Вариант 1: Флеш-кредит для манипуляции ценой
                // Кодируем параметры для передачи в колбэк флеш-кредита.
                bytes memory params = abi.encode(
                    amountToEvacuate,
                    manipulationMinReturn,
                    evacuationMinReturn,
                    simpleSwapMinReturn
                );
                aavePool.flashLoanSimple(
                    address(this),
                    address(safeAsset),
                    flashLoanAmount,
                    params,
                    0
                );
                return;
            } else {
                // Вариант 2: Простой обмен без флеш-кредита
                uint256 evacuatedAmount = _swapV4(
                    address(protectedAsset),
                    address(safeAsset),
                    amountToEvacuate,
                    evacuationMinReturn
                );

                emit AssetsEvacuated(amountToEvacuate, evacuatedAmount);
            }
        }
        // Произошел простой обмен или не было токенов для эвакуации и нужно просто сменить актив.
        // Ротируем активы и сбрасываем флаг
        _rotateAsset();
        evacuating = false;
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
        (
            uint256 amountToEvacuate,
            uint256 manipulationMinReturn,
            uint256 evacuationMinReturn,
            uint256 simpleSwapMinReturn
        ) = abi.decode(
                params,
                (uint256, uint256, uint256, uint256)
            );

        // Манипулятивный обмен: продаем заемный safeAsset, чтобы купить protectedAsset.
        _swapV4(
            asset,
            address(protectedAsset), // Целевой токен
            uint128(amount),
            manipulationMinReturn
        );

        // Основной обмен: продаем все protectedAsset по новой, более высокой цене.
        // Баланс включает как исходные активы, так и купленные на предыдущем шаге.
        uint256 totalProtectedAssetBalance = protectedAsset.balanceOf(
            address(this)
        );

        uint256 evacuatedAmount = _swapV4(
            address(protectedAsset),
            address(safeAsset), // Целевой токен
            totalProtectedAssetBalance,
            evacuationMinReturn
        );
        // Рассчитываем сумму для погашения флеш-кредита с комиссией.
        uint256 amountToRepay = amount + premium;
        
        // Проверяем прибыльность: стратегия с флеш-кредитом должна быть выгоднее простого обмена.
        uint256 winAmount = simpleSwapMinReturn + amountToRepay;
        if (evacuatedAmount  <= winAmount) {
            revert EvacuationWithCreditFailed(evacuatedAmount, winAmount); // Стратегия не была прибыльной
        }

        emit AssetsEvacuated(amountToEvacuate, evacuatedAmount);

        // Даем разрешение пулу Aave забрать сумму долга.
        IERC20(asset).approve(address(aavePool), amountToRepay);
        _rotateAsset();
        evacuating = false;

        return true;
    }
    /**
     * @notice Обменивает один токен на другой через Uniswap V4.
     * @param tokenIn Адрес токена, который отдаем. Используйте address(weth) для ETH.
     * @param tokenOut Адрес токена, который получаем.
     * @param amountIn Количество токена, которое отдаем.
     * @param minAmountOut Минимальное количество токена, которое ожидаем получить.
     * @return amountOut Фактическое количество полученного токена.
     */
    function _swapV4(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        // Если мы отдаем токен ERC20 (а не нативный ETH), одобряем его через Permit2
        if (tokenIn != address(0)) {
            // Сначала approve для Permit2
            IERC20(tokenIn).approve(address(permit2), amountIn);
            
            // Затем даем разрешение через Permit2 для UniversalRouter
            permit2.approve(
                tokenIn, 
                address(router), 
                uint160(amountIn), 
                uint48(block.timestamp + 600) 
            );
        }

        // Определяем PoolKey. Адреса должны быть отсортированы.
        bool zeroForOne = tokenIn < tokenOut;
        address token0 = zeroForOne ? tokenIn : tokenOut;
        address token1 = zeroForOne ? tokenOut : tokenIn;

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0), // Токен с меньшим адресом
            currency1: Currency.wrap(token1), // Токен с большим адресом
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(address(0)) // Без использования хуков
        });

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: uint128(amountIn),
                amountOutMinimum: uint128(minAmountOut),
                hookData: bytes("")
            })
        );
        // SETTLE_ALL: Pay the input token (tokenIn)
        params[1] = abi.encode(Currency.wrap(tokenIn), uint128(amountIn));
        // TAKE_ALL: Receive the output token (tokenOut)
        params[2] = abi.encode(Currency.wrap(tokenOut), uint128(0));

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Учтем баланс выходного токена до обмена
        uint256 amountBefore = IERC20(tokenOut).balanceOf(address(this));
        // Execute the swap
        uint256 deadline = block.timestamp + 600;
        // Execute the swap
        if (tokenIn == address(0)) {
            // Если мы меняем ETH, нужно передать его в вызове
            router.execute{value: amountIn}(commands, inputs, deadline);
        } else {
            router.execute(commands, inputs, deadline);
        }

        // Verify and return the output amount
        amountOut = IERC20(tokenOut).balanceOf(address(this)) - amountBefore;
        if (amountOut < minAmountOut) {
            revert InsufficientOutputAmount(amountOut, minAmountOut);     
        }
        return amountOut;
    }

    /**
     * @notice Конвертирует весь ETH баланс контракта в protectedAsset.
     * @dev Доступна только владельцу. Использует Uniswap V4 для обмена.
     * @param minAmountOut Минимальное количество protectedAsset, которое мы ожидаем получить.
     */
    function convertEthToProtectedAsset(
        uint256 minAmountOut
    ) external onlyOwner {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) {
            revert NoEthToConvert();
        }

        // Обмениваем ETH на protectedAsset через Uniswap V4
        uint256 receivedAmount = _swapV4(
            address(0),
            address(protectedAsset),
            ethBalance,
            minAmountOut
        );

        emit EthConverted(ethBalance, receivedAmount);
    }
    
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
     * @notice Возвращает количество неподтвержденных операций вывода.
     * @return uint256 Количество операций.
     */
    function getUnconfirmedOperationsCount() external view returns (uint256) {
        return unconfirmedOperations.length;
    }

    /**
     * @notice Возвращает количество чеков для конкретной операции вывода.
     * @param operationId ID операции вывода.
     * @return uint256 Количество чеков.
     */
    function getWithdrawalChecksCount(
        uint256 operationId
    ) external view returns (uint256) {
        return withdrawalOperations[operationId].checks.length;
    }

    /**
     * @notice Возвращает хеш чека по индексу для конкретной операции вывода.
     * @param operationId ID операции вывода.
     * @param index Индекс чека в массиве.
     * @return bytes32 Хеш чека.
     */
    function getWithdrawalCheckAtIndex(
        uint256 operationId,
        uint256 index
    ) external view returns (bytes32) {
        return withdrawalOperations[operationId].checks[index];
    }

    // Функция для вычисления уникального хеша чека
    function getReceiptHash(
        uint64 _fn,
        uint32 _fd,
        uint32 _fpd
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_fn, _fd, _fpd));
    }

    /**
     * @notice Создает запись о выводе средств и переводит защищенный актив получателю.
     * @dev Только для владельца. Транзакция будет полностью отменена (reverted), если перевод токенов не удастся.
     * Все изменения состояния (создание записи, обновление счетчиков) будут отменены вместе с транзакцией.
     * @param recipient Адрес получателя средств.
     * @param amount Сумма для вывода.
     */
    function withdrawalProtectedAsset(
        address recipient,
        uint256 amount,
        bool offchain
    ) external onlyOwner {
        // Обновляем состояние: создаем запись о выводе
        uint256 id = ++withdrawalCount;
        withdrawalOperations[id] = WithdrawalOperation({
            amount: amount,
            recipient: recipient,
            offchain: offchain, 
            timestamp: block.timestamp,
            checks: new bytes32[](0)
        });

        // Переводим токены
        bool success = protectedAsset.transfer(recipient, amount);
        if (!success) revert WithdrawalProtectedAssetFailed();
        emit WithdrawalProtectedAsset(id, amount, address(protectedAsset), recipient, offchain);
        
        if(offchain){
            // Добавляем ID в массив и сохраняем его индекс в маппинг
            unconfirmedOperationIndex[id] = unconfirmedOperations.length;
            unconfirmedOperations.push(id);
        }
        else {
            emit WithdrawalConfirmed(id);
        }

    }

    /**
     * @notice Добавляет фискальный чек к существующей операции вывода.
     * @dev Только для владельца. Можно добавить несколько чеков к одной операции.
     * @param operationId ID операции, к которой добавляется чек.
     * @param date Дата чека в формате YYYYMMDDHHSS.
     * @param fn Номер фискального накопителя.
     * @param fd Порядковый номер фискального документа.
     * @param fpd Фискальный признак документа.
     */
    function addCheckToWithdrawal(
        uint256 operationId,
        uint64 date,
        uint64 fn,
        uint32 fd,
        uint32 fpd
    ) external onlyOwner {
        // Проверяем, что такая операция существует в списке неподтвержденных.
        // Индекс 0 валиден, но если ID нет в маппинге, он вернет 0.
        // Поэтому дополнительно проверяем, что элемент на этом индексе действительно наш ID.
        uint256 indexToRemove = unconfirmedOperationIndex[operationId];
        if (
            unconfirmedOperations.length == 0 ||
            (indexToRemove == 0 && unconfirmedOperations[0] != operationId)
        ) {
            revert OperationNotFound();
        }

        // Вычисляем хеш чека
        bytes32 hashCheck = getReceiptHash(fn, fd, fpd);
        // Получаем указатель на место в хранилище для этого чека
        Check storage newCheck = checks[hashCheck];

        // Проверяем, что чек с таким хешем еще не был использован (поле fn будет 0)
        if (newCheck.fn != 0) revert CheckAlreadyUsed();

        newCheck.date = date;
        newCheck.fn = fn;
        newCheck.fd = fd;
        newCheck.fpd = fpd;

        // Добавляем хеш чека в массив операции
        WithdrawalOperation storage operation = withdrawalOperations[
            operationId
        ];
        operation.checks.push(hashCheck);
        emit AddCheckToWithdrawal(operationId, date, fn, fd, fpd);
    }

    /**
     * @notice Финализирует операцию вывода, удаляя ее ID из списка неподтвержденных.
     * @dev Только для владельца. Требует, чтобы к операции был добавлен хотя бы один чек.
     * Использует эффективный по газу алгоритм удаления из массива (O(1)).
     * @param operationId ID операции для подтверждения.
     */
    function confirmWithdrawal(uint256 operationId) external onlyOwner {
        // Проверяем, что такая операция существует в списке неподтвержденных.
        uint256 indexToRemove = unconfirmedOperationIndex[operationId];
        if (indexToRemove == 0 && unconfirmedOperations[0] != operationId) {
            revert OperationNotFound();
        }

        // Проверяем, что к операции привязан хотя бы один чек.
        if (withdrawalOperations[operationId].checks.length == 0) {
            revert OperationHasNoChecks();
        }

        // Чтобы удалить элемент из середины массива, перемещаем последний элемент на его место и удаляем последний.
        // Берем ID последнего элемента в массиве.
        uint256 lastElementId = unconfirmedOperations[
            unconfirmedOperations.length - 1
        ];

        // Перемещаем последний элемент на место удаляемого.
        unconfirmedOperations[indexToRemove] = lastElementId;

        // Обновляем индекс перемещенного элемента в маппинге.
        unconfirmedOperationIndex[lastElementId] = indexToRemove;

        //  Удаляем последний элемент из массива (теперь он дубликат).
        unconfirmedOperations.pop();
        delete unconfirmedOperationIndex[operationId];

        emit WithdrawalConfirmed(operationId);
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // This is OK because of remappings
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {IV4Router} from "lib/universal-router/lib/v4-periphery/src/interfaces/IV4Router.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {console} from "forge-std/Test.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";

// import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";

/// @dev Минимальный интерфейс для WeValue, необходимый мокам для разрыва циклических зависимостей.
interface IWeValue {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

// Мок токена ERC20
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

// Мок оракула Chainlink
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public latestAnswer;

    function setLatestAnswer(int256 _answer) public {
        latestAnswer = _answer;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, latestAnswer, block.timestamp, block.timestamp, 1);
    }

    // Неиспользуемые функции
    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "Mock";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80
    ) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert("Not implemented");
    }
}

// Мок пула Aave
contract MockAavePool is
    IPool // forgefmt: disable-line
{
    IWeValue public weValueContract;
    MockERC20 public safeAssetMock;
    uint256 public premium;

    function setWeValueContract(address _weValue) public {
        weValueContract = IWeValue(_weValue);
    }

    function setSafeAssetMock(MockERC20 _safeAssetMock) public {
        safeAssetMock = _safeAssetMock;
    }

    function setPremium(uint256 _premium) public {
        premium = _premium;
    }

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 /* referralCode */
    ) external override {
        // Имитируем флеш-кредит: выпускаем токены на адрес получателя (WeValue)
        safeAssetMock.mint(receiverAddress, amount);

        // Вызываем executeOperation на контракте WeValue
        weValueContract.executeOperation(
            asset,
            amount,
            premium,
            receiverAddress,
            params
        );

        // Имитируем погашение: сжигаем токены у получателя (WeValue)
        // Контракт WeValue должен был дать approve на `amount + premium`.
        safeAssetMock.burn(receiverAddress, amount + premium);
    }
}

/// @dev Мок для роутера Uniswap V4 (IUniversalRouter)
contract MockUniswapRouter {
    mapping(address => mapping(address => uint256)) public expectedSwapReturns;

    /// @dev Устанавливает ожидаемое количество токенов для возврата
    function setExpectedSwapReturn(
        address fromToken,
        address toToken,
        uint256 returnAmount
    ) public {
        expectedSwapReturns[fromToken][toToken] = returnAmount;
    }

    /// @dev Симулирует выполнение обмена. Принимает ETH и отправляет protectedAsset.
    function execute(
        bytes calldata,
        bytes[] calldata inputs,
        uint256
    ) external payable {
        (, bytes[] memory params) = abi.decode(inputs[0], (bytes, bytes[]));
        (IV4Router.ExactInputSingleParams memory swapParams) = abi.decode(params[0], (IV4Router.ExactInputSingleParams));

        address tokenIn = Currency.unwrap(swapParams.poolKey.currency0);
        address tokenOut = Currency.unwrap(swapParams.poolKey.currency1);
        if (!swapParams.zeroForOne) {
            (tokenIn, tokenOut) = (tokenOut, tokenIn);
        }

        if (tokenIn == address(0)) {
            require(msg.value > 0, "MockUniswapRouter: ETH not received");
        }

        // Отправляем вызывающему ожидаемое количество токенов
        MockERC20(tokenOut).mint(msg.sender, expectedSwapReturns[tokenIn][tokenOut]);
        // Сжигаем исходные токены, если это не нативный ETH
        if (tokenIn != address(0)) {
            MockERC20(tokenIn).burn(msg.sender, swapParams.amountIn);
        }
    }
}

/// @dev Упрощенный мок контракта Permit2 для тестирования
contract MockPermit2 {
    // Структура для хранения разрешений
    struct Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    // Маппинг разрешений: owner => token => spender => allowance
    mapping(address => mapping(address => mapping(address => Allowance))) public allowances;

    /// @notice Устанавливает разрешение для spender тратить токены owner
    /// @param token Адрес токена
    /// @param spender Адрес кому разрешено тратить
    /// @param amount Количество разрешенных токенов
    /// @param expiration Время истечения разрешения (unix timestamp)
    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        allowances[msg.sender][token][spender] = Allowance({
            amount: amount,
            expiration: expiration,
            nonce: 0
        });
    }

    /// @notice Переводит токены от from к to через Permit2
    /// @dev Упрощенная версия для тестирования
    /// @param from Адрес отправителя
    /// @param to Адрес получателя
    /// @param amount Количество токенов
    /// @param token Адрес токена
    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external {
        Allowance storage allowed = allowances[from][token][msg.sender];
        
        require(allowed.amount >= amount, "Insufficient allowance");
        require(allowed.expiration >= block.timestamp, "Allowance expired");
        
        // Уменьшаем разрешение
        allowed.amount -= amount;
        
        // Выполняем перевод токенов
        require(ERC20(token).transferFrom(from, to, amount), "Transfer failed");
    }

    /// @notice Получает информацию о разрешении
    /// @param owner Владелец токенов
    /// @param token Адрес токена
    /// @param spender Адрес кому разрешено
    function allowance(
        address owner,
        address token,
        address spender
    ) external view returns (uint160 amount, uint48 expiration, uint48 nonce) {
        Allowance memory allowed = allowances[owner][token][spender];
        return (allowed.amount, allowed.expiration, allowed.nonce);
    }

    /// @notice Проверяет, что разрешение валидно
    /// @param owner Владелец токенов
    /// @param token Адрес токена
    /// @param spender Адрес кому разрешено
    /// @param amount Требуемое количество
    function checkAllowance(
        address owner,
        address token,
        address spender,
        uint160 amount
    ) external view returns (bool) {
        Allowance memory allowed = allowances[owner][token][spender];
        return allowed.amount >= amount && allowed.expiration >= block.timestamp;
    }
}

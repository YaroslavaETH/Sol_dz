// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // This is OK because of remappings
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {IOneInchRouter} from "src/interfaces/IOneInchRouter.sol";
import {IPool} from "src/interfaces/IPool.sol";

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

// --- Мок токена ERC20 ---
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

// --- Мок оракула Chainlink ---
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

    // --- Неиспользуемые функции ---
    function decimals() external pure returns (uint8) { return 8; }
    function description() external pure returns (string memory) { return "Mock"; }
    function version() external pure returns (uint256) { return 1; }
    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) { revert("Not implemented"); }
}

// --- Мок роутера 1inch ---
contract MockOneInchRouter is IOneInchRouter {
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable PROTECTED_ASSET;
    address public immutable SAFE_ASSET;

    mapping(address => mapping(address => uint256)) public expectedSwapReturns;

    constructor(address _protectedAsset, address _safeAsset) {
        PROTECTED_ASSET = _protectedAsset;
        SAFE_ASSET = _safeAsset;
    }

    function setExpectedSwapReturn(address fromToken, address toToken, uint256 returnAmount) public {
        expectedSwapReturns[fromToken][toToken] = returnAmount;
    }

    function swap(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata data
    ) external payable override returns (uint256 returnAmount) {

        uint256 expected = expectedSwapReturns[fromToken][toToken];
        if (expected == 0) expected = minReturn; // Поведение по умолчанию, если не задано

        // Выпускаем возвращаемую сумму на адрес вызывающего (контракт WeValue)
        MockERC20(toToken).mint(msg.sender, expected);
        // Сжигаем сумму к обмену на адресе вызывающего (контракт WeValue)
        if (fromToken != ETH_ADDRESS) { // Только для ERC20 токенов
            MockERC20(fromToken).burn(msg.sender, amount);
        }
        return expected;
    }
}

// --- Мок пула Aave ---
contract MockAavePool is IPool { // forgefmt: disable-line
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
        weValueContract.executeOperation(asset, amount, premium, receiverAddress, params); 

        // Имитируем погашение: сжигаем токены у получателя (WeValue)
        // Контракт WeValue должен был дать approve на `amount + premium`.
        safeAssetMock.burn(receiverAddress, amount+premium);
    }
}

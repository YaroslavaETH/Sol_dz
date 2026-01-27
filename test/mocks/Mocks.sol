// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // This is OK because of remappings
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";
import {IOneInchRouter} from "src/interfaces/IOneInchRouter.sol";
import {IPool} from "src/interfaces/IPool.sol";

// --- Мок токена ERC20 ---
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
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
// Пока что достаточно простого контракта с адресом. Логику добавим позже.
contract MockOneInchRouter is IOneInchRouter {
    address public immutable WETH;
    address public immutable PROTECTED_ASSET;

    constructor(address _weth, address _protectedAsset) {
        WETH = _weth;
        PROTECTED_ASSET = _protectedAsset;
    }

    function swap(
        address fromToken,
        uint256 amount,
        uint256 minReturn,
        address[] calldata // pools (пулы)
    ) external payable override returns (uint256 returnAmount) {
        // Этот мок имитирует обмен ETH на PROTECTED_ASSET.
        // Он не использует реальную логику курсов, а просто пересылает токены.
        address toToken = PROTECTED_ASSET; // В нашем сценарии мы всегда меняем на PROTECTED_ASSET
        require(fromToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, "Mock: Only ETH swaps supported");
        require(msg.value == amount, "Mock: msg.value mismatch");

        uint256 amountToReturn = minReturn; // Для простоты возвращаем minReturn
        MockERC20(toToken).transfer(msg.sender, amountToReturn);
        return amountToReturn;
    }
}

// --- Мок пула Aave ---
// Пока что достаточно простого контракта с адресом. Логику добавим позже.
contract MockAavePool is IPool { // forgefmt: disable-line
    function flashLoanSimple(
        address, // receiverAddress
        address, // asset
        uint256, // amount
        bytes calldata, // params
        uint16 // referralCode
    ) external override {
        // Эта функция намеренно оставлена пустой.
    }
}

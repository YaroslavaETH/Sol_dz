// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOneInchRouter {
    function swap(
        address fromToken,
        address toToken, // Добавлен целевой токен
        uint256 amount,
        uint256 minReturn,
        address[] calldata pools
    ) external payable returns (uint256 returnAmount);
}

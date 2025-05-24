// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "contracts/iBank.sol";

interface IDepositeBank is INativeBank {
       
    /**
     * @dev Генерируется, когда пытаются внести нулевую сумму.
     * @param account Адрес аккаунта, который пытался внести средства.
     */
    error DepositAmountZero(address account);

    /**
     * @dev Генерируется, когда не удалось отправить средств на аккаунт 
     * @param account Адрес аккаунта, который пытался снять средства.
     * @param amount Сумма, которую пытались снять.
     */
    error CouldNotWithdraw(address account, uint256 amount);
    
    /**
     * @dev Владелец выводит все средства.
     * @param account Адрес, на который выводятся средства.
     */
    function escape(address account) external;
}
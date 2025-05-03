// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "contracts/iBank.sol";

interface IDepositBank is INativeBank {
    /**
     * @dev Генерируется, когда запрошен баланс несуществующего адреса.
     * @param account Адрес аккаунта, который запрашивал баланс.
     * @param client Адрес, чей баланс хотели узнать
     */
    error BalanceNonexceedClient(address account, address client);
   
       
}
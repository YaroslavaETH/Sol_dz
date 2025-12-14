// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Homework4.sol";

/**
 * Контракт Homework4V2
 * @dev Вторая версия контракта с измененной логикой.
 */
contract Homework4V2 is Homework4 {

    // Событие для новой логики
    event TodayV2(address indexed account, uint256 indexed timestamp);

    // Ошибка для новой логики
    error NotTodayV2(address account, uint256 timestamp);

    /**
     * @dev Инициализирует контракт после его развертывания через прокси.
     * Этот метод вызывается только один раз.
     * @param recipient Адрес, которому будут выпущены начальные токены.
     * @param initialOwner Адрес начального владельца контракта.
     * @param _trustedForwarderAddress Адрес доверенного отправителя.
     */
    function initialize(address recipient, address initialOwner, address _trustedForwarderAddress) public virtual override initializer {
        __Homework4_init(recipient, initialOwner, _trustedForwarderAddress);

        // Дадим еще 2000 токенов, чтобы проверить в тесте
        _mint(recipient, 2000 * 10 ** decimals());
    }

    /**
     * @dev Создает токены для вызывающего пользователя.
     * Токены могут быть созданы только в последний день месяца.
     * Количество создаваемых токенов зависит от дня.
     */
    function createTokens() external virtual override {
       uint256 endOfMonth = DateTime.getDaysInMonth(block.timestamp);
        if (endOfMonth != DateTime.getDay(block.timestamp)) {
            revert NotTodayV2(_msgSender(), block.timestamp);           
        }
        _mint(_msgSender(), endOfMonth * 1000 * 10 ** decimals());
        emit TodayV2(_msgSender(), block.timestamp);
    }
    
    /**
     * @dev Возвращает текущую версию контракта.
     * @return string memory Строка с номером версии.
     */
    function version()  external pure virtual override returns (string memory) {
        return "2.0";   
    }   
}
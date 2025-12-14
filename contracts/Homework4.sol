// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "contracts/DateTime.sol";


// Контракт токена Homework4.
// Поддерживает  ERC20permit, UUPS Upgradeable, MetaTransaction
contract Homework4 is Initializable, ERC20PermitUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    // адрес доверенного отправителя
    address private _trustedForwarder;

    // Событие при изменении доверенного отправителя.
    event TrustedForwarderChanged(address indexed newTrustedForwarder);

    // Событие при успешном создании токенов.
    event Today(address indexed account, uint256 indexed timestamp);
    
    // Пользовательская ошибка, при вызове функции `createTokens` в выходные дни.
    error NotToday(address account, uint256 timestamp);
    
    /**
     * @dev Инициализирует контракт после его развертывания через прокси.
     * Этот метод вызывается только один раз.
     * @param recipient Адрес, которому будут выпущены начальные токены.
     * @param initialOwner Адрес начального владельца контракта.
     * @param _trustedForwarderAddress Адрес доверенного отправителя.
     */
    function initialize(address recipient, address initialOwner, address _trustedForwarderAddress) public virtual initializer {
        __Homework4_init(recipient, initialOwner, _trustedForwarderAddress);
    }

    /**
     * @dev Внутренний инициализатор, который может быть вызван дочерними контрактами.
     */
    function __Homework4_init(address recipient, address initialOwner, address _trustedForwarderAddress) internal onlyInitializing {
        // Инициализация базовых контрактов OpenZeppelin.
        __ERC20_init("Homework4", "HW4");
        __ERC20Permit_init("Homework4");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        // Установка доверенного отправителя.
        _setTrustedForwarder(_trustedForwarderAddress);

        // Выпуск начального количества токенов получателю.
        _mint(recipient, 1000 * 10 ** decimals());
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
     * @dev Создает токены для вызывающего пользователя.
     * Токены могут быть созданы только в будний день.
     * Количество создаваемых токенов зависит от дня месяца.
     */
    function createTokens() external virtual {
        if (!DateTime.isWeekDay(block.timestamp)) {
            revert NotToday(_msgSender(), block.timestamp);           
        }
        // Выпускаем токены реальному отправителю. Количество = (день месяца) * 1000 * 10^decimals.
        _mint(_msgSender(), DateTime.getDay(block.timestamp) * 1000 * 10 ** decimals());
        emit Today(_msgSender(), block.timestamp);
    }

    /**
     * @dev Возвращает текущую версию контракта.
     * @return string memory Строка с номером версии.
     */
    function version()  external pure virtual returns (string memory) {
        return "1.0";   
    }
    
    /**
     * @dev Реализует пермит от имени подписавшего и затем сразу перевод средст.
     * @return bool результат трансфера
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
}

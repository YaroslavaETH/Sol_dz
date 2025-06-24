// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

contract SellNicknames {
    string public nicknameSpace; // название пространства никнеймов
    address public owner; // владелец пространства
    uint256 public price; // текущая цена покупки ника
    mapping (string nickname => address ownerNickname) public ownerOf; // владельцы ников

    
    error NicknameIsBusy(address _ownerNickname); // ошибка при невозможности купить ник, т.к. он уже занят
    error AnotherPrice(uint256 _currentPrice, uint256 _tryPrice); // ошибка при невозможности купить ник, т.к. не соотв. текущей цене
    error NotTheOwner(); // ошибка при попытке выполнить операцию доступную только владельцу кем-либо еще
    error RandomCall(); // ошибка обращения к контракту

    event BuyNickname(address indexed _ownerNickname, string indexed _nickname); // событие покупки ника
    event NewPrice(uint256 indexed _price); // событие установки новой цены
    
    /**
     * @notice Конструктор, инициализирующий пространство никнеймов.
     * @param _nicknameSpace Название пространства никнеймов.
     */
    constructor(string memory _nicknameSpace) {
        nicknameSpace = _nicknameSpace;
        owner = msg.sender;
    }
    
    /**
     * @notice Модификатор, который ограничивает выполнение функции только владельцем контракта.
     * @dev Если вызывающий не является владельцем, транзакция будет отменена с ошибкой NotTheOwner.
     */
    modifier onlyOwner {
        if(msg.sender != owner) revert NotTheOwner();
        _;
    }

    /**
     * @notice Устанавливает новую цену для покупки никнейма.
     * @dev Может быть вызвана только владельцем контракта. Генерирует событие NewPrice.
     * @param _price Новая цена для никнейма.
     */
    function setPrice(uint256 _price) public onlyOwner{
        price = _price;
        emit NewPrice(_price);
    }

    /**
     * @notice Позволяет пользователю купить никнейм.
     * @dev Пользователь должен отправить точное количество эфира, равное текущей цене.
     * @dev Отменяется, если никнейм уже занят (NicknameIsBusy) или если отправленная сумма неверна (AnotherPrice).
     * @param _nickname Желаемый никнейм для покупки.
     */
    function buyNickname(string calldata _nickname) external payable {
        address _currentOwner = ownerOf[_nickname];
        if(_currentOwner != address(0)) revert NicknameIsBusy(_currentOwner);
        uint256 _price = price;
        if (msg.value != _price) revert AnotherPrice(_price, msg.value);

        ownerOf[_nickname] = msg.sender;

        emit BuyNickname(msg.sender, _nickname);
    }

    /**
     * @notice Обрабатывает прямые переводы эфира на контракт.
     * @dev Отменяет любые прямые переводы эфира с ошибкой RandomCall,
     * так как покупка должна происходить через функцию buyNickname.
     */
    receive() external payable {
        revert RandomCall();
    }

    // функции вывода денег с контракта не написана для уменьшения объема тестирования
} 

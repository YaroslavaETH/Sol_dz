// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/**
 * @title IHwERC20
 * @dev Интерфейс для контракта по стандарту ERC-20.
 */
interface IHwERC20 {
    
    /**
     * @dev Возвращает имя токена. 
     */
    function name() external view returns (string memory);

    /**
     * @dev Возвращает тикер токена.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Возвращает количество десятичных знаков, используемых токеном. 
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Возвращает общее количество токенов. 
     */
    function totalSupply() external view returns (uint256);
     
    /**
     * @dev Возвращает текущий курс к eth. 
     */
    function exchangeRate() external view returns (uint8);
    
    /**
     * @dev Возвращает владельца. 
     */
    function ownerToken() external view returns (address);
      
    /**
     * @dev Возвращает остаток на счете.
     * @param _owner Адрес, баланс которого нужно проверить.
     */
    function balanceOf(address _owner) external view returns (uint256 balance);

    /**
     * @dev Переводит сумму токенов на указанный адрес.
     * @param _to Адрес получатель средств.
     * @param _value Переводимое количество.
     */
    function transfer(address _to, uint256 _value) external returns (bool success);
    
    /**
     * @dev Переводит количество токенов с адреса на адрес.
     * @param _from Адрес отправитель средств.
     * @param _to Адрес получатель средств.
     * @param _value Переводимое количество.
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    
    /**
     * @dev Дает разрешение стороннему адресу снимать средства со счета владельца несколько раз, вплоть до указанной суммы.
     * @param _spender Адрес реципиент.
     * @param _currentValue Текущий остаток допустимый к снятию.
     * @param _value Допустимое к снятию количество.
     */
    function approve(address _spender, uint256 _currentValue, uint256 _value) external returns (bool success);

    /**
     * @dev Возвращает сумму, которая доступна к снятию реципиентом у донора.
     * @param _owner Адрес донор.
     * @param _spender Адрес реципиент.
     */
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    /**
     * @dev Устанавливает новый курс, доступно только владельцу контракта.
     * @param _exchangeRate новый курс к eth.
     */
    function setExchangeRate(uint8 _exchangeRate) external returns (bool success);
    
    /**
     * @dev Покупка токенов.
     */
    function buy() external payable;
   
    /**
     * @dev Снимает средства со счёта. Доступно только владельцу контракта.
     * @param amount Сумма, которую нужно снять.
     */
    function withdraw(uint256 amount) external;

    /**
     * @dev Генерируется при переводе токенов.
     * @param _from Адрес отправитель средств.
     * @param _to Адрес получатель средств.
     * @param _value Переводимое количество.
     */
     event Transfer(address indexed _from, address indexed _to, uint256 _value);
    
    /**
     * @dev Генерируется при переводе токенов методом transferFrom.
     * @param _spender Адрес реципиент.
     * @param _from Адрес отправитель средств.
     * @param _to Адрес получатель средств.
     * @param _value Переводимое количество.
     */
     event Transfer(address indexed _spender, address indexed _from, address indexed _to, uint256 _value);
    
    /**
     * @dev Генерируется при установке разрешения донорства..
     * @param _owner Адрес донор.
     * @param _spender Адрес реципиент.
     * @param _value Допустимое к снятию количество.
     */
     event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /**
     * @dev Генерируется при установке разрешения донорства.
     * @param _owner Адрес донор.
     * @param _spender Адрес реципиент.
     * @param _oldValue Старый остаток допустимый к снятию.
     * @param _value Допустимое к снятию количество.
     */
     event Approval(address indexed _owner, address indexed _spender, uint256 _oldValue, uint256 _value);

    /**
     * @dev Генерируется при установке нового курса.
     * @param _exchangeRate новый курс к eth.
     */
    event SetExchangeRate(uint8 _exchangeRate);
    
    /**
     * @dev Генерируется при покупке новых токенов.
     * @param _to Адрес кто купил.
     * @param _value Количество токенов.
     * @param _exchangeRate Курс покупки.
     */
    event Buy(address _to, uint256 _value, uint256 _exchangeRate);

    /**
     * @dev Генерируется, когда владелец выводит со счёта контракта средства.
     * @param account Адрес на котороый переводятся средства.
     * @param amount Сумма, которая была снята.
     */
    event Withdrawal(address indexed account, uint256 amount);     
    
     /**
     * @dev Генерируется, когда не удалось отправить средств на аккаунт 
     * @param account Адрес аккаунта, который пытался снять средства.
     * @param amount Сумма, которую пытались снять.
     */
    error CouldNotWithdraw(address account, uint256 amount); 
    
    /**
     * @dev Генерируется, когда сумма снятия превышает баланс счёта.
     * @param account Адрес аккаунта, который пытался снять средства.
     * @param amount Сумма, которую пытались снять.
     * @param balance Текущий баланс контракта.
     */
    error WithdrawalAmountExceedsBalance(address account, uint256 amount, uint256 balance);
    
    /**
     * @dev Генерируется, когда пытаются снять нулевую сумму.
     * @param account Адрес аккаунта, который пытался снять средства.
     */
    error WithdrawalAmountZero(address account);


}

interface IHwERC6093 is IHwERC20 {
    /**
     * @dev Генерируется, когда сумма снятия превышает баланс счёта.
     * @param sender Адрес аккаунта, c которого пытались снять средства.
     * @param balance Текущий остаток.
     * @param needed Сумма, которую пытались снять.
    */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    /**
     * @dev Генерируется при нулевом адресе отправителе
     * @param sender Адрес отправитель средств.
    */
    error ERC20InvalidSender(address sender);
    /**
     * @dev Генерируется при нулевом адресе отправителе
     * @param receiver Адрес получатель средств.
    */
    error ERC20InvalidReceiver(address receiver);
    /**
     * @dev Генерируется, когда допустимый разрешенный остаток к снятию превышает запрашиваемый на перевод.
     * @param spender Адрес аккаунта, который пытался снять средства.
     * @param allowance Текущий остаток допустимый к снятию.
     * @param needed Сумма, которую пытались снять.
    */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    /**
     * @dev Генерируется при нулевом адресе донора
     * @param approver Адрес донор.
    */
    error ERC20InvalidApprover(address approver);
    /**
     * @dev Генерируется при попытке дать разрешение нулевому адресу или владельцу
     * @param spender Адрес получатель.
    */
    error ERC20InvalidSpender(address spender);
}
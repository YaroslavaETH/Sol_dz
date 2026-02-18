// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title MultiSigWallet
 * @notice Мультисиг кошелек для управления контрактом WeValue
 * @dev Позволяет нескольким владельцам совместно управлять контрактом
 */
contract MultiSigWallet {
    // ========== События ==========
    
    event TransactionProposed(
        uint256 indexed txId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        bytes data,
        string description
    );
    
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event ConfirmationRevoked(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId, address indexed executor);
    event TransactionRejected(uint256 indexed txId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequirementChanged(uint256 required);
    
    // ========== Ошибки ==========
    
    error NotOwner();
    error TransactionDoesNotExist();
    error TransactionAlreadyExecuted();
    error TransactionAlreadyConfirmed();
    error TransactionNotConfirmed();
    error CannotExecuteTransaction();
    error InvalidRequirement();
    error OwnerAlreadyExists();
    error OwnerDoesNotExist();
    error InvalidAddress();
    error TransactionFailed();
    
    // ========== Структуры ==========
    
    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        string description;
        uint256 timestamp;
    }
    
    // ========== Переменные ==========
    
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    
    // ========== Модификаторы ==========
    
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }
    
    modifier txExists(uint256 txId) {
        if (txId >= transactions.length) revert TransactionDoesNotExist();
        _;
    }
    
    modifier notExecuted(uint256 txId) {
        if (transactions[txId].executed) revert TransactionAlreadyExecuted();
        _;
    }
    
    modifier notConfirmed(uint256 txId) {
        if (confirmations[txId][msg.sender]) revert TransactionAlreadyConfirmed();
        _;
    }
    
    // ========== Конструктор ==========
    
    constructor(address[] memory _owners, uint256 _required) {
        if (_owners.length == 0) revert InvalidRequirement();
        if (_required == 0 || _required > _owners.length) revert InvalidRequirement();
        
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            
            if (owner == address(0)) revert InvalidAddress();
            if (isOwner[owner]) revert OwnerAlreadyExists();
            
            isOwner[owner] = true;
            owners.push(owner);
        }
        
        required = _required;
    }
    
    // ========== Основные функции ==========
    
    /**
     * @notice Предложить новую транзакцию
     */
    function proposeTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external onlyOwner returns (uint256 txId) {
        txId = transactions.length;
        
        transactions.push(Transaction({
            target: target,
            value: value,
            data: data,
            executed: false,
            confirmations: 0,
            description: description,
            timestamp: block.timestamp
        }));
        
        emit TransactionProposed(txId, msg.sender, target, value, data, description);
        
        // Автоматически подтверждаем от создателя
        confirmTransaction(txId);
        
        return txId;
    }
    
    /**
     * @notice Подтвердить транзакцию
     */
    function confirmTransaction(uint256 txId)
        public
        onlyOwner
        txExists(txId)
        notExecuted(txId)
        notConfirmed(txId)
    {
        confirmations[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;
        
        emit TransactionConfirmed(txId, msg.sender);
        
        // Автоматически выполняем при достижении кворума
        if (transactions[txId].confirmations >= required) {
            executeTransaction(txId);
        }
    }
    
    /**
     * @notice Отозвать подтверждение
     */
    function revokeConfirmation(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        if (!confirmations[txId][msg.sender]) revert TransactionNotConfirmed();
        
        confirmations[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;
        
        emit ConfirmationRevoked(txId, msg.sender);
    }
    
    /**
     * @notice Выполнить транзакцию
     */
    function executeTransaction(uint256 txId)
        public
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        Transaction storage txn = transactions[txId];
        
        if (txn.confirmations < required) revert CannotExecuteTransaction();
        
        txn.executed = true;
        
        (bool success, ) = txn.target.call{value: txn.value}(txn.data);
        if (!success) revert TransactionFailed();
        
        emit TransactionExecuted(txId, msg.sender);
    }
    
    // ========== View функции ==========
    
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }
    
    function getTransaction(uint256 txId)
        external
        view
        txExists(txId)
        returns (
            address target,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmationsCount,
            string memory description,
            uint256 timestamp
        )
    {
        Transaction storage txn = transactions[txId];
        return (
            txn.target,
            txn.value,
            txn.data,
            txn.executed,
            txn.confirmations,
            txn.description,
            txn.timestamp
        );
    }
    
    function hasConfirmed(uint256 txId, address owner)
        external
        view
        returns (bool)
    {
        return confirmations[txId][owner];
    }
    
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
    
    function getOwnersCount() external view returns (uint256) {
        return owners.length;
    }
    
    function getPendingTransactions() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (!transactions[i].executed) {
                count++;
            }
        }
        
        uint256[] memory pending = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (!transactions[i].executed) {
                pending[index] = i;
                index++;
            }
        }
        
        return pending;
    }
    
    // ========== Управление владельцами (через мультисиг) ==========
    
    function addOwner(address owner) external {
        if (msg.sender != address(this)) revert NotOwner();
        if (owner == address(0)) revert InvalidAddress();
        if (isOwner[owner]) revert OwnerAlreadyExists();
        
        isOwner[owner] = true;
        owners.push(owner);
        
        emit OwnerAdded(owner);
    }
    
    function removeOwner(address owner) external {
        if (msg.sender != address(this)) revert NotOwner();
        if (!isOwner[owner]) revert OwnerDoesNotExist();
        if (owners.length - 1 < required) revert InvalidRequirement();
        
        isOwner[owner] = false;
        
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        
        emit OwnerRemoved(owner);
    }
    
    function changeRequirement(uint256 _required) external {
        if (msg.sender != address(this)) revert NotOwner();
        if (_required == 0 || _required > owners.length) revert InvalidRequirement();
        
        required = _required;
        
        emit RequirementChanged(_required);
    }
    
    // ========== Fallback ==========
    
    receive() external payable {}
}

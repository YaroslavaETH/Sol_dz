// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

contract SellNicknames {
    string public nicknameSpace;
    address public owner;
    uint256 public price;
    mapping (string nickname => address ownerNickname) public ownerOf;

    error NicknameIsBusy(address _ownerNickname);
    error AnotherPrice(uint256 _currentPrice, uint256 _tryPrice);
    error NotTheOwner();
    error RandomCall();

    event BuyNickname(address indexed _ownerNickname, string indexed _nickname);
    event NewPrice(uint256 indexed _price);

    constructor(string memory _nicknameSpace) {
        nicknameSpace = _nicknameSpace;
        owner = msg.sender;
    }

    modifier onlyOwner {
        if(msg.sender != owner) revert NotTheOwner();
        _;
    }

    function setPrice(uint256 _price) public onlyOwner{
        price = _price;
        emit NewPrice(_price);
    }

    function buyNickname(string calldata _nickname) external payable {
        //address _currentOwner = checkNickname(_nickname);
        address _currentOwner = ownerOf[_nickname];
        if(_currentOwner != address(0)) revert NicknameIsBusy(_currentOwner);
        uint256 _price = price;
        if (msg.value != _price) revert AnotherPrice(_price, msg.value);

        ownerOf[_nickname] = msg.sender;

        emit BuyNickname(msg.sender, _nickname);
    }

    receive() external payable {
        //revert RandomCall();
        revert NotTheOwner();
    }

    // функции вывода денег с контракта не написана для уменьшения объема тестирования
} 

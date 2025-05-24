// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "contracts/iHwERC721.sol";
// контракт для бронирования помещений
contract HwERC721 is IHwERC721{ 
    
    string public override name;
    string public override symbol;

    string public override addressOfObject; 
    address public override ownerObject;
    address public override adminObject;

    struct Room {
        uint8 floor; // номер этажа
        string nameRoom;  // название команты (номер команты или ее название)
        string descriptionRoom;// описание команты
        uint8 square; // площадь команты
    }
    Room[] private rooms;

    mapping(address _owner => uint256 balance) public override balanceOf;
    mapping(uint256 _tokenId => address _owner) public override ownerOf;
    mapping(uint256 _tokenId => address _approved) public override getApproved;
    mapping(address _owner => mapping(address _approved => bool))  public override isApprovedForAll;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _addressOfObject
    ) {
        name = _name;
        symbol = _symbol;
        addressOfObject = _addressOfObject;

        ownerObject = msg.sender;
        adminObject = msg.sender;
        rooms.push(Room(0, "Room of Requirement", "Open only when needed", 0));
    }

    modifier onlyOwnerObject {
        require(msg.sender == ownerObject, "Not the owner of object!");
        _;
    }
    modifier onlyAdminObject {
        require(msg.sender == adminObject, "Not the administrator of object!");
        _;
    }
    modifier onlyOwnerOrAdminObject {
        require(msg.sender == ownerObject || msg.sender == adminObject, "Not the owner or the administrator of object!");
        _;
    }

    modifier onlyOwnerOrApprovedNFT(uint256 _tokenId) {
        address _owner = ownerOf[_tokenId];
        require(msg.sender == _owner
                || msg.sender == getApproved[_tokenId]
                || isApprovedForAll[_owner][msg.sender]
                , "You aren't an owner or an approved of the NFT!");
        _;  
    }
    
    function decimals() public pure returns (uint8){
        return uint8(0);
    }

    function totalSupply() public view returns (uint256){
        return rooms.length - 1;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external payable onlyOwnerOrApprovedNFT(_tokenId){
        require(_from != address(0), "Invalid address from");
        require(_to != address(0), "Invalid address to");
        require(_from == ownerOf[_tokenId], "Address from isn't an owner of the NFT!");
        balanceOf[_from] += balanceOf[_from];
        balanceOf[_to] += balanceOf[_to];
        ownerOf[_tokenId] = _to;
        delete getApproved[_tokenId];
        emit Transfer(_from, _to, _tokenId);
    } 

    function approve(address _approved, uint256 _tokenId) external payable onlyOwnerOrApprovedNFT(_tokenId){
        require(_approved != address(0), "Invalid approved");
        getApproved[_tokenId] = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) external{
        require(_operator != address(0), "Invalid approved");
        isApprovedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }  

    function addRoom(uint8 _floor, string calldata  _nameRoom, string  calldata  _descriptionRoom, uint8 _square) external onlyOwnerOrAdminObject returns(uint256){
        
        Room memory _newRoom = Room(_floor ,_nameRoom, _descriptionRoom, _square);
        rooms.push(_newRoom); 
        uint256 _tokenId = totalSupply();      
        ownerOf[_tokenId] = ownerObject;
        balanceOf[ownerObject] += balanceOf[ownerObject];
        emit Transfer(address(0), ownerObject, _tokenId);
        return _tokenId;
    }     

      function getRoom(uint256 _tokenId) external view returns (uint8 _floor, string memory _nameRoom, string memory _descriptionRoom, uint8 _square){
        Room memory currentRoom = rooms[_tokenId];
        return (currentRoom.floor, currentRoom.nameRoom, currentRoom.descriptionRoom, currentRoom.square);
    }      

    function setAdministrator(address _adminObject) external onlyOwnerObject {
        adminObject = _adminObject;  
    }      
   
}
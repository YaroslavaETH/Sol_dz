// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "contracts/iHwERC20.sol";

contract HwERC6093 is IHwERC6093{ 

    string public override name;
    string public override symbol;
    uint8 public override decimals;

    uint256 public override totalSupply;
    uint8 public override exchangeRate;
    address public override ownerToken;
    mapping(address account => uint256 balance) public override balanceOf;
    mapping(address owner => mapping(address spender => uint256 _value)) public override allowance;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply,
        uint8 _exchangeRate
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply * (10 ** _decimals);
        exchangeRate = _exchangeRate;
        ownerToken = msg.sender;
    }
    modifier onlyOwnerToken {
        require(msg.sender == ownerToken, "Not the owner of token!");
        _;
    }
    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        if (_from == address(0)) {
            revert ERC20InvalidSender(_from);
        }
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(_to);
        }
        uint256 balance = balanceOf[_from];
        if (balance < _value) {
            revert ERC20InsufficientBalance(_from, balance, _value);
        }
        unchecked {
            balanceOf[_from] = balance - _value;
        }
        balanceOf[_to] += _value;

        emit Transfer(_from, _to, _value);
    }
    
    function transfer(address _to, uint256 _value) external returns (bool success){
        _transfer(msg.sender, _to, _value);

        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success){
        if (_from != msg.sender) {
            uint256 _allowance = allowance[_from][msg.sender];
            if (_allowance < _value) {
                revert ERC20InsufficientAllowance(msg.sender, _allowance, _value);
            }
            unchecked{
                allowance[_from][msg.sender] = _allowance - _value;
            }
        }
        _transfer(_from, _to, _value);
        emit Transfer(msg.sender, _from, _to, _value);

        return true;
    }
    
    function approve(address _spender, uint256 _currentValue, uint256 _value) external returns (bool success){
        if (_spender == address(0) || msg.sender == _spender){ revert ERC20InvalidSpender(_spender);}

        uint256 _oldValue = allowance[msg.sender][_spender];
        if (_oldValue != _currentValue) { return false;} 

        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Approval(msg.sender, _spender, _oldValue, _value);

        return true;
    }

    function setExchangeRate(uint8 _exchangeRate) external  onlyOwnerToken returns (bool success){
        if(_exchangeRate == 0) {return false;}
        exchangeRate = _exchangeRate;
        emit SetExchangeRate(_exchangeRate);
        return true;
     }

    function _buy(address _owner, uint256 _value) internal{
        uint256 _amount = (_value * exchangeRate * (10 ** decimals));
        balanceOf[_owner] += _amount;
        totalSupply += _amount;
        emit Buy(_owner, _amount, exchangeRate); 
    }

    function buy() external payable{   
        _buy(msg.sender, msg.value);      
    }

    receive() external payable { 
        _buy(msg.sender, msg.value);
    }   

     function withdraw(uint256 amount) external onlyOwnerToken{
        if (amount == 0){revert WithdrawalAmountZero(msg.sender);}
        uint256 balance = address(this).balance;
        if(balance < amount) {revert WithdrawalAmountExceedsBalance(msg.sender, amount, balance);}
        (bool success, ) = msg.sender.call{value: amount}("");
        if(success == false){ revert CouldNotWithdraw(msg.sender, amount);}
        emit Withdrawal(msg.sender, amount); 
     }

}
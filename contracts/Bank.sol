// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "contracts/iBank.sol";

contract Bank is INativeBank {
	
	// Variables 
	address private owner;
    mapping (address => uint256) public balances;
    mapping (address => bool) public locked; 
       
    constructor() {
        owner = msg.sender;
        }

    modifier OnlyOwner {
        require(msg.sender == owner, "Not the owner!");
        _;
    }

    fallback() external payable { 
        save();
    }
    receive() external payable { 
        save();
    }
    
    function balanceOf(address account) external view returns(uint256){
            return balances[account];
    }

    function deposit() external payable{
            save();
    }

    function save() private {
        require(msg.value > 0, "Amount should be more than 0!");
             balances[msg.sender] += msg.value;
             emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(address payable account, uint256 amount) external payable {
        require(account == msg.sender,"Not your wallet!");
        if(amount == 0){ revert WithdrawalAmountZero(account);}
        require(amount > 0, "Amount should be more than 0!");
        require(!locked[account], "Sumultaneouse withdraw!");
        if(balances[account] < amount) {
             revert WithdrawalAmountExceedsBalance(account, amount, balances[account]);
        }

        locked[account] = true;    
        account.transfer(amount);
        balances[account] -= amount;
        locked[account] = false;
        emit Withdrawal(account, amount); 
    }

    function escape(address payable account) external payable OnlyOwner {
        account.transfer(address(this).balance); 
    }
}
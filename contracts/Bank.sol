// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "contracts/iDepositBank.sol";

contract Bank is IDepositeBank {
	
	// Variables 
	address private owner;
    mapping (address account => uint256 amount) public balanceOf;
       
    constructor() {
        owner = msg.sender;
        }

    modifier onlyOwner {
        require(msg.sender == owner, "Not the owner!");
        _;
    }

    receive() external payable { 
        save();
    }    

    function deposit() external payable{
            if (msg.value == 0){ revert DepositAmountZero(msg.sender); }  
            save();
    }

    function save() private {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) external {
        if(amount == 0){ revert WithdrawalAmountZero(msg.sender);}
        uint256 balance = balanceOf[msg.sender];
        if(balance < amount) {
             revert WithdrawalAmountExceedsBalance(msg.sender, amount, balance);
        }
        balanceOf[msg.sender] = balance - amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        if(success == false){ revert CouldNotWithdraw(msg.sender, amount);}
        emit Withdrawal(msg.sender, amount); 
    }

    function escape(address account) external onlyOwner {
        uint256 allBalance =  address(this).balance;
        (bool success, ) = account.call{value: allBalance}(""); 
        if(success == false){ revert CouldNotWithdraw(msg.sender, allBalance);}
    }
}
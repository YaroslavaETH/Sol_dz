// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {WeValue} from "./WeValue.sol";

// Контракта фабрики CloneWeValue
contract CloneWeValue is Ownable {
    error ImplementationIsNotAContract(address implementation);

    event WeValueDeployed(address newContract, address implementation);
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    // Возвращает адрес будущего прокси
    function predictNewAddress(
        address implementation,
        bytes32 salt
    ) public view returns (address predicted) { 
       return Clones.predictDeterministicAddress(
            implementation,
            salt,
            address(this));
    }

    // Деплой прокси через CREATE2
    function deployWeValue(
        address implementation,
        bytes32 salt
    ) public onlyOwner returns (address instance) {
            if (implementation.code.length == 0) {
                revert ImplementationIsNotAContract(implementation);
            }
            instance = Clones.cloneDeterministic(implementation, salt);
            emit WeValueDeployed(instance, implementation);
            return instance;
    }
}

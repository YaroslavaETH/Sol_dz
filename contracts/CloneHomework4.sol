// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import {Homework4} from "./Homework4.sol";

// Контракта фабрики CloneHomework4
contract CloneHomework4 {
    event Homework4Deployed(address newContract, address implementation);

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
    function deployHomework4(
        address implementation,
        bytes32 salt
    ) public returns (address instance) {
            instance = Clones.cloneDeterministic(implementation, salt);
            emit Homework4Deployed(instance, implementation);
            return instance;
    }
}

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Фабрика для создания клонов контракта WeValue
 * @author YaroslavaETH
 * @notice Этот контракт позволяет владельцу развертывать дешевые,
 * детерминированные прокси-контракты (клоны) на основе реализации WeValue.
 */
contract CloneWeValue is Ownable {
    error ImplementationIsNotAContract(address implementation);

    event WeValueDeployed(address newContract, address implementation);
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @notice Предсказывает адрес будущего прокси-контракта без его развертывания.
     * @param implementation Адрес контракта-реализации.
     * @param salt Произвольное значение для детерминированного вычисления адреса.
     * @return predicted Предсказанный адрес.
     */
    function predictNewAddress(
        address implementation,
        bytes32 salt
    ) public view returns (address predicted) { 
       return Clones.predictDeterministicAddress(
            implementation,
            salt,
            address(this));
    }

    /**
     * @notice Развертывает новый прокси-контракт (клон) через CREATE2.
     * @dev Может быть вызвана только владельцем.
     * @param implementation Адрес контракта-реализации.
     * @param salt Произвольное значение, используемое для развертывания.
     */
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

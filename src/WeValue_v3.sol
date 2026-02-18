// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {WeValue as WeValue2} from "src/WeValue_v2.sol";

/**
 * @title Контракт благотворительного фонда WeValue
 * @author YaroslavaETH
 * @notice Этот контракт представляет собой токен для благотворительного фонда.
 * Он поддерживает пожертвования, обновляемость (UUPS), мета-транзакции,
 * а также имеет механизм защиты активов от обесценивания стейблкоинов.
 */
contract WeValue is
    WeValue2
{
    /// @notice Событие, возникающее при изменении порога эвакуации
    event ChangeDepegThreshold(uint256 oldDepeg, uint256 newDepeg);

    /**
     * @notice Изменяет пороговую цену эвакуации средств в новый актив .
     * @dev Только для владельца.
     * @param _newDepeg новое значение пороговой цены.
     */
     function setDepegThreshold(uint256 _newDepeg) external onlyOwner{
        uint256 _oldDepeg = depegThreshold;
        depegThreshold = _newDepeg;
        emit ChangeDepegThreshold(_oldDepeg, _newDepeg);
    }
    
    /**
     * @dev Возвращает текущую версию контракта.
     * @return string memory Строка с номером версии.
     */
    function version() external pure virtual override returns (string memory) {
        return "0.3";
    }
}

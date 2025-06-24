// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SellNicknames} from "../src/SellNicknames.sol";

contract SellNicknamesTest is Test {
    SellNicknames public sellNicknames;

    event BuyNickname(address indexed _ownerNickname, string indexed _nickname);
    event NewPrice(uint32 indexed _price);

    address _otherAddress = makeAddr("_otherAddress");

    /**
     * @notice Настраивает тестовое окружение перед каждым тестом.
     * @dev Развертывает новый экземпляр контракта SellNicknames с пространством имен "TestSpace".
     */
    function setUp() public {
        sellNicknames = new SellNicknames("TestSpace");
    }

    /**
     * @notice Проверяет, что владелец контракта установлен правильно.
     * @dev Убеждается, что `owner()` возвращает адрес тестового контракта.
     */
    function test_owner() public view {
        assertEq(sellNicknames.owner(), address(this));
    }

    /**
     * @notice Проверяет, что пространство никнеймов установлено правильно.
     * @dev Убеждается, что `nicknameSpace()` возвращает "TestSpace", заданное в конструкторе.
     */
    function test_nicknameSpace() public view {
        assertEq(sellNicknames.nicknameSpace(), "TestSpace");
    }

    /**
     * @notice Фаззинг-тест для функции `setPrice`.
     * @dev Проверяет, что функция `setPrice` корректно устанавливает цену для различных значений.
     */
    function testFuzz_setPrice(uint32 x) public {
        sellNicknames.setPrice(x);
        assertEq(sellNicknames.price(), x);
    }

    /**
     * @notice Проверяет, что `setPrice` не может быть вызвана не владельцем.
     * @dev Ожидает реверт с ошибкой `NotTheOwner`, если `setPrice` вызывается с другого адреса.
     */
    function test_setPriceNotOwner() public {
        vm.expectRevert(SellNicknames.NotTheOwner.selector);
        vm.prank(address(0));
        sellNicknames.setPrice(10);
    }

    /**
     * @notice Проверяет, что при установке новой цены генерируется событие `NewPrice`.
     * @dev Убеждается, что генерируется событие `NewPrice` при установке новой цены.
     */
    function test_setPriceEventNewPrice() public {
        vm.expectEmit(true, true, true, false);
        uint32 _newPrice = 14;
        emit NewPrice(_newPrice);
        sellNicknames.setPrice(_newPrice);
    }

    /**
     * @notice Проверяет успешную покупку никнейма.
     * @dev Убеждается, что генерируется событие `BuyNickname` и что владелец никнейма правильно установлен.
     */
    function test_buyNickname() public {
        string memory _nickname = "Zevs";
        vm.expectEmit(true, true, true, false);
        emit BuyNickname(_otherAddress, _nickname);
        vm.startPrank(_otherAddress);
        sellNicknames.buyNickname{value: sellNicknames.price()}(_nickname);
        vm.stopPrank();
        vm.assertEq(sellNicknames.ownerOf(_nickname), _otherAddress);
    }

    /**
     * @notice Проверяет сценарий, когда никнейм уже занят.
     * @dev Сначала покупает ник, затем пытается купить его снова и ожидает реверт с ошибкой `NicknameIsBusy`.
     */
    function test_buyNicknameNicknameIsBusy() public {
        string memory _nickname = "Zevs";
        uint32 _price = sellNicknames.price();
        vm.prank(_otherAddress);
        sellNicknames.buyNickname{value: _price}(_nickname);
        vm.expectRevert(
            abi.encodeWithSelector(
                SellNicknames.NicknameIsBusy.selector,
                _otherAddress
            )
        );
        sellNicknames.buyNickname{value: _price}(_nickname);
    }

    /**
     * @notice Проверяет сценарий, когда для покупки отправлена неверная сумма.
     * @dev Пытается купить ник, отправив больше эфира, чем текущая цена, и ожидает реверт с ошибкой `AnotherPrice`.
     */
    function test_buyNicknameAnotherPrice() public {
        string memory _nickname = "Zevs";
        uint32 _currentprice = sellNicknames.price();
        uint32 _price = _currentprice + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                SellNicknames.AnotherPrice.selector,
                _currentprice,
                _price
            )
        );
        sellNicknames.buyNickname{value: _price}(_nickname);
    }

    /**
     * @notice Проверяет, что прямой перевод эфира на контракт отклоняется.
     * @dev Отправляет прямой перевод эфира на адрес контракта и проверяет, что транзакция отменяется с ошибкой `RandomCall`.
     */
    function test_receive() public {
        hoax(_otherAddress);      
        (bool success, bytes memory result) = address(sellNicknames).call{value: 1}("");
        vm.assertFalse(success);
        bytes4 expectedSelector = bytes4(keccak256("RandomCall()"));
        bytes4 receivedSelector = bytes4(result);        
        vm.assertEq(receivedSelector, expectedSelector, "Should revert with RandomCall error");
    }
}

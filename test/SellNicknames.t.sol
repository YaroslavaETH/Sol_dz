// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SellNicknames} from "../src/SellNicknames.sol";

contract SellNicknamesTest is Test {
    SellNicknames public sellNicknames;

    event BuyNickname(address indexed _ownerNickname, string indexed _nickname);
    event NewPrice(uint256 indexed _price);

    address _otherAddress = makeAddr("_otherAddress");

    function setUp() public {
        sellNicknames = new SellNicknames("TestSpace");
    }

    function test_owner() public {
        assertEq(sellNicknames.owner(), address(this));
    }

    function test_nicknameSpace() public {
        assertEq(sellNicknames.nicknameSpace(), "TestSpace");
    }

    function testFuzz_setPrice(uint256 x) public {
        sellNicknames.setPrice(x);
        assertEq(sellNicknames.price(), x);
    }

    function test_setPriceNotOwner() public {
        vm.expectRevert(SellNicknames.NotTheOwner.selector);
        vm.prank(address(0));
        sellNicknames.setPrice(10);
    }

    function test_setPriceEventNewPrice() public {
        vm.expectEmit(true, true, true, false);
        uint256 _newPrice = 14;
        emit NewPrice(_newPrice);
        sellNicknames.setPrice(_newPrice);
    }

    function test_buyNickname() public {
        string memory _nickname = "Zevs";
        vm.expectEmit(true, true, true, false);
        emit BuyNickname(_otherAddress, _nickname);
        vm.startPrank(_otherAddress);
        sellNicknames.buyNickname{value: sellNicknames.price()}(_nickname);
        vm.stopPrank();
        vm.assertEq(sellNicknames.ownerOf(_nickname), _otherAddress);
    }

    function test_buyNicknameNicknameIsBusy() public {
        string memory _nickname = "Zevs";
        uint256 _price = sellNicknames.price();
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

    function test_buyNicknameAnotherPrice() public {
        string memory _nickname = "Zevs";
        uint256 _currentprice = sellNicknames.price();
        uint256 _price = _currentprice + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                SellNicknames.AnotherPrice.selector,
                _currentprice,
                _price
            )
        );
        sellNicknames.buyNickname{value: _price}(_nickname);
    }

    function test_receive() public {
        hoax(_otherAddress);
        vm.expectRevert(SellNicknames.RandomCall.selector);        
        (bool success, ) = address(sellNicknames).call{value: 1}("");
        //vm.assertFalse(success);
        //vm.assertEq(address(sellNicknames).balance, 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";
import {WeValue} from "src/WeValue_v2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public multiSig;
    WeValue public weValue;
    WeValue public implementation;
    ERC1967Proxy public proxy;
    
    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;
    
    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        
        // Deploy MultiSig (2 of 3)
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        
        multiSig = new MultiSigWallet(owners, 2);
        
        // Deploy WeValue with MultiSig as owner
        implementation = new WeValue();
        
        bytes memory initData = abi.encodeWithSelector(
            WeValue.initialize.selector,
            "WeValue",
            "WEVALUE",
            address(multiSig), // MultiSig is owner
            address(0), // aavePool (mock)
            address(0), // priceOracle (mock)
            address(0), // protectedAsset (mock)
            address(0), // safeAssetOracle (mock)
            address(0), // safeAsset (mock)
            95_000_000, // depegThreshold
            address(0), // router (mock)
            address(0)  // permit2 (mock)
        );
        
        proxy = new ERC1967Proxy(address(implementation), initData);
        weValue = WeValue(payable(address(proxy)));
    }
    
    // ========== MultiSig Basic Tests ==========
    
    function test_MultiSigSetup() public view {
        assertEq(multiSig.getOwnersCount(), 3);
        assertEq(multiSig.required(), 2);
        assertTrue(multiSig.isOwner(owner1));
        assertTrue(multiSig.isOwner(owner2));
        assertTrue(multiSig.isOwner(owner3));
        assertFalse(multiSig.isOwner(nonOwner));
    }
    
    function test_WeValueOwnerIsMultiSig() public view {
        assertEq(weValue.owner(), address(multiSig));
    }
    
    // ========== Propose Transaction ==========
    
    function test_ProposeTransaction() public {
        // Prepare call to WeValue.setSafeAsset
        address newSafeAsset = makeAddr("newSafeAsset");
        address newSafeAssetOracle = makeAddr("newOracle");
        
        bytes memory data = abi.encodeWithSelector(
            WeValue.setSafeAsset.selector,
            newSafeAsset,
            newSafeAssetOracle
        );
        
        vm.prank(owner1);
        uint256 txId = multiSig.proposeTransaction(
            address(weValue),
            0,
            data,
            "Set new safe asset"
        );
        
        assertEq(txId, 0);
        
        (
            address target,
            uint256 value,
            bytes memory txData,
            bool executed,
            uint256 confirmations,
            string memory description,
            uint256 timestamp
        ) = multiSig.getTransaction(txId);
        
        assertEq(target, address(weValue));
        assertEq(value, 0);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(confirmations, 1); // Auto-confirmed by proposer
        assertEq(description, "Set new safe asset");
        assertGt(timestamp, 0);
    }
    
    function test_RevertIf_NonOwnerProposesTransaction() public {
        bytes memory data = "";
        
        vm.prank(nonOwner);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        multiSig.proposeTransaction(address(weValue), 0, data, "Test");
    }
    
    // ========== Confirm Transaction ==========
    
    function test_ConfirmAndExecuteTransaction() public {
        // Propose transaction
        bytes memory data = abi.encodeWithSelector(
            WeValue.setSafeAsset.selector,
            address(0x123),
            address(0x456)
        );
        
        vm.prank(owner1);
        uint256 txId = multiSig.proposeTransaction(
            address(weValue),
            0,
            data,
            "Set safe asset"
        );
        
        // Check not executed yet (need 2 confirmations)
        (, , , bool executed1, uint256 confirmations1, , ) = multiSig.getTransaction(txId);
        assertFalse(executed1);
        assertEq(confirmations1, 1);
        
        // Owner2 confirms - should auto-execute
        vm.prank(owner2);
        multiSig.confirmTransaction(txId);
        
        // Check executed
        (, , , bool executed2, uint256 confirmations2, , ) = multiSig.getTransaction(txId);
        assertTrue(executed2);
        assertEq(confirmations2, 2);
        
        // Verify WeValue was updated (would need proper mocks)
    }
    
    function test_RevertIf_DoubleConfirm() public {
        vm.prank(owner1);
        uint256 txId = multiSig.proposeTransaction(
            address(weValue),
            0,
            "",
            "Test"
        );
        
        // Try to confirm again
        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.TransactionAlreadyConfirmed.selector);
        multiSig.confirmTransaction(txId);
    }
    
    // ========== Revoke Confirmation ==========
    
    function test_RevokeConfirmation() public {
        vm.prank(owner1);
        uint256 txId = multiSig.proposeTransaction(
            address(weValue),
            0,
            "",
            "Test"
        );
        
        // Owner1 revokes
        vm.prank(owner1);
        multiSig.revokeConfirmation(txId);
        
        // Check
        assertFalse(multiSig.hasConfirmed(txId, owner1));
        (, , , , uint256 confirmations, , ) = multiSig.getTransaction(txId);
        assertEq(confirmations, 0);
    }
    
    function test_RevertIf_RevokeAfterExecution() public {
        vm.prank(owner1);
        uint256 txId = multiSig.proposeTransaction(
            address(weValue),
            0,
            "",
            "Test"
        );
        
        // Execute
        vm.prank(owner2);
        multiSig.confirmTransaction(txId);
        
        // Try to revoke
        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.TransactionAlreadyExecuted.selector);
        multiSig.revokeConfirmation(txId);
    }
    
    // ========== Get Pending Transactions ==========
    
    function test_GetPendingTransactions() public {
        // Create 3 transactions
        vm.startPrank(owner1);
        multiSig.proposeTransaction(address(weValue), 0, "", "Tx 1");
        multiSig.proposeTransaction(address(weValue), 0, "", "Tx 2");
        multiSig.proposeTransaction(address(weValue), 0, "", "Tx 3");
        vm.stopPrank();
        
        // Execute tx 1
        vm.prank(owner2);
        multiSig.confirmTransaction(0);
        
        // Get pending (should be 1 and 2)
        uint256[] memory pending = multiSig.getPendingTransactions();
        assertEq(pending.length, 2);
        assertEq(pending[0], 1);
        assertEq(pending[1], 2);
    }
    
    // ========== Integration Test ==========
    
    function test_Integration_ChangeSafeAsset() public {
        address newSafeAsset = makeAddr("newSafeAsset");
        address newOracle = makeAddr("newOracle");
        
        // Step 1: Owner1 proposes
        bytes memory data = abi.encodeWithSelector(
            WeValue.setSafeAsset.selector,
            newSafeAsset,
            newOracle
        );
        
        vm.prank(owner1);
        uint256 txId = multiSig.proposeTransaction(
            address(weValue),
            0,
            data,
            "Update safe asset to new token"
        );
        
        console.log("Transaction proposed:", txId);
        
        // Step 2: Check pending
        uint256[] memory pending = multiSig.getPendingTransactions();
        assertEq(pending.length, 1);
        
        // Step 3: Owner2 confirms (auto-executes)
        vm.prank(owner2);
        multiSig.confirmTransaction(txId);
        
        // Step 4: Verify executed
        (, , , bool executed, , , ) = multiSig.getTransaction(txId);
        assertTrue(executed);
        
        // Step 5: Check no pending
        pending = multiSig.getPendingTransactions();
        assertEq(pending.length, 0);
        
        console.log("Transaction executed successfully");
    }
}

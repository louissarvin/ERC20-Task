// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/CampusCredit.sol";

contract CampusCreditTest is Test {
    CampusCredit public campusCredit;
    
    address public admin;
    address public pauser;
    address public minter;
    address public student1;
    address public student2;
    address public merchant1;
    address public merchant2;
    address public unauthorized;
    
    // Events to test for
    event Transfer(address indexed from, address indexed to, uint256 value);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    
    function setUp() public {
        // Setup test addresses
        admin = address(this);
        pauser = makeAddr("pauser");
        minter = makeAddr("minter");
        student1 = makeAddr("student1");
        student2 = makeAddr("student2");
        merchant1 = makeAddr("merchant1");
        merchant2 = makeAddr("merchant2");
        unauthorized = makeAddr("unauthorized");
        
        // Deploy contract
        campusCredit = new CampusCredit();
        
        // Grant additional roles
        campusCredit.grantRole(campusCredit.PAUSER_ROLE(), pauser);
        campusCredit.grantRole(campusCredit.MINTER_ROLE(), minter);
    }
    
    function testConstructorSetup() public {
        // Test initial token properties
        assertEq(campusCredit.name(), "Campus Credit");
        assertEq(campusCredit.symbol(), "CREDIT");
        assertEq(campusCredit.decimals(), 18);
        
        // Test initial supply
        assertEq(campusCredit.totalSupply(), 1000000000);
        assertEq(campusCredit.balanceOf(admin), 1000000000);
        
        // Test role assignments
        assertTrue(campusCredit.hasRole(campusCredit.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(campusCredit.hasRole(campusCredit.PAUSER_ROLE(), admin));
        assertTrue(campusCredit.hasRole(campusCredit.MINTER_ROLE(), admin));
        
        // Test contract is not paused initially
        assertFalse(campusCredit.paused());
    }
    
    function testMinting() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 initialBalance = campusCredit.balanceOf(student1);
        uint256 initialSupply = campusCredit.totalSupply();
        
        // Test successful minting by admin
        campusCredit.mint(student1, mintAmount);
        assertEq(campusCredit.balanceOf(student1), initialBalance + mintAmount);
        assertEq(campusCredit.totalSupply(), initialSupply + mintAmount);
        
        // Test successful minting by minter role
        vm.prank(minter);
        campusCredit.mint(student2, mintAmount);
        assertEq(campusCredit.balanceOf(student2), mintAmount);
        
        // Test unauthorized minting fails
        vm.prank(unauthorized);
        vm.expectRevert();
        campusCredit.mint(student1, mintAmount);
    }
    
    function testPauseUnpause() public {
        // Test pause by admin
        campusCredit.pause();
        assertTrue(campusCredit.paused());
        
        // Test unpause by admin
        campusCredit.unpause();
        assertFalse(campusCredit.paused());
        
        // Test pause by pauser role
        vm.prank(pauser);
        campusCredit.pause();
        assertTrue(campusCredit.paused());
        
        // Test unpause by pauser role
        vm.prank(pauser);
        campusCredit.unpause();
        assertFalse(campusCredit.paused());
        
        // Test unauthorized pause fails
        vm.prank(unauthorized);
        vm.expectRevert();
        campusCredit.pause();
    }
    
    function testTransferWhenPaused() public {
        uint256 transferAmount = 100 * 10**18;
        
        // Setup: give student1 some tokens
        campusCredit.mint(student1, transferAmount * 2);
        
        // Pause the contract
        campusCredit.pause();
        
        // Test that transfers fail when paused
        vm.prank(student1);
        vm.expectRevert("Token transfers paused");
        campusCredit.transfer(student2, transferAmount);
        
        // Unpause and test transfer works
        campusCredit.unpause();
        vm.prank(student1);
        campusCredit.transfer(student2, transferAmount);
        assertEq(campusCredit.balanceOf(student2), transferAmount);
    }
    
    function testMerchantRegistration() public {
        string memory merchantName = "Campus Cafeteria";
        
        // Test successful merchant registration
        campusCredit.registerMerchant(merchant1, merchantName);
        assertTrue(campusCredit.isMerchant(merchant1));
        assertEq(campusCredit.merchantName(merchant1), merchantName);
        
        // Test unauthorized registration fails
        vm.prank(unauthorized);
        vm.expectRevert();
        campusCredit.registerMerchant(merchant2, "Unauthorized Merchant");
    }
    
    function testDailySpendingLimit() public {
        uint256 dailyLimit = 500 * 10**18;
        
        // Set daily limit for student1
        campusCredit.setDailyLimit(student1, dailyLimit);
        
        assertEq(campusCredit.dailySpendingLimit(student1), dailyLimit);
        assertEq(campusCredit.spentToday(student1), 0);
        assertEq(campusCredit.lastSpendingReset(student1), block.timestamp);
        
        // Test unauthorized limit setting fails
        vm.prank(unauthorized);
        vm.expectRevert();
        campusCredit.setDailyLimit(student2, dailyLimit);
    }
    
    function testTransferWithLimit() public {
        uint256 dailyLimit = 500 * 10**18;
        uint256 transferAmount = 200 * 10**18;
        uint256 initialBalance = 1000 * 10**18;
        
        // Setup
        campusCredit.mint(student1, initialBalance);
        campusCredit.setDailyLimit(student1, dailyLimit);
        
        // Test successful transfer within limit
        vm.prank(student1);
        campusCredit.transferWithLimit(student2, transferAmount);
        
        assertEq(campusCredit.balanceOf(student1), initialBalance - transferAmount);
        assertEq(campusCredit.balanceOf(student2), transferAmount);
        assertEq(campusCredit.spentToday(student1), transferAmount);
        
        // Test transfer that exceeds daily limit fails
        vm.prank(student1);
        vm.expectRevert("Transfer kamu sudah mencapai maksimal limit");
        campusCredit.transferWithLimit(student2, dailyLimit);
        
        // Test transfer that exceeds balance fails
        vm.prank(student1);
        vm.expectRevert("Saldo Tidak Cukup");
        campusCredit.transferWithLimit(student2, initialBalance);
    }
    
    function testDailyLimitReset() public {
        uint256 dailyLimit = 500 * 10**18;
        uint256 transferAmount = 300 * 10**18;
        uint256 initialBalance = 1000 * 10**18;
        
        // Setup
        campusCredit.mint(student1, initialBalance);
        campusCredit.setDailyLimit(student1, dailyLimit);
        
        // Make a transfer
        vm.prank(student1);
        campusCredit.transferWithLimit(student2, transferAmount);
        assertEq(campusCredit.spentToday(student1), transferAmount);
        
        // Fast forward time by more than 1 day
        vm.warp(block.timestamp + 2 days);
        
        // Make another transfer - should reset the daily spending
        vm.prank(student1);
        campusCredit.transferWithLimit(student2, transferAmount);
        assertEq(campusCredit.spentToday(student1), transferAmount);
        assertEq(campusCredit.lastSpendingReset(student1), block.timestamp);
    }
    
    function testCashbackMechanism() public {
        uint256 transferAmount = 1000 * 10**18;
        uint256 expectedCashback = (transferAmount * 2) / 100; // 2% cashback
        uint256 initialBalance = 2000 * 10**18;
        uint256 dailyLimit = 1500 * 10**18;
        
        // Setup
        campusCredit.mint(student1, initialBalance);
        campusCredit.setDailyLimit(student1, dailyLimit);
        campusCredit.registerMerchant(merchant1, "Test Merchant");
        
        uint256 studentBalanceBefore = campusCredit.balanceOf(student1);
        uint256 merchantBalanceBefore = campusCredit.balanceOf(merchant1);
        uint256 totalSupplyBefore = campusCredit.totalSupply();
        
        // Test successful cashback transfer
        vm.prank(student1);
        campusCredit.transferWithCashback(merchant1, transferAmount);
        
        // Check balances after transfer
        assertEq(campusCredit.balanceOf(student1), studentBalanceBefore - transferAmount + expectedCashback);
        assertEq(campusCredit.balanceOf(merchant1), merchantBalanceBefore + transferAmount);
        assertEq(campusCredit.totalSupply(), totalSupplyBefore + expectedCashback);
        assertEq(campusCredit.spentToday(student1), transferAmount);
    }
    
    function testBurnFunctionality() public {
        uint256 burnAmount = 100 * 10**18;
        uint256 initialBalance = 1000 * 10**18;
        
        // Setup
        campusCredit.mint(student1, initialBalance);
        
        uint256 totalSupplyBefore = campusCredit.totalSupply();
        
        // Test burning tokens
        vm.prank(student1);
        campusCredit.burn(burnAmount);
        
        assertEq(campusCredit.balanceOf(student1), initialBalance - burnAmount);
        assertEq(campusCredit.totalSupply(), totalSupplyBefore - burnAmount);
        
        // Test burning more than balance fails
        vm.prank(student1);
        vm.expectRevert();
        campusCredit.burn(initialBalance);
    }
    
    function testRoleManagement() public {
        bytes32 minterRole = campusCredit.MINTER_ROLE();
        
        // Test granting role
        campusCredit.grantRole(minterRole, student1);
        assertTrue(campusCredit.hasRole(minterRole, student1));
        
        // Test student1 can now mint
        vm.prank(student1);
        campusCredit.mint(student2, 100 * 10**18);
        assertEq(campusCredit.balanceOf(student2), 100 * 10**18);
        
        // Test revoking role
        campusCredit.revokeRole(minterRole, student1);
        assertFalse(campusCredit.hasRole(minterRole, student1));
        
        // Test student1 can no longer mint
        vm.prank(student1);
        vm.expectRevert();
        campusCredit.mint(student2, 100 * 10**18);
    }
    
    function testCashbackPercentage() public {
        // Test default cashback percentage
        assertEq(campusCredit.cashbackPercentage(), 2);
        
        // Note: There's no setter for cashback percentage in the contract
        // This could be a potential improvement
    }
    
    function testEdgeCases() public {
        // Test zero amount transfers
        vm.prank(student1);
        campusCredit.transfer(student2, 0);
        assertEq(campusCredit.balanceOf(student2), 0);
        
        // Test self-transfer
        campusCredit.mint(student1, 100 * 10**18);
        uint256 balanceBefore = campusCredit.balanceOf(student1);
        
        vm.prank(student1);
        campusCredit.transfer(student1, 50 * 10**18);
        assertEq(campusCredit.balanceOf(student1), balanceBefore);
    }
    
    function testFuzzTransferWithLimit(uint256 amount) public {
        // Bound the amount to reasonable values
        amount = bound(amount, 1, 1000000 * 10**18);
        
        uint256 dailyLimit = 500 * 10**18;
        uint256 initialBalance = 1000000 * 10**18;
        
        campusCredit.mint(student1, initialBalance);
        campusCredit.setDailyLimit(student1, dailyLimit);
        
        vm.prank(student1);
        if (amount <= dailyLimit && amount <= initialBalance) {
            campusCredit.transferWithLimit(student2, amount);
            assertEq(campusCredit.spentToday(student1), amount);
        } else {
            vm.expectRevert();
            campusCredit.transferWithLimit(student2, amount);
        }
    }
}
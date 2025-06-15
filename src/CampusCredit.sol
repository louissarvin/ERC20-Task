// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CampusCredit
 * @dev ERC-20 token untuk transaksi dalam kampus
 * Use cases:
 * - Pembayaran di kafetaria
 * - Biaya printing dan fotokopi
 * - Laundry service
 * - Peminjaman equipment
 */
contract CampusCredit is ERC20, ERC20Burnable, Pausable, AccessControl {
    // TODO: Define role constants
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Additional features untuk kampus
    mapping(address => uint256) public dailySpendingLimit;
    mapping(address => uint256) public spentToday;
    mapping(address => uint256) public lastSpendingReset;
    
    // Merchant whitelist
    mapping(address => bool) public isMerchant;
    mapping(address => string) public merchantName;

    constructor() ERC20("Campus Credit", "CREDIT") {
        // TODO: Setup roles
        // Hint:
        // 1. Grant DEFAULT_ADMIN_ROLE ke msg.sender
        // 2. Grant PAUSER_ROLE ke msg.sender
        // 3. Grant MINTER_ROLE ke msg.sender
        // 4. Consider initial mint untuk treasury
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _mint(_msgSender(), 1000000000);
    }

    /**
     * @dev Pause all token transfers
     * Use case: Emergency atau maintenance
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        // TODO: Implement dengan role check
        // Only PAUSER_ROLE can pause
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        // TODO: Implement unpause
        _unpause();
    }

    /**
     * @dev Mint new tokens
     * Use case: Top-up saldo mahasiswa
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        // TODO: Implement dengan role check
        // Only MINTER_ROLE can mint
        // Consider adding minting limits
        _mint(to, amount);
    }

    /**
     * @dev Register merchant
     * Use case: Kafetaria, toko buku, laundry
     */
    function registerMerchant(address merchant, string memory name) 
        public onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        // TODO: Register merchant untuk accept payments
        isMerchant[merchant] = true;
        merchantName[merchant] = name;
    }

    /**
     * @dev Set daily spending limit untuk mahasiswa
     * Use case: Parental control atau self-control
     */
    function setDailyLimit(address student, uint256 limit) 
        public onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        // TODO: Set spending limit
        dailySpendingLimit[student] = limit;
        lastSpendingReset[student] = block.timestamp;
        spentToday[student] = 0;
    }

    /**
     * @dev Transfer dengan spending limit check
     */
    function transferWithLimit(address to, uint256 amount) public {
        // TODO: Check daily limit before transfer
        // Reset limit if new day
        // Update spent amount
        // Then do normal transfer
        if(lastSpendingReset[msg.sender] + 1 days <= block.timestamp) {
            lastSpendingReset[msg.sender] = block.timestamp;
            spentToday[msg.sender] = 0;
        }
        require(amount <= dailySpendingLimit[msg.sender] && amount <= balanceOf(msg.sender), "Saldo Tidak Cukup");
        require(spentToday[msg.sender] + amount <= dailySpendingLimit[msg.sender], "Transfer kamu sudah mencapai maksimal limit");
        spentToday[msg.sender] += amount;
        transfer(to, amount);
    }

    /**
     * @dev Override _beforeTokenTransfer untuk add pause functionality
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        // TODO: Add pause check
        require(!paused(), "Token transfers paused");
        super._update(from, to, amount);
    }

    /**
     * @dev Cashback mechanism untuk encourage usage
     */
    uint256 public cashbackPercentage = 2; // 2%
    
    function transferWithCashback(address merchant, uint256 amount) public {
        // TODO: Transfer to merchant dengan cashback ke sender
        // Calculate cashback
        // Transfer main amount
        // Mint cashback to sender
        require(amount <= dailySpendingLimit[msg.sender] && amount <= balanceOf(msg.sender), "Saldo Tidak Cukup");
        require(spentToday[msg.sender] + amount <= dailySpendingLimit[msg.sender], "Transfer kamu sudah mencapai maksimal limit");
        require(isMerchant[merchant] == true, "Anda harus mendaftarkan sebagai merchant terlebih dahulu");
        
        uint256 cashback = amount * cashbackPercentage / 100;
        spentToday[msg.sender] += amount;
        _transfer(_msgSender(), merchant, amount);
        _mint(_msgSender(), cashback);
    }
}
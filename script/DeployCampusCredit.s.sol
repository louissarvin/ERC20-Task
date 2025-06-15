// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "lib/forge-std/src/Script.sol";
import { CampusCredit } from "../src/CampusCredit.sol";

contract DeployCampusCredit is Script {
    CampusCredit public campusCredit;

    function setUp() public {}

    function run() public returns (CampusCredit, address) {
        console.log("Starting CampusCredit deployment to Monad Testnet...\n");

        // Get deployer account from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployment Details:");
        console.log("Deployer address:", deployer);
        
        // Check balance
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "MON");
        
        if (balance < 0.01 ether) {
            console.log("Warning: Low balance. Make sure you have enough MON for deployment.");
        }

        // Get network info
        console.log("Network: Monad Testnet");
        console.log("Chain ID: 10143");
        console.log("RPC URL: https://testnet-rpc.monad.xyz/\n");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying CampusCredit contract...");
        
        // Deploy TaskManager
        campusCredit = new CampusCredit();
        address contractAddress = address(campusCredit);

        vm.stopBroadcast();

        console.log("CampusCredit deployed successfully!");
        console.log("Contract address:", contractAddress);
        console.log("Block explorer:", string.concat("https://testnet.monadexplorer.com/address/", _addressToString(contractAddress)));

        // Provide next steps
        console.log("Next Steps:");
        console.log("1. Save the contract address for future interactions");
        console.log("2. Verify the contract on block explorer (optional)");
        console.log("3. Test contract functions using cast or frontend");
        console.log("4. Add the contract to your MetaMask for easy interaction");

        // Save deployment info
        _saveDeploymentInfo(contractAddress, deployer);

        return (campusCredit, contractAddress);
    }

    function _saveDeploymentInfo(address contractAddress, address deployer) internal {
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "contractAddress": "', _addressToString(contractAddress), '",\n',
            '  "deployerAddress": "', _addressToString(deployer), '",\n',
            '  "network": "Monad Testnet",\n',
            '  "chainId": "10143",\n',
            '  "blockExplorer": "https://testnet.monadexplorer.com/address/', _addressToString(contractAddress), '",\n',
            '  "timestamp": "', _getTimestamp(), '"\n',
            "}"
        );

        // Write deployment info to file
        vm.writeFile("./deployments/campuscredit-monad-testnet.json", deploymentInfo);
        console.log("Deployment info saved to: deployments/campuscredit-monad-testnet.json");
    }

    function _addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function _getTimestamp() internal view returns (string memory) {
        // Simple timestamp as block number since we can't get actual timestamp in scripts
        return vm.toString(block.number);
    }
}
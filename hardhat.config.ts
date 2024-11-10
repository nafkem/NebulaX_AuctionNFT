import { HardhatUserConfig } from "hardhat/types";
import '@openzeppelin/hardhat-upgrades';
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";
import "@nomicfoundation/hardhat-ignition-ethers";

// Updated variable names for ArbitrumSepoliaTestnet
const { API_URL, PRIVATE_KEY, API_KEY } = process.env;

if (!PRIVATE_KEY) {
  throw new Error("Please set your ARBITRUM_SEPOLIA_PRIVATE_KEY in the .env file");
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // Optimize the contract for 200 runs
      },
    },
  },

  networks: {
    arbitrum_sepolia: {
      url: API_URL || "https://arbitrum-sepolia.infura.io/v3/3d18acc99e604d92b3c5c5844859708e", // Default to Arbitrum Sepolia RPC URL if not defined
      accounts: [PRIVATE_KEY],
      chainId: 421614, // Chain ID for Arbitrum Sepolia
    },
  },

  etherscan: {
    apiKey: API_KEY || "", // Fallback for Arbiscan API Key
    customChains: [
      {
        network: "arbitrum_sepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://arbitrum-sepolia.infura.io/v3/3d18acc99e604d92b3c5c5844859708e", // Arbiscan API URL for Arbitrum
          browserURL: "https://sepolia.arbiscan.io", // Block Explorer for Arbitrum Sepolia
        },
      },
    ],
  },
};

export default config;

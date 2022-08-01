import * as dotenv from "dotenv";
import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

dotenv.config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task('deployNFT', 'Deploys market item on a provided network').setAction(
  async (taskArguments, hre) => {
    const deployToken = require('./scripts/deploy');
    await deployToken(taskArguments);
  },
);

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  paths: {
    artifacts: "./src/artifacts"
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.WALLET_PRIVATE_KEY !== undefined ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
    rinkeby: {
      url: process.env.RINKEBY_URL || "",
      accounts: process.env.WALLET_PRIVATE_KEY !== undefined ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
  },
};

export default config;

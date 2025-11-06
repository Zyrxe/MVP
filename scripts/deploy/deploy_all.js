const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

const DEPLOYMENTS_PATH = path.join(__dirname, "../../deployments.json");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  const deployments = {
    network: network.name,
    chainId: network.config.chainId,
    timestamp: new Date().toISOString(),
    contracts: {}
  };

  // Deploy ALONEAToken
  console.log("Deploying ALONEAToken...");
  const ALONEAToken = await ethers.getContractFactory("ALONEAToken");
  const token = await upgrades.deployProxy(ALONEAToken, [
    deployer.address,
    deployer.address, // buyback wallet
    deployer.address, // liquidity wallet
    deployer.address  // treasury wallet
  ], {
    initializer: "initialize",
    kind: "transparent",
  });
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log("ALONEAToken deployed to:", tokenAddress);
  
  deployments.contracts.ALONEAToken = {
    proxy: tokenAddress,
    implementation: await upgrades.erc1967.getImplementationAddress(tokenAddress),
    version: await token.version()
  };

  // Deploy ALONEAStaking
  console.log("Deploying ALONEAStaking...");
  const ALONEAStaking = await ethers.getContractFactory("ALONEAStaking");
  const staking = await upgrades.deployProxy(ALONEAStaking, [
    tokenAddress,
    deployer.address
  ], {
    initializer: "initialize",
    kind: "uups",
  });
  await staking.waitForDeployment();
  const stakingAddress = await staking.getAddress();
  console.log("ALONEAStaking deployed to:", stakingAddress);
  
  deployments.contracts.ALONEAStaking = {
    proxy: stakingAddress,
    implementation: await upgrades.erc1967.getImplementationAddress(stakingAddress),
    version: await staking.version()
  };

  // Deploy ALONEABuyback
  console.log("Deploying ALONEABuyback...");
  const ALONEABuyback = await ethers.getContractFactory("ALONEABuyback");
  const routerAddress = network.config.chainId === 56 
    ? "0x10ED43C718714eb63d5aA57B78B54704E256024E" // PancakeSwap Mainnet
    : "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // PancakeSwap Testnet
    
  const buyback = await upgrades.deployProxy(ALONEABuyback, [
    tokenAddress,
    routerAddress,
    deployer.address
  ], {
    initializer: "initialize",
    kind: "uups",
  });
  await buyback.waitForDeployment();
  const buybackAddress = await buyback.getAddress();
  console.log("ALONEABuyback deployed to:", buybackAddress);
  
  deployments.contracts.ALONEABuyback = {
    proxy: buybackAddress,
    implementation: await upgrades.erc1967.getImplementationAddress(buybackAddress),
    version: await buyback.version()
  };

  // Deploy Timelock for Governance
  console.log("Deploying TimelockController...");
  const TimelockController = await ethers.getContractFactory("TimelockController");
  const timelock = await TimelockController.deploy(
    0, // min delay
    [deployer.address], // proposers
    [deployer.address]  // executors
  );
  await timelock.waitForDeployment();
  const timelockAddress = await timelock.getAddress();
  console.log("TimelockController deployed to:", timelockAddress);

  // Deploy ALONEAGovernance
  console.log("Deploying ALONEAGovernance...");
  const ALONEAGovernance = await ethers.getContractFactory("ALONEAGovernance");
  const governance = await upgrades.deployProxy(ALONEAGovernance, [
    tokenAddress,
    timelockAddress,
    deployer.address
  ], {
    initializer: "initialize",
    kind: "transparent",
  });
  await governance.waitForDeployment();
  const governanceAddress = await governance.getAddress();
  console.log("ALONEAGovernance deployed to:", governanceAddress);
  
  deployments.contracts.ALONEAGovernance = {
    proxy: governanceAddress,
    implementation: await upgrades.erc1967.getImplementationAddress(governanceAddress),
    version: await governance.version()
  };
  
  deployments.contracts.TimelockController = {
    address: timelockAddress
  };

  // Save deployments
  fs.writeFileSync(DEPLOYMENTS_PATH, JSON.stringify(deployments, null, 2));
  console.log("Deployments saved to:", DEPLOYMENTS_PATH);

  console.log("\n=== Deployment Summary ===");
  console.log("ALONEAToken:", tokenAddress);
  console.log("ALONEAStaking:", stakingAddress);
  console.log("ALONEABuyback:", buybackAddress);
  console.log("ALONEAGovernance:", governanceAddress);
  console.log("TimelockController:", timelockAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

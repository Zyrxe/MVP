const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

const DEPLOYMENTS_PATH = path.join(__dirname, "../../deployments.json");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Upgrading contracts with account:", deployer.address);

  if (!fs.existsSync(DEPLOYMENTS_PATH)) {
    throw new Error("deployments.json not found. Deploy contracts first.");
  }

  const deployments = JSON.parse(fs.readFileSync(DEPLOYMENTS_PATH, "utf8"));
  
  // Upgrade ALONEAToken
  console.log("Upgrading ALONEAToken...");
  const ALONEATokenV2 = await ethers.getContractFactory("ALONEAToken");
  const tokenProxy = deployments.contracts.ALONEAToken.proxy;
  const upgradedToken = await upgrades.upgradeProxy(tokenProxy, ALONEATokenV2);
  await upgradedToken.waitForDeployment();
  console.log("ALONEAToken upgraded");

  // Upgrade ALONEAStaking
  console.log("Upgrading ALONEAStaking...");
  const ALONEAStakingV2 = await ethers.getContractFactory("ALONEAStaking");
  const stakingProxy = deployments.contracts.ALONEAStaking.proxy;
  const upgradedStaking = await upgrades.upgradeProxy(stakingProxy, ALONEAStakingV2);
  await upgradedStaking.waitForDeployment();
  console.log("ALONEAStaking upgraded");

  // Upgrade ALONEABuyback
  console.log("Upgrading ALONEABuyback...");
  const ALONEABuybackV2 = await ethers.getContractFactory("ALONEABuyback");
  const buybackProxy = deployments.contracts.ALONEABuyback.proxy;
  const upgradedBuyback = await upgrades.upgradeProxy(buybackProxy, ALONEABuybackV2);
  await upgradedBuyback.waitForDeployment();
  console.log("ALONEABuyback upgraded");

  // Upgrade ALONEAGovernance
  console.log("Upgrading ALONEAGovernance...");
  const ALONEAGovernanceV2 = await ethers.getContractFactory("ALONEAGovernance");
  const governanceProxy = deployments.contracts.ALONEAGovernance.proxy;
  const upgradedGovernance = await upgrades.upgradeProxy(governanceProxy, ALONEAGovernanceV2);
  await upgradedGovernance.waitForDeployment();
  console.log("ALONEAGovernance upgraded");

  // Update deployments file
  deployments.timestamp = new Date().toISOString();
  deployments.contracts.ALONEAToken.implementation = await upgrades.erc1967.getImplementationAddress(tokenProxy);
  deployments.contracts.ALONEAStaking.implementation = await upgrades.erc1967.getImplementationAddress(stakingProxy);
  deployments.contracts.ALONEABuyback.implementation = await upgrades.erc1967.getImplementationAddress(buybackProxy);
  deployments.contracts.ALONEAGovernance.implementation = await upgrades.erc1967.getImplementationAddress(governanceProxy);

  fs.writeFileSync(DEPLOYMENTS_PATH, JSON.stringify(deployments, null, 2));
  console.log("Deployments file updated");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

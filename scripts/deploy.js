const hre = require("hardhat");

async function main() {
  const { ethers, network } = hre;
  const [deployer] = await ethers.getSigners();

  console.log("Network:", network.name);
  console.log("Deployer:", deployer.address);

  const AuthorizationManager = await ethers.getContractFactory("AuthorizationManager");
  const authManager = await AuthorizationManager.deploy(deployer.address);
  await authManager.waitForDeployment();
  console.log("AuthorizationManager deployed to:", await authManager.getAddress());

  const SecureVault = await ethers.getContractFactory("SecureVault");
  const vault = await SecureVault.deploy(await authManager.getAddress());
  await vault.waitForDeployment();
  console.log("SecureVault deployed to:", await vault.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

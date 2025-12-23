const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Vault System", function () {
  async function deployContracts() {
    const [deployer, user1, user2] = await ethers.getSigners();

    const AuthorizationManager = await ethers.getContractFactory(
      "AuthorizationManager"
    );
    const authManager = await AuthorizationManager.deploy(deployer.address);
    // Wait for deployment (v6 style)
    await authManager.waitForDeployment();
    const authManagerAddress = await authManager.getAddress();

    const SecureVault = await ethers.getContractFactory("SecureVault");
    const vault = await SecureVault.deploy(authManagerAddress);
    await vault.waitForDeployment();
    const vaultAddress = await vault.getAddress();

    return { authManager, vault, vaultAddress, deployer, user1, user2 };
  }

  it("should deploy and accept deposits", async function () {
    const { vault, vaultAddress, deployer } = await deployContracts();

    await deployer.sendTransaction({
      to: vaultAddress,
      value: ethers.parseEther("1.0"),
    });

    const balance = await ethers.provider.getBalance(vaultAddress);
    expect(balance).to.equal(ethers.parseEther("1.0"));
  });

  it("should revert withdraw without valid authorization", async function () {
    const { vault, vaultAddress, user1 } = await deployContracts();

    await user1.sendTransaction({
      to: vaultAddress,
      value: ethers.parseEther("1.0"),
    });

    const recipient = user1.address;
    const amount = ethers.parseEther("0.1");
    const fakeAuthId = ethers.ZeroHash;
    const fakeSig = "0x"; // invalid signature

    await expect(
      vault.withdraw(recipient, amount, fakeAuthId, fakeSig)
    ).to.be.reverted;
  });
});

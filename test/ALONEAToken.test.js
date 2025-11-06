const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("ALONEAToken", function () {
  let token;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    const ALONEAToken = await ethers.getContractFactory("ALONEAToken");
    token = await upgrades.deployProxy(ALONEAToken, [
      owner.address,
      owner.address,
      owner.address,
      owner.address
    ], {
      initializer: "initialize",
    });
    await token.waitForDeployment();
  });

  it("Should deploy with correct initial supply", async function () {
    expect(await token.totalSupply()).to.equal(ethers.parseEther("100000000"));
  });

  it("Should apply fees on transfer", async function () {
    const amount = ethers.parseEther("1000");
    await token.transfer(user1.address, amount);
    
    const user1Balance = await token.balanceOf(user1.address);
    expect(user1Balance).to.be.lessThan(amount);
  });

  it("Should exclude addresses from fees", async function () {
    await token.excludeFromFees(user1.address, true);
    
    const amount = ethers.parseEther("1000");
    await token.transfer(user1.address, amount);
    
    const user1Balance = await token.balanceOf(user1.address);
    expect(user1Balance).to.equal(amount);
  });
});

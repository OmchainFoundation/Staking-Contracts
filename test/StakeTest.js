const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Staking Contract", function() {

  async function deployOneYear() {
    await network.provider.send("hardhat_setBalance", [
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      "0x18D0BF423C03D8DE000000000",
    ]);
    const Staking = await ethers.getContractFactory("OmchainStaking");
    const staking = await Staking.deploy();
    await staking.deployed();

    await staking.setRewardsDuration(1440 * 24 * 60 * 60);
    await staking.notifyRewardAmount(ethers.utils.parseEther("24000000"));
    await staking.deposit({ value: ethers.utils.parseEther("24000000")});
    await network.provider.send("hardhat_setBalance", [
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      "0x21E19E0C9BAB2400000",
    ]);
    return staking;
  }

  it("Should deploy and stake with one user", async function() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const staking = await deployOneYear();

    // Owner initial balance
    console.log("Balance of owner: " + (await ethers.provider.getBalance(owner.address)).toString());
    console.log("Balance of addr1: " + (await ethers.provider.getBalance(addr1.address)).toString());
    console.log("Balance of addr2: " + (await ethers.provider.getBalance(addr2.address)).toString());

    // Scenario
    // Stake addr1 for 2 years - 1000 tokens
    // T0
    await staking.connect(addr1).stake(ethers.utils.parseEther("1000"), 5, {
      value: ethers.utils.parseEther("1000"),
    });
    await time.increase(30 * 24 * 60 * 60);
    
    // T30
    await staking.connect(addr1).stake(ethers.utils.parseEther("1000"), 2, {
      value: ethers.utils.parseEther("1000"),
    });
    await time.increase(60 * 24 * 60 * 60);

    // T90
    let earned_1 = await staking.earned(addr1.address, 0);
    console.log("earned_1: " + ethers.utils.formatEther(earned_1));

    let earned_2 = await staking.earned(addr1.address, 1);
    console.log("earned_2: " + ethers.utils.formatEther(earned_2));

    await staking.connect(addr1).exit(1);

    await expect(staking.connect(addr1).exit(0)).to.be.revertedWith("Stake is not yet finished.");

    // Stake second guy
    console.log("Balance of addr2: " + (await ethers.provider.getBalance(addr2.address)).toString());
    await staking.connect(addr2).stake(ethers.utils.parseEther("1000"), 1, {
      value: ethers.utils.parseEther("1000"),
    });
    await time.increase(30 * 24 * 60 * 60);
    await staking.connect(addr2).exit(0);
    console.log("Balance of addr2: " + (await ethers.provider.getBalance(addr2.address)).toString());

    // T120
    await staking.connect(addr2).stake(ethers.utils.parseEther("1000"), 4, {
      value: ethers.utils.parseEther("1000"),
    });
    await time.increase(360 * 24 * 60 * 60);
    console.log("Balance of addr2: " + (await ethers.provider.getBalance(addr2.address)).toString());
    console.log("Earned: " + ethers.utils.formatEther(await staking.earned(addr2.address, 0)));
    await staking.connect(addr2).exit(0);
    console.log("Balance of addr2: " + (await ethers.provider.getBalance(addr2.address)).toString());

    // T480
    await time.increase(240 * 24 * 60 * 60);

    // T720
    console.log("Balance of addr1: " + (await ethers.provider.getBalance(addr1.address)).toString());
    await staking.connect(addr1).exit(0);
    console.log("Balance of addr1: " + (await ethers.provider.getBalance(addr1.address)).toString());



  });

});
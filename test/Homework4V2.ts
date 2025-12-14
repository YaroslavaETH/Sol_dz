import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Homework4V2", function () {

async function deployFixture() {
    
    const [owner, forwarder, user] = await ethers.getSigners();

    const ContractFactory = await ethers.getContractFactory("Homework4");
    const instance = await upgrades.deployProxy(ContractFactory, [user.address, owner.address, forwarder.address]);
    await instance.waitForDeployment();
    const V2Factory = await ethers.getContractFactory("Homework4V2");
    const upgradedInstance = await upgrades.upgradeProxy(await instance.getAddress(), V2Factory);
    await upgradedInstance.waitForDeployment();

    return { instance, upgradedInstance, owner, forwarder, user};
  }

  it("mint only once", async function () {
    const { instance, user } = await loadFixture(deployFixture);
    const userBalance = await instance.balanceOf(user.address);
    expect(userBalance).to.equal(ethers.parseUnits("1000", 18));
  });

  it("version", async function () {
    const { instance } = await loadFixture(deployFixture);
    expect(await instance.version()).to.equal("2.0");
  });

  it("weekday not end of month", async function () {
    const { instance, upgradedInstance, user } = await loadFixture(deployFixture);
    // Пятница не конец месяца
    const fridayTimestamp = 2841926057; // 2060-01-21 22:54:17
    await time.setNextBlockTimestamp(fridayTimestamp);

    await expect(instance.connect(user).createTokens())
      .to.be.revertedWithCustomError(upgradedInstance, "NotTodayV2")
      .withArgs(user.address, fridayTimestamp);
  });

  it("weekend end of month", async function () {
    const { instance, upgradedInstance, user } = await loadFixture(deployFixture);

    // Суббота, конец месяца, по новой логике  подходящий день
    const endOfMonthTimestamp = 2850544192; // 2060-04-30 16:49:52
    await time.setNextBlockTimestamp(endOfMonthTimestamp);

    // 21 день
    const expectedMintAmount = ethers.parseUnits((30 * 1000).toString(), 18);

    const tx = instance.connect(user).createTokens();
    await expect(tx).to.changeTokenBalance(instance, user, expectedMintAmount)
    await expect(tx).to.emit(upgradedInstance, "TodayV2")
      .withArgs(user.address, endOfMonthTimestamp);

  });
});
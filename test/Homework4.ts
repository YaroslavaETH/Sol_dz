import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Homework4v1", function () {

  async function deployFixture() {
    
    const [owner, forwarder, user] = await ethers.getSigners();

    const ContractFactory = await ethers.getContractFactory("Homework4");
    const instance = await upgrades.deployProxy(ContractFactory, [owner.address, owner.address, forwarder.address]);
    await instance.waitForDeployment();

    return { instance, owner, forwarder, user };
  }

  it("deploy", async function () {
    const { instance, owner, forwarder } = await loadFixture(deployFixture);
    // проверяем установка парамеров из инициализации
    expect(await instance.name()).to.equal("Homework4");
    expect(await instance.symbol()).to.equal("HW4");
    expect(await instance.trustedForwarder()).to.equal(forwarder.address);
    const ownerBalance = await instance.balanceOf(owner.address);
    expect(ownerBalance).to.equal(ethers.parseUnits("1000", 18));
  });

  it("version", async function () {
    const { instance } = await loadFixture(deployFixture);
    expect(await instance.version()).to.equal("1.0");
  });

  it("weekend", async function () {
    const { instance, user } = await loadFixture(deployFixture);
    //console.log("Latest 1:", await time.latest());
    // Суббота, сильно в будущем, чтобы на долго хватило теста
    const saturdayTimestamp = 2526451711; // 2050-01-22 15:08:31
    await time.setNextBlockTimestamp(saturdayTimestamp);

    await expect(instance.connect(user).createTokens())
      .to.be.revertedWithCustomError(instance, "NotToday")
      .withArgs(user.address, saturdayTimestamp);
    //console.log("Latest 2:", await time.latest());
  });

  it("weekday", async function () {
    const { instance, user } = await loadFixture(deployFixture);
    //console.log("Latest 1:", await time.latest());

    // Пятница
    const fridayTimestamp = 2526393257; // 2050-01-21 22:54:17
    await time.setNextBlockTimestamp(fridayTimestamp);

    // 21 день
    const expectedMintAmount = ethers.parseUnits((21 * 1000).toString(), 18);

    const tx = instance.connect(user).createTokens();
    await expect(tx).to.changeTokenBalance(instance, user, expectedMintAmount)
    await expect(tx).to.emit(instance, "Today")
      .withArgs(user.address, fridayTimestamp);

    //console.log("Latest 2:", await time.latest());
  });

  it("transferWithPermit", async function () {
    const { instance, owner, user } = await loadFixture(deployFixture);

    const spender = user;
    const value = ethers.parseUnits("100", 18);
    const deadline = (await time.latest()) + 3600; 

    const domain = {
      name: await instance.name(),
      version: "1", 
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: await instance.getAddress(),
    };

    const types = {
      Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };

    const message = {
      owner: owner.address,
      spender: spender.address,
      value: value,
      nonce: await instance.nonces(owner.address),
      deadline: deadline,
    };

    // owner подписывает сообщение
    const signature = await owner.signTypedData(domain, types, message);
    const { v, r, s } = ethers.Signature.from(signature);

    // spender вызывает функцию, используя подпись, и мы проверяем изменение балансов
    await expect(
      instance.connect(spender).transferWithPermit(owner.address, spender.address, value, deadline, v, r, s)
    ).to.changeTokenBalances(instance, [owner, spender], [-value, value]);

    // после успешного перевода, allowance должен быть равен 0
    expect(await instance.allowance(owner.address, spender.address)).to.equal(0);
  });

  it("change trusted forwarder", async function () {
    const { instance, owner, user } = await loadFixture(deployFixture);
    const newForwarder = user;

    await expect(instance.connect(owner).setTrustedForwarder(newForwarder.address))
      .to.emit(instance, "TrustedForwarderChanged")
      .withArgs(newForwarder.address);
  });

  it("meta-transaction", async function () {
    const { instance, forwarder, user } = await loadFixture(deployFixture);

    // Пятница
    const fridayTimestamp = 2526393257; // 2050-01-21 22:54:17
    await time.setNextBlockTimestamp(fridayTimestamp);

    // calldata функции createTokens
    const functionData = instance.interface.encodeFunctionData("createTokens");

    // добавляем адрес пользователя в конец calldata
    const data = ethers.concat([functionData, user.address]);

    // форвардер отправляет транзакцию, оплачивая газ
    const tx = forwarder.sendTransaction({
      to: await instance.getAddress(),
      data: data,
    });

    // токены должны быть начислены user
    const expectedMintAmount = ethers.parseUnits((21 * 1000).toString(), 18);
    await expect(tx).to.changeTokenBalance(instance, user, expectedMintAmount);
    await expect(tx).to.emit(instance, "Today")
      .withArgs(user.address, fridayTimestamp);
  });
});

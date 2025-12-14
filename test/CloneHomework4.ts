import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { CloneHomework4, Homework4 } from "../typechain-types";

describe("CloneHomework4 Factory", function () {
  async function deployCloneFactoryFixture() {
    const [owner, user, forwarder] = await ethers.getSigners();

    // контракт-реализация Homework4
    const Homework4Factory = await ethers.getContractFactory("Homework4");
    const implementation = await Homework4Factory.deploy();
    await implementation.waitForDeployment();
    const implementationAddress = await implementation.getAddress();

    // контракт-реализация Homework4V2
    const Homework4V2Factory = await ethers.getContractFactory("Homework4V2");
    const implementationV2 = await Homework4V2Factory.deploy();
    await implementationV2.waitForDeployment();
    const implementationAddressV2 = await implementationV2.getAddress();

    // фабрика CloneHomework4
    const CloneFactory = await ethers.getContractFactory("CloneHomework4");
    const factory = await CloneFactory.deploy();
    await factory.waitForDeployment();

    return { factory, implementationAddress, implementationAddressV2, owner, user, forwarder };
  }

  it("deploy clone", async function () {
    const { factory, implementationAddress, implementationAddressV2, owner, user, forwarder } = await loadFixture(
      deployCloneFactoryFixture
    );
    const salt = ethers.encodeBytes32String("something");

    // предсказанный адрес от фабрики
    const predictedAddressV1 = await factory.predictNewAddress(implementationAddress, salt);

    // развертываем клон и проверяем событие
    await expect(factory.deployHomework4(implementationAddress, salt))
      .to.emit(factory, "Homework4Deployed")
      .withArgs(predictedAddressV1, implementationAddress);

    // Подключаемся к развернутому клону, используя ABI от Homework4
    const cloneInstanceV1 = (await ethers.getContractAt(
      "Homework4",
      predictedAddressV1
    )) as Homework4;

    // проверяем, что версия соответствует реализации от нужной имплементации
    expect(await cloneInstanceV1.version()).to.equal("1.0");

    //баланс долженб быть равен 0, так как еще не инициализирован
    expect(await cloneInstanceV1.balanceOf(owner.address)).to.equal(0);

    // инициализируем клон
    await cloneInstanceV1.initialize(user.address, owner.address, forwarder.address);

    // Проверяем, что параметры установились правильно
    expect(await cloneInstanceV1.name()).to.equal("Homework4");
    expect(await cloneInstanceV1.owner()).to.equal(owner.address);
    expect(await cloneInstanceV1.trustedForwarder()).to.equal(forwarder.address);
    expect(await cloneInstanceV1.balanceOf(user.address)).to.equal(ethers.parseUnits("1000", 18));

    
    // развертываем клон от 2 имплементации и так же всё проверяем
    // предсказанный адрес от фабрики
    const predictedAddressV2 = await factory.predictNewAddress(implementationAddressV2, salt);

    // развертываем клон и проверяем событие
    await expect(factory.deployHomework4(implementationAddressV2, salt))
      .to.emit(factory, "Homework4Deployed")
      .withArgs(predictedAddressV2, implementationAddressV2);

    // Подключаемся к развернутому клону, используя ABI от Homework4
    const cloneInstanceV2 = (await ethers.getContractAt(
      "Homework4",
      predictedAddressV2
    )) as Homework4;

    // проверяем, что версия соответствует реализации от нужной имплементации
    expect(await cloneInstanceV2.version()).to.equal("2.0");

    //баланс долженб быть равен 0, так как еще не инициализирован
    expect(await cloneInstanceV2.balanceOf(owner.address)).to.equal(0);

    // инициализируем клон
    await cloneInstanceV2.initialize(user.address, owner.address, forwarder.address);

    // Проверяем, что параметры установились правильно и выполнена инициализация именно второй имплементации (через баланас user)
    expect(await cloneInstanceV2.name()).to.equal("Homework4");
    expect(await cloneInstanceV2.owner()).to.equal(owner.address);
    expect(await cloneInstanceV2.trustedForwarder()).to.equal(forwarder.address);
    expect(await cloneInstanceV2.balanceOf(user.address)).to.equal(ethers.parseUnits("3000", 18)); 
  });
});

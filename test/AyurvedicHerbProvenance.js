const { expect } = require("chai");
const { ethers } = require("hardhat");

function toBytes32(text) {
  return ethers.utils.formatBytes32String(text);
}

describe("AyurvedicHerbProvenance", function () {

  async function deploy() {
    const [admin, collector, verifier, outsider] = await ethers.getSigners();

    const Contract = await ethers.getContractFactory("AyurvedicHerbProvenance");
    const contract = await Contract.deploy();
    await contract.deployed();

    await contract.registerUser(collector.address, 2); // FARMER
    await contract.registerUser(verifier.address, 3);  // GPS_VERIFIER

    return { contract, admin, collector, verifier, outsider };
  }

  it("Registers users with roles", async function () {
    const { contract, collector } = await deploy();
    expect(await contract.roles(collector.address, 2)).to.equal(true);
  });

  it("Allows collector to record herb", async function () {
    const { contract, collector } = await deploy();

    await contract.connect(collector).recordHerb(
      toBytes32("Ashwagandha"),
      toBytes32("BATCH1"),
      toBytes32("12.97,77.59")
    );

    const herb = await contract.getHerb(toBytes32("BATCH1"));
    expect(herb.verified).to.equal(false);
  });

  it("Allows verifier to verify herb", async function () {
    const { contract, collector, verifier } = await deploy();

    await contract.connect(collector).recordHerb(
      toBytes32("Tulsi"),
      toBytes32("BATCH2"),
      toBytes32("11.01,76.95")
    );

    await contract.connect(verifier).verifyHerb(
      toBytes32("BATCH2")
    );

    const herb = await contract.getHerb(toBytes32("BATCH2"));
    expect(herb.verified).to.equal(true);
    expect(herb.verifier).to.equal(verifier.address);
  });

  it("Should revert when unauthorized user tries to record herb", async function () {
    const { contract, outsider } = await deploy();

    await expect(
      contract.connect(outsider).recordHerb(
        toBytes32("Neem"),
        toBytes32("BATCH3"),
        toBytes32("10.00,10.00")
      )
    ).to.be.revertedWith("Not authorized");
  });

  it("Should not allow verifier to record herb", async function () {
    const { contract, verifier } = await deploy();

    await expect(
      contract.connect(verifier).recordHerb(
        toBytes32("Brahmi"),
        toBytes32("BATCH4"),
        toBytes32("9.99,9.99")
      )
    ).to.be.revertedWith("Not authorized");
  });

  it("Should not allow double verification", async function () {
    const { contract, collector, verifier } = await deploy();

    await contract.connect(collector).recordHerb(
      toBytes32("Amla"),
      toBytes32("BATCH5"),
      toBytes32("8.88,8.88")
    );

    await contract.connect(verifier).verifyHerb(
      toBytes32("BATCH5")
    );

    await expect(
      contract.connect(verifier).verifyHerb(
        toBytes32("BATCH5")
      )
    ).to.be.revertedWith("Already verified");
  });

});

describe("AyurvedicHerbProvenance – Hash Anchoring", function () {

  async function deployWithAnchor() {
    const [admin, anchor, outsider] = await ethers.getSigners();

    const Contract = await ethers.getContractFactory("AyurvedicHerbProvenance");
    const contract = await Contract.deploy();
    await contract.deployed();

    await contract.setAnchorAuthorization(anchor.address, true);

    return { contract, anchor, outsider };
  }

  it("Allows authorized actor to anchor a hash", async function () {
    const { contract, anchor } = await deployWithAnchor();

    const collectionId = toBytes32("COLL-001");
    const hash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes("data1")
    );

    await contract.connect(anchor).anchorHash(collectionId, hash);

    expect(
      await contract.verifyHash(collectionId, hash)
    ).to.equal(true);
  });

  it("Prevents duplicate hash anchoring", async function () {
    const { contract, anchor } = await deployWithAnchor();

    const collectionId = toBytes32("COLL-002");
    const hash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes("data2")
    );

    await contract.connect(anchor).anchorHash(collectionId, hash);

    await expect(
      contract.connect(anchor).anchorHash(collectionId, hash)
    ).to.be.revertedWith("Already anchored");
  });

  it("Blocks unauthorized anchoring", async function () {
    const { contract, outsider } = await deployWithAnchor();

    await expect(
      contract.connect(outsider).anchorHash(
        toBytes32("COLL-003"),
        ethers.utils.keccak256(
          ethers.utils.toUtf8Bytes("data3")
        )
      )
    ).to.be.revertedWith("Not authorized");
  });

  it("Returns correct anchored hash count", async function () {
    const { contract, anchor } = await deployWithAnchor();

    const collectionId = toBytes32("COLL-004");

    await contract.connect(anchor).anchorHash(
      collectionId,
      ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("one")
      )
    );

    await contract.connect(anchor).anchorHash(
      collectionId,
      ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("two")
      )
    );

    const count = await contract.getAnchoredHashCount(collectionId);

    expect(count).to.equal(2);
  });

});

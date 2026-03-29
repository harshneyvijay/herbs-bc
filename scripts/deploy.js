const { ethers } = require("hardhat");

// Role constants from your contract
const FARMER_ROLE = 2;
const GPS_VERIFIER_ROLE = 3;
const LAB_TESTER_ROLE = 6;

async function main() {
  // 1️⃣ Use your single wallet
  const [wallet] = await ethers.getSigners();
  console.log("Using wallet:", wallet.address);

  // 2️⃣ Deploy the contract
  const Contract = await ethers.getContractFactory("AyurvedicHerbProvenance");
  const contract = await Contract.connect(wallet).deploy();
  await contract.deployed();
  console.log("Contract deployed at:", contract.address);

  // 3️⃣ Register your wallet for roles
  console.log("Registering roles for this wallet...");
  const txFarmer = await contract.registerUser(wallet.address, FARMER_ROLE);
  await txFarmer.wait();

  const txVerifier = await contract.registerUser(wallet.address, GPS_VERIFIER_ROLE);
  await txVerifier.wait();

  const txLab = await contract.registerUser(wallet.address, LAB_TESTER_ROLE);
  await txLab.wait();
  console.log("Roles registered ✅");

  // 4️⃣ Define herbs with GPS, batch IDs, and names
  const herbs = [
    { name: "Tulsi", batchId: "BATCH001", gps: "12.9716N_77.5946E" },
    { name: "Neem", batchId: "BATCH002", gps: "12.2958N_76.6394E" },
    { name: "Ashwagandha", batchId: "BATCH003", gps: "13.0827N_80.2707E" }
  ];

  // 5️⃣ Process each herb
  for (let herb of herbs) {
    const batchIdBytes = ethers.utils.formatBytes32String(herb.batchId);
    console.log(`\nProcessing herb: ${herb.name}, batch: ${herb.batchId}, GPS: ${herb.gps}`);

    // Farmer records the herb
    const txRecord = await contract.recordHerb(
      ethers.utils.formatBytes32String(herb.name),
      batchIdBytes,
      ethers.utils.formatBytes32String(herb.gps)
    );
    await txRecord.wait();
    console.log(`✅ Recorded by Farmer`);

    // GPS Verifier verifies the herb
    const txVerify = await contract.verifyHerb(batchIdBytes);
    await txVerify.wait();
    console.log(`✅ Verified by GPS Verifier`);

    // Lab Tester certifies the batch
    const txLabApprove = await contract.certifyLab(
      batchIdBytes,
      ethers.utils.formatBytes32String(`LAB_REPORT_${herb.batchId}`)
    );
    await txLabApprove.wait();
    console.log(`✅ Lab approved`);
  }

  console.log("\nAll herbs processed successfully through supply chain ✅");
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });

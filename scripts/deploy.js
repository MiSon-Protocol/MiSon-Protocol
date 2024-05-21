const { ethers, upgrades } = require("hardhat");

async function main() {
  const Asset = await ethers.getContractFactory("Asset"); 
  const ShareProfit = await ethers.getContractFactory("ShareProfit"); 
  const ShareProfit1 = await ethers.getContractFactory("ShareProfit");

  const usdt = ""
  const whiteListAddr = ""
  const withdrawAddr = ""

  const asset = await upgrades.deployProxy(Asset,[
    usdt,
    whiteListAddr,
    withdrawAddr,
  ], { initializer: 'initialize', unsafeAllow: ['delegatecall'] });

  const shareProfit = await ShareProfit.deploy(withdrawAddr)

  const shareProfit1 = await ShareProfit1.deploy(withdrawAddr)

  console.log("OK")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


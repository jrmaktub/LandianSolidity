async function main() {

    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    // // deploy contracts here:
    // const NFT = await ethers.getContractFactory("NFT");
    // const nft = await NFT.deploy();
    // const Marketplace = await ethers.getContractFactory("Marketplace");
    // const marketplace = await Marketplace.deploy(1);
  
  
  
    
    // // For each contract, pass the deployed contract and name to this function to save a copy of the contract ABI and address to the front end.
    // saveFrontendFiles(nft, "NFT");
    // saveFrontendFiles(marketplace, "Marketplace");
  
    // Get the ContractFactories and Signers here.
    const Ticket = await ethers.getContractFactory("Ticket");
    const Show = await ethers.getContractFactory("Show");
    // deploy contracts
    const show = await Show.deploy(1);
    const ticket = await Ticket.deploy();
    // Save copies of each contracts abi and address to the frontend.
    saveFrontendFiles(show , "Show");
    saveFrontendFiles(ticket , "Ticket");
  
    console.log("NFT contract address: ", ticket.address);
    console.log("Events contract address: ", show.address);
  }
  // npx hardhat run src/backend/scripts/deploy.js --network localhost
  //const contract = await ethers.getContractAt("NFT","0x5FbDB2315678afecb367f032d93F642f64180aa3")
  //const contract = await ethers.getContractAt("NFT","0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0")
  //const tokenCount = await contract.tokenCount()
  //npx hardhat console --network localhost
  //const marketplace = await ethers.getContractAt("Marketplace","0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0")
  //const marketplace = await ethers.getContractAt("Marketplace","0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e")
  
  
  function saveFrontendFiles(contract, name) {
    const fs = require("fs");
    const contractsDir = __dirname + "/../../frontend/contractsData";
  
    if (!fs.existsSync(contractsDir)) {
      fs.mkdirSync(contractsDir);
    }
  
    fs.writeFileSync(
      contractsDir + `/${name}-address.json`,
      JSON.stringify({ address: contract.address }, undefined, 2)
    );
  
    const contractArtifact = artifacts.readArtifactSync(name);
  
    fs.writeFileSync(
      contractsDir + `/${name}.json`,
      JSON.stringify(contractArtifact, null, 2)
    );
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  
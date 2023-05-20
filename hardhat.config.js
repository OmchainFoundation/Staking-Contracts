require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    hardhat: {
      accounts: {
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266": "10000000000000000000000000"
      }
    }
  },
};

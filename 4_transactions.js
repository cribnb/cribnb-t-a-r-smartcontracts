const TestToken = artifacts.require("TestToken");
const CribnbArbitration = artifacts.require("CribnbArbitration");
const CribnbTransaction = artifacts.require("CribnbTransactiont");

function parameterize(network) {
  switch (network) {
  case 'ropsten': // Ropsten
    return {
      token: "tokenaddress,
    };
  case 'development':
  case 'coverage':
    return {
      token: TestToken.address,
    };
  };
}


module.exports = function(deployer, network, accounts) {
  const parameters = parameterize(network);
  deployer.deploy(
    BeePayment,
    parameters.token, 
    '0x0' //gonna have to use the set arbitration address function 
    //parameters.arbitrationAddress 
  );

};



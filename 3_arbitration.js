const TestToken = artifacts.require("TestToken");
const CribnbArbitration = artifacts.require("CribnbArbitration");

function parameterize(network) {
  switch (network) {
  case 'ropsten': // Ropsten
    return {
      token: 
    };
  case 'development':
  case 'coverage':
    return {
      token: TestToken.address
    };
  };
}

module.exports = function(deployer, network, accounts) {
  const parameters = parameterize(network);
  deployer.deploy(
    CribnbArbitration,
    parameters.token,
    {gas: 8000000 }
    //{from: parameters.arbitrationContractOwner,  gas: 8000000 }
  );
};



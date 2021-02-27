const CribnbRating = artifacts.require("CribnbRating");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(
    CribnbRating,
    {gas: 8000000 }
    //{from: parameters.arbitrationContractOwner,  gas: 8000000 }
  );
};



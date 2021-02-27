pragma solidity ^0.4.24;

//import 'openzeppelin-solIdity/contracts/token/ERC20/ERC20.sol';
import './CribnbArbitration.sol';
// okay this can't be a contract in the same file... need to figrue it out'
// contract CribnbArbitration {
//     function requestArbitration(bytes32 paymentId, uint256 disputedCRBTokens, address host, address guest) external;
//     function normArbFee() external returns (uint256);
    
// }

contract CribnbTransaction {
    
    ERC20 crbToken;  //crb token address TODO
    address crbArbitrationContractAddress;
    CribnbArbitration crbArb;

    constructor (address crbTokenContractAddress, address arbitrationAddress)
    public 
    {
        crbArbitrationContractAddress = arbitrationAddress;
        crbToken = ERC20(crbTokenContractAddress);
        crbArb = CribnbArbitration(crbArbitrationContractAddress);
    }
    
    function setArbitrationAddress(address arbitrationAddress) public {
        CribnbArbitrationContractAddress = arbitrationAddress;
        crbArb = CribnbArbitration(crbArbitrationContractAddress);
    }
    
    
    function sendArbitrationRequest (address guest, address host, uint256 disputeAmt, bytes32 PaymentId) public  {
        //crbToken.mintFreeCRBTokens();
        disputeAmt = disputeAmt + crbArb.normArbFee();
        crbToken.approve(crbArbitrationContractAddress, disputeAmt);
        crbArb.requestArbitration(PaymentId, disputeAmt, guest, host);
        
     }
}


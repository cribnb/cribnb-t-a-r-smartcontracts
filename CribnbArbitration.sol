/************************
 * Version 0.1 of Cribnb Arbitration
 * WARNING: byte code is real close to ganache limit
 * a few more lines and it won't port over but if you
 * use remix you have some room to spare.  There must be a
 * optmizer for bytecode size somewhere
 * 
 * Not created for production
 * Not fully unit tested
 * No audits for hacking have 
 been done
 * ***********************/


pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';


contract BaseModifiers is Ownable{
    bool activated_;
    
    function activated() 
        public
        view
        returns (bool)
    {
        return activated_;
    }
    
    modifier isActivated() {
        require(activated_ == true, "its not ready yet"); 
        _;
    }

    function activateContract() public onlyOwner {
        activated_ = true;
    }

    function deactivateContract() public onlyOwner {
        activated_ = false;
    }

}
contract CribnbModifiers is BaseModifiers {
    mapping (address => bool) public whiteListedContracts;

    function addContractAddress(address _contractAddress) onlyOwner external {
        require(whiteListedContracts[_contractAddress]==false, "contract addres already added");
        whiteListedContracts[_contractAddress]=true;
    }
    function removeContractAddress(address _contractAddress) onlyOwner external {
        require (_contractAddress != 0, "contract address can't be 0");
        require (whiteListedContracts[_contractAddress] != false, "must be a valid address");
        delete(whiteListedContracts[_contractAddress]);
    }

    modifier isNotContract() {
        address _addr = msg.sender;
        require (_addr == tx.origin);
        uint256 _codeLength;
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry only white listed contracts allowed");
        _;
    }
    
    modifier isWhitelistedContract() {
        address _addr = msg.sender;
        require(whiteListedContracts[_addr]==true);
        _;
    }
}

contract CribnbArbEvents {
    
    event MinerBanned
    (
        uint256 minerId, //the unique Ids of the arbitration requested
        uint256 timestamp //timestamp of request
    );

    event MinerApproved
    (
        uint256 minerId, //the unique Ids of the arbitration requested
        uint256 timestamp //timestamp of request
    );


    // fired whenever an aribitration is requested
    event ArbRequested
    (
        uint256 arbitrationId, //the unique Ids of the arbitration requested
        bytes32 paymentId, //payment Ids are byte32s, reservation Id might be different
        uint256 timestamp, //timestamp of request
        uint256 minTime, //min timetimestamp to wait for when miners can start to try and arbitrate
        uint256 maxTime, //maximum timestamp to wait until before defaulting to default arbitrators
        uint256 crbTokensDispute, //amount of crb tokens in dispute
        uint256 crbTokensArbitration //amount of crb tokens paid for arbitration to occur
    );
    
    event MinerStartedMining
    (
        uint256 arbitrationId, //The unique id of miner
        uint256 minerIndexId, //The index of the miner array (really a set) they are in
        uint256 stake, //the stake the miner started mining with
        uint256 timestamp //timestamp of request
    );
    
    event MinerFailedStartedMining
    (
        uint256 arbitrationId, //The unique id of miner
        bytes32 errorMessage,
        uint256 stake, //the stake the miner started mining with
        uint256 timestamp //timestamp of request
    );

    event MinerStoppedMining
    (
        uint256 arbitrationId, //The unique id of miner
        uint256 stake, //the stake the miner started mining with
        uint256 timestamp //timestamp of request
    );

    event ArbitrationJobTriggered
    (
        uint256 arbitrationJobId, //The unique id of job triggered
        address triggermanAddress, //the address of the person who triggered the event
        uint256 path, //the path that the trigger took
        uint256 timestamp //timestamp of request
    );
    
    event ArbiterVoteSubmitted
    (
        uint256 arbiterId, //The unique id of abiter
        uint256 voteSubmitted, //the path that the trigger took
        uint256 timestamp //timestamp of request
    );
    // fired when not enough miners are present to start arbitration process
    event ArbDelayed
    (
        uint256 errorCode, //1 = not enough miners
        uint256 arbitrationId, //the unique Id of the arbitration requested
        bytes32 paymentId, //payment Ids are byte32s, reservation Id might be different
        uint256 timestamp //timestamp
    );

    // fired when an arbitraion is completed
    event ArbCompleted
    (
        uint256 arbitrationId, //the unique Id of the arbitration requested
        //maybe put in who voted for what in here too?
        uint256 voteResult, // percent 0 - 100 awarded to guest, rest awarded to host
        bytes32 paymentId, //payment Ids are byte32s, reservation Id might be different
        uint256 timestamp //timestamp of vote
    );
    
    event ArbiterPaid
    (
        uint256 arbiterId, //id of arbiter
        uint256 vote, // vote casted
        uint256 amountPaid, //amount paid
        uint256 timestamp //timestamp of vote
    );

    event ArbiterPenalized
    (
        uint256 arbiterId, //id of arbiter
        uint256 voteId, // the unique id of the vote they needed to do but failed to do
        uint256 crbTokenTaken, //amount paid
        uint256 crbTokenStaked, //amount paid
        uint256 timestamp //timestamp of vote
    );

    
}

contract CribnbeArbitrationStructs {
    struct ArbitrationJob {
        uint256 arbitrationId; //if this was an appeal, this is the Id of the arbitration it came from
        bytes32 paymentId; //payment Ids are byte32s, reservation Id might be different
        uint256 timestamp; //timestamp of request
        uint256 minMinerTime; //min timetimestamp to wait for when miners can start to try and arbitrate
        uint256 maxMinerTime; //maximum timestamp to wait until before defaulting to default arbitrators
        uint256 appealTimelimit; //maximum time allowed for appeal
        uint256 crbTokensArbitrationFee; //amount of crb tokens paid for arbitration to occur
        uint256 [] arbiterVoteIds;
        uint256 disputedAmountOfCRBTokens;
        address host;
        address guest; 
    }
    
    enum ArbiterAccessState {
        PENDING_APPROVAL,      // can trigger but cannot mine
        APPROVED,    // can trigger and can mine
        BANNED //can trigger but cannot mine
    }

    //try to use up 256 bits
    struct Arbiter {
        ArbiterAccessState accessState;//8bit int, holds info if they can mine or trigger
        address minerAddress; 
        uint256 miningArrayIndex;
        uint256 currentCRBTokenStake;
        uint256 arbitrationsCompleted; //maybe put this in reputation api
        uint256 arbitrationsAppealed;  //maybe put this in reputation api
        uint256 [] arbiterVoteIds;
    }
    
    enum VoteState {
        NOT_ASSIGNED_TO_ARBITER, //assigned to a job but not yet assigned to a miner / arbiter yet
        PENDING_VOTE, //Arbiter hasn't voted yet
        VOTE_COMPLETE, //Arbiter has voted
        PENALIZED_NO_VOTE, //Arbiter failed to vote by min mining time and was penalized for it
        VOTE_PAID //Arbiter voted and was paid for it
    }

    struct ArbiterVote {
        VoteState state; //0 hasn't voted, 1 has voted, 2 penealized for not voting (NOTE: since we have extra bits, why not)
        uint8 vote;//0 by default
        uint256 arbitrationJobId;
        uint256 arbiterId;
    }
    
    struct MinerTicketHolder {
        uint256 miningId;
        uint256 numLottoTickets;
    }
}

contract CribnbArbitration is CribnbArbEvents, CribnbModifiers, CribnbArbitrationStructs {
    using SafeMath for uint256;

    uint8 crbTokenPenality = 100; //0-100% pentality for Arbiters's staked crb tokens if submission isn't completed by max time
    uint8 activeMinerPayPercentage = 100; //After the triggerman get's paid, this is the percentage of crb tokens that are left over that get distributed among the arbiters
    uint8 percentPenTokensToFee = 100; //percent of crb tokens taken from miners who didn't vote put into miners fee.  rest just lives in contract until owner pulls it out
    
    uint8 percentAppealFeeToDisputeAmount = 0; //percent of crb tokens after we subtract arbitration fee to be put into dispute amount for host/ guest, the rest goes to owner of contract

    uint8 [] triggermanPayCRBTokenAmount = [2,3,3,3,3,3];  //how much the triggerman gets paid.  each element in the array is a pay path
    uint8 [] percentDisputedChoices = [0,25,50,75,100];//0,25,50,75,100 in whitepaper.  percent of crb tokens of the disputed amount to be distributed to the winner.  This is the vote choices

    uint8 nonce = 0; //used for random number generation
    uint8 appealMultCost = 2; //multiplier of previous appeal cost so they appeal less
    uint8 arbitersPerJob = 5;

    //todo figure out gas price of executing everything, write up code that gets current eth price and current crb price then figures out a correct arb fee or static?
    uint256 public normArbFee = 1110000; //fee we charge to do arbitrations

    uint256 public minMiningStake = 1000; //min number of crb tokens needed to stake for miners
    uint256 minMinerTime = 1 days; //min time to wait before miners can be selected as Arbiters
    uint256 maxMinerTime = 5 days; //max time to wait before going to default Arbiters
    uint256 appealTime = 3 days; //max time allowed for users to appeal decisions

    Arbiter [] public existingArbiters;//requirement is existing Arbiters index 0 needs to be taken in constuctor because mapping returns 0 if not there
    MinerTicketHolder [] public arbitersMining; //we can't make this into a view because the contract that modifies data will need this info, read costs like 5k, write is 20k
    ArbitrationJob [] public arbitrationJobs;
    ArbiterVote [] public arbVotes;

    mapping (address => uint256) public addressToMinerId;
    uint256 [] public jobsInProgress; //when an arbitration job comes in, the Id is in here till it is completed or appealed
    mapping (bytes32 => uint256[]) public paymentIdToJobIds;

    
    address crbTokenContractAddress;
    ERC20 crbToken;  
    
    
////////
//OWNER FUNCTIONS 
////////
    /**
     * @dev default function, unsure about this at the moment, maybe disable
     *  -functionhash- unknown yet
     */
    function () public payable {
        revert();
    }


    /**
     * @dev constructor, adds default values for everything and adds in
     *    a dummy var for our pointers that maps can go to.  A map value without
     *    a key produces a value of 0, so as an extra safeguard, I put in dummy
     *    values at location 0 so if there is a problem it's not as bad
     *  -functionhash- unknown yet
     */
    constructor(address crbTokenAddress) 
    public 
    {
        crbTokenContractAddress = crbTokenAddress;
        crbToken = ERC20(crbTokenContractAddress);

        
        Arbiter memory dummyArbiter = Arbiter({
            accessState:ArbiterAccessState.BANNED,
            minerAddress:0x0,
            currentCRBTokenStake:0, 
            arbitrationsCompleted:0, 
            arbitrationsAppealed:0, 
            miningArrayIndex:0,
            arbiterVoteIds:new uint256[](0)
        });
        existingArbiters.push(dummyArbiter);
        
        
        
        ArbitrationJob memory dummyArbiterJob = ArbitrationJob({
            arbitrationId:0,
            paymentId:"dummyJob",
            timestamp:0,
            minMinerTime:0, 
            maxMinerTime:0,
            appealTimelimit:0,
            crbTokensArbitrationFee:0,
            arbiterVoteIds:new uint256[](arbitersPerJob),
            disputedAmountOfCRBTokens:0,
            host:0x0,
            guest:0x0
        });
        arbitrationJobs.push(dummyArbiterJob);
        
        jobsInProgress.push(0); //not really needed but lets make it consistant

        
        //not really needed but better safe then sorry if someone decides to add in a mapping to this array    
        ArbiterVote memory dummyArbiterVote = ArbiterVote({
            state:VoteState.PENDING_VOTE,
            arbitrationJobId:0,
            vote:0,
            arbiterId:0
        });
        arbVotes.push(dummyArbiterVote);



        MinerTicketHolder memory curTickets = MinerTicketHolder({
            miningId:0, 
            numLottoTickets:0
        });
        arbitersMining.push(curTickets);


    }

    /**
     * @dev owner of the contract has to approve all miners before they can vote
     *  -functionhash- unknown yet
     * @param arbId arbitrationId of the arbiter / miner
     */
    function approveMiner(uint256 arbId)
        onlyOwner()
        external
    {
        require(arbId < existingArbiters.length, "no arbiter by that number exists");
        Arbiter storage curMiner = existingArbiters[arbId];
        curMiner.accessState = ArbiterAccessState.APPROVED;
//        emit MinerApproved(arbId, now);
    }

    /**
     * @dev take a ban a miner from voting again
     *  -functionhash- unknown yet
     * @param arbId arbitrationId of the arbiter / miner
     */
    function banMiner(uint256 arbId)
        onlyOwner()
        external
    {
        require(arbId < existingArbiters.length, "no arbiter by that number exists");
        Arbiter storage curMiner = existingArbiters[arbId];
        curMiner.accessState = ArbiterAccessState.BANNED;
        
        uint index = curMiner.miningArrayIndex;
        if (index >= 1) {
            removeMinerFromQueue(index);
            curMiner.miningArrayIndex = 0;
            //they could still be voting so we don't want to return their stake in case we need to penalize them later
            //require(crbToken.transfer(curMiner.minerAddress, curMiner.currentCRBTokenStake), "transfer to miner stake failed");
            //curMiner.currentCRBTokenStake = 0;
        }
//        emit MinerBanned(arbId, now);
    }

    //Ability for owner to transfer other ERC20 tokens as well as crb dust out
    function transferToken(address tokenContractAddress, address transferTo, uint256 value) 
        onlyOwner 
        external 
    {
        ERC20 token = ERC20(tokenContractAddress); 
        if (tokenContractAddress == crbTokenContractAddress) { //if owner is transfering out crb token dust, make sure owner doesn't try and transfer out promised crb tokens
            uint256 promisedCRBTokens = 0;
            for (uint256 i =0; i<arbitrationJobs.length; i++) {
                if (now < arbitrationJobs[i].appealTimelimit || now < arbitrationJobs[i].maxMinerTime || now < arbitrationJobs[i].minMinerTime) {
                    promisedCRBTokens += arbitrationJobs[i].crbTokensArbitrationFee;
                    promisedCRBTokens += arbitrationJobs[i].disputedAmountOfCRBTokens;
                }
            }
            
            for (uint256 j =0; j<arbitersMining.length; j++) {
                promisedCRBTokens += existingArbiters[arbitersMining[j].miningId].currentCRBTokenStake;
            }
            
            uint256 extraCRBTokens = token.balanceOf(this)-promisedCRBTokens;
            require(value <= extraCRBTokens, "not enough crb tokens");
        }
         require(token.transfer(transferTo, value), "trasfer of crb tokens to user failed");
    }

////////
//payment contract FUNCTIONS 
////////

    /**
     * @dev crb payment contract must transfer the tokens before calling this
     *  method or it will return an error.  only payment contract can call this
     *  Starts up an arbitration, don't forget to pay the arbitration fee on top
     *  of the dispute amount
     *  -functionhash- unknown yet
     * @param paymentId The Id that all the booking info is under
     * @param disputedCRBTokensAndFee How many crb tokens are under dispute
     * @param host The host eth wallet address
     * @param guest The guest eth wallet address
     */
     //norm flow testing complete
    function requestArbitration(bytes32 paymentId, uint256 disputedCRBTokensAndFee, address guest, address host)
        external
        isWhitelistedContract()
        isActivated()
    { 
        require(crbToken.transferFrom(msg.sender, address(this), disputedCRBTokensAndFee), "unable to transfer tokens from contract"); 
        createJob(paymentId, disputedCRBTokensAndFee.sub(normArbFee), host, guest, 0);

        //event launched in create job, less reads
    }

////////
//Everyone else FUNCTIONS 
////////
    
    /**
     * @dev anyone can request an appeal but usually the host / guest would. 
     *   as a design decision I could limit it to a host or guest, but if there
     *   is a bad vote, we as crb token can pay to request an appeal.
     *   
     *  -functionhash- unknown yet
     * @param prevArbId the arbitration that the person wants to dispute
     */     
    function requestAppeal(uint256 prevArbId)
        external
        isNotContract()
        isActivated()
    {
        require(arbitrationJobs.length > prevArbId, "prev ruling does not exist");
        ArbitrationJob memory prevJob = arbitrationJobs[prevArbId];
        
        require(now < prevJob.appealTimelimit, "previous rulling appeal time has already concluded");
        require(now > prevJob.maxMinerTime, "previous rulling is still being voted on");
        
        require(msg.sender == prevJob.host || msg.sender == prevJob.guest || msg.sender == owner, "appeal only avalible to guest, host or owner");

        uint256 appealCost = normArbFee.mul(appealMultCost);

        //request money for appeal 
        require(crbToken.transferFrom(msg.sender, address(this), appealCost), "payment for appeal rejected"); 
        uint256 extraCRBTokensFromAppeal = appealCost.sub(normArbFee);
        uint256 crbToAddToDispute = extraCRBTokensFromAppeal.mul(percentAppealFeeToDisputeAmount) / 100;

        createJob(prevJob.paymentId, prevJob.disputedAmountOfCRBTokens.add(crbToAddToDispute)
        , prevJob.host, prevJob.guest, prevArbId);
        
        removeIndexFromArray(prevArbId, jobsInProgress);
        payArbs(prevJob);
        
    }

    
    /**
     * @dev preferabilly this is called when something is in the queue ready
     *   to get mined otherwise it's kind of wasted gas.  it announces that
     *   the user is ready to get picked to be an arbiter
     *  -functionhash- unknown yet
     * @param crbToStake The amount of crb tokens the miner is staking
     */
     //norm flow tested
    function startMining(uint256 crbToStake)
        external
        isNotContract()
        isActivated()
    {
        require(crbToStake >= minMiningStake, "crb token stake not at least minimum required");
        //check to see if user has a miner Id, if not, create miner and assign Id
        uint256 minerId = addressToMinerId[msg.sender];
        if (minerId == 0) {
            //create miner
            minerId = registerNewUser();
        }
        Arbiter memory curMiner = existingArbiters[minerId];
        if (curMiner.accessState == ArbiterAccessState.APPROVED) {
            require (curMiner.miningArrayIndex == 0, "miner already in mining queue"); //require that the user is not currently in the mining state        
            require(crbToken.transferFrom(curMiner.minerAddress, address(this), crbToStake), "crb token stake payment fail"); //get staked tokens
            curMiner.currentCRBTokenStake = crbToStake;
            
            //put miner into mining queue
            uint256 completedJobs = curMiner.arbitrationsCompleted.add(2); //make it not perfect and avoid div 0 err
            uint256 appealed = curMiner.arbitrationsAppealed.add(1); //make it not perfect and avoid div 0 err
            uint256 goodJobs = completedJobs.sub(appealed);
            uint256 tickets = crbToStake.mul(goodJobs) /completedJobs;
        
        
            MinerTicketHolder memory curTickets = MinerTicketHolder({
                miningId:minerId, 
                numLottoTickets:tickets
            });
        
            uint256 minerArrayIndex = arbitersMining.push(curTickets)-1;
            curMiner.miningArrayIndex = minerArrayIndex;
            existingArbiters[minerId] = curMiner;            
            emit MinerStartedMining(minerId,minerArrayIndex, crbToStake, now);

        } else {
            if (curMiner.accessState == ArbiterAccessState.BANNED) {
                emit MinerFailedStartedMining(minerId,"miner banned", crbToStake, now);
            } else if (curMiner.accessState == ArbiterAccessState.PENDING_APPROVAL) {
                emit MinerFailedStartedMining(minerId,"miner pending approval", crbToStake, now);
            }
        }

    }
    /**
     * @dev stops mining for the caller if they are in the mining state 
     *  -functionhash- unknown yet
     */
     //norm flow tested
    function stopMining()
        external
        isNotContract()
        isActivated()
    {
        //take miner out of mining queue
        uint256 minerId = addressToMinerId[msg.sender];
        require (minerId >=1, "miner doesn't exist");
        Arbiter memory curMiner = existingArbiters[minerId];

        uint index = curMiner.miningArrayIndex;
        require(index > 0, "miner not in mining queue"); //require that the user is currently mining
        
        removeMinerFromQueue(index);

        require(crbToken.transfer(curMiner.minerAddress, curMiner.currentCRBTokenStake), "transfer to miner stake failed");

        emit MinerStoppedMining (minerId, curMiner.currentCRBTokenStake, now);
        curMiner.currentCRBTokenStake = 0;
        curMiner.miningArrayIndex = 0;
        existingArbiters[minerId] = curMiner;
    }
    /**
     * @dev A triggerman would use checkTriggermanNextNeededJob for free on 
     *      client side until they see something that needs to be triggered.
     *      after that they would call this function to trigger an event and
     *      get paid for it
     *  -functionhash- unknown yet
     * @param arbitrationInProgressJobId the index of the arbitration job inside arbitration job
     */
    function triggerArbJob(uint256 arbitrationInProgressJobId)
        external
        isNotContract()
        isActivated()
    {
//TODO figure out gas it takes to do each one of the states, then assign percentage of single Arbiter pay for it
        require (arbitrationInProgressJobId<jobsInProgress.length, "job doesn't exist");
        uint256 arbitraionJobId = jobsInProgress[arbitrationInProgressJobId];
        ArbitrationJob storage currentJob = arbitrationJobs[arbitraionJobId];

        //TODO this can be heavily optmized, way too many reads
        //check if miner job is voteComplete
        uint256 votesInProgress = 0;
        uint256 nonAssignedVotes = 0;
        for (uint256 i=0; i < currentJob.arbiterVoteIds.length; i++) {
            if (arbVotes[currentJob.arbiterVoteIds[i]].state == VoteState.VOTE_COMPLETE) {
                votesInProgress++;
            } else if (arbVotes[currentJob.arbiterVoteIds[i]].state == VoteState.NOT_ASSIGNED_TO_ARBITER) {
                nonAssignedVotes++;
            }
        }

        uint256 votersNeeded = arbitersPerJob - votesInProgress;

        if (nonAssignedVotes >0 && now > currentJob.minMinerTime && now < currentJob.maxMinerTime) { //job ready for miners to arbitrate, min time has been waited, assign Arbiters
            require (arbitersMining.length >= arbitersPerJob+1, "needs enough arbiters to init a vote state: createJob"); //TODO Optimization need to filter out unique miners from arbs mining.length < votes needed
            //select miners
            selectArbitersFromMiners (currentJob, arbitraionJobId);
            currentJob.maxMinerTime = now.add(maxMinerTime);
            payTriggerman(1, currentJob);
            emit ArbitrationJobTriggered(arbitraionJobId, msg.sender, 1, now);
        } else if (votersNeeded == 0 && now > currentJob.maxMinerTime  && currentJob.appealTimelimit == 0) { //vote complete, set timer for users to appeal
            //set max appeal time
            currentJob.appealTimelimit = now.add(appealTime);
            payTriggerman(2, currentJob);
            emit ArbitrationJobTriggered(arbitraionJobId, msg.sender, 2, now);
        } else if (votersNeeded == 0 && now > currentJob.maxMinerTime && now > currentJob.appealTimelimit) { //vote complete and no appeal has taken place in max appeal time, render judgement
            //remove from jobsInProgress
            removeIndexFromArray(arbitrationInProgressJobId, jobsInProgress);
            //refund people / give either the renter or rentee the money
            abideByFinalVoteOfArbs(currentJob, arbitraionJobId);
            payArbs(currentJob);
            payTriggerman(3, currentJob);
            emit ArbitrationJobTriggered(arbitraionJobId, msg.sender, 3, now);
        //if vote not complete
        } else if (votersNeeded > 0 && now > currentJob.minMinerTime && now > currentJob.maxMinerTime) {//some people didn't vote or the max timer ran out
            penalizeArbitersForNotVoting (currentJob, arbitraionJobId); //penalize and boot all arbiters who didn't vote
            require (arbitersMining.length >= arbitersPerJob+1, "needs enough arbiters to init a vote state:vote not complete"); //TODO Optimization need to filter out unique miners from arbs mining.length < votes needed
            selectArbitersFromMiners (currentJob, arbitraionJobId);
            currentJob.minMinerTime = now.sub(2);
            currentJob.maxMinerTime = now.add(maxMinerTime);
            payTriggerman(4, currentJob);
            
            emit ArbitrationJobTriggered(arbitraionJobId, msg.sender, 4, now);
            emit ArbDelayed(1, arbitraionJobId, currentJob.paymentId, now);
        } else {
            //failed to trigger anything
            emit ArbitrationJobTriggered(arbitraionJobId, msg.sender, 0, now);
        }

    }
    /**
     * @dev once the miner is named to be an arbiter, then they can get paid to
     *   vote, once they vote, we pay them.  The arbiter will only get the
     *   payment Id and amount of crb in dispute info from this contract,
     *   they will need to get the rest of the info via centeralized backend
     *   or payment contract for now (TODO change when storage gets cheaper)
     *  -functionhash- unknown yet
     * @param voteId the vote id of the vote that the arbiter is processing
     * @param vote the vote that the arbiter is casting
     */
    function arbitrationVote(uint256 voteId, uint8 vote)
        external
        isNotContract()
        isActivated()
    {
     
        ArbiterVote storage currentVote = arbVotes[voteId];
        Arbiter storage curArb = existingArbiters[currentVote.arbiterId];
        require (msg.sender == curArb.minerAddress, "only arbiter assigned to vote can vote"); //make sure it's the miner who owns the vote who is voting
        require(vote < percentDisputedChoices.length, "vote needs to be within the vote options");
        
        ArbitrationJob storage currentJob = arbitrationJobs[currentVote.arbitrationJobId];
        require (currentJob.maxMinerTime > now, "can't vote / change vote after time limit is completed");//make sure they still got time to vote
        
        //check to see if vote was discarded because user didn't vote in time
        require (currentVote.state == VoteState.PENDING_VOTE ||
        currentVote.state == VoteState.VOTE_COMPLETE, "vote state invalid");
        
        currentVote.vote = vote;
        currentVote.state = VoteState.VOTE_COMPLETE;
        

        emit ArbiterVoteSubmitted(currentVote.arbiterId, vote, now);
    }
    
    /**
     * @dev usually called via client so it doesn't cost gas because it's a view
     *   then the client uses info to trigger actions and get paid for it returns next job needed to trigger
     *   can also just be done client side 
     *  -functionhash- unknown yet
     */
    function checkTriggermanNextNeededJob()
        external
        view
        returns (uint256) //returns next job needed to get triggered
    { 
        for (uint256 i = 1; i<jobsInProgress.length; i++) {
            if (checkTriggermanNeededSingleJob(jobsInProgress[i])) {
                return jobsInProgress[i];
            }
        }
        return 0;
    }
    /**
     * @dev checks to see if a job is ready to get triggered
     * 
     *  -functionhash- unknown yet
     * @param arbitrationInProgressJobId the index of the arbitration job inside arbitration job
     */
    function checkTriggermanNeededSingleJob(uint256 arbitrationInProgressJobId) 
        public
        view
        returns (bool)
    {
        require (arbitrationInProgressJobId<jobsInProgress.length, "arb job does not exit");
        uint256 arbitraionJobId = jobsInProgress[arbitrationInProgressJobId];
        ArbitrationJob storage currentJob = arbitrationJobs[arbitraionJobId];

        //check if miner job is voteComplete
        uint256 votesInProgress = 0;
        uint256 nonAssignedVotes = 0;
        for (uint256 i=0; i < currentJob.arbiterVoteIds.length; i++) {
            if (arbVotes[currentJob.arbiterVoteIds[i]].state == VoteState.VOTE_COMPLETE) {
                votesInProgress++;
            } else if (arbVotes[currentJob.arbiterVoteIds[i]].state == VoteState.NOT_ASSIGNED_TO_ARBITER) {
                nonAssignedVotes++;
            }
        }

        uint256 votersNeeded = arbitersPerJob - votesInProgress;
        

        if (nonAssignedVotes >0 && now > currentJob.minMinerTime && now < currentJob.maxMinerTime) { //job ready for miners to arbitrate, min time has been waited, assign Arbiters
            if (arbitersMining.length > arbitersPerJob+1) { //TODO Optimization need to filter out unique miners from arbs mining.length < votes needed
                return false;
            } 
            return true;    
        } else if (votersNeeded == 0 && now > currentJob.maxMinerTime  && currentJob.appealTimelimit == 0) { //vote complete, set timer for users to appeal
            return true;
        } else if (votersNeeded == 0 && now > currentJob.maxMinerTime && now > currentJob.appealTimelimit) { //vote complete and no appeal has taken place in max appeal time, render judgement
            return true;
        } else if (votersNeeded > 0 && now > currentJob.minMinerTime && now > currentJob.maxMinerTime) {//some people didn't vote or the max timer ran out
            //TODO predict how many arbiters will get dropped because they didn't vote and use arbitersPerJob+ needed arbs instead of *2
            if (arbitersMining.length > (arbitersPerJob*2)+1) { //TODO Optimization need to filter out unique miners from arbs mining.length < votes needed
                return false;
            } 
            return true;
        }

        return false;
    }

    /**
     * @dev  next vote id that they need to do or 0 if no current jobs are avalible
     * 
     *  -functionhash- unknown yet
     */
    function getMyFirstIncompletedVote() 
        external
        view
        returns (uint256)
    {
        uint256 minerId = addressToMinerId[msg.sender];
        require (minerId >0, "miner doesn't exist");
        Arbiter memory curMiner = existingArbiters[minerId]; 

        for(uint256 i = 0; i<curMiner.arbiterVoteIds.length; i++) {
            uint256 voteId = curMiner.arbiterVoteIds[i];
            ArbiterVote memory currentVote = arbVotes[voteId];
            if (currentVote.state == VoteState.PENDING_VOTE) {
                return voteId;
            }
        }
        return 0;
    }
////////
//INTERNAL HELPER FUNCTIONS 
////////

    //arbitors don't get paid until the end of the arbitration is appealed or 
    function payArbs (ArbitrationJob memory currentJob) 
        internal
    {
        uint256 crbTokenPaymentForArbitration = currentJob.crbTokensArbitrationFee.mul(activeMinerPayPercentage) / 100;
        crbTokenPaymentForArbitration = crbTokenPaymentForArbitration/currentJob.arbiterVoteIds.length;
           
        for (uint256 i=0; i < currentJob.arbiterVoteIds.length; i++) {
            ArbiterVote storage currentVote = arbVotes[currentJob.arbiterVoteIds[i]]; //storage cuz we are gonna mark as paid after
            require(currentVote.state != VoteState.VOTE_PAID, "vote already paid");
            currentVote.state = VoteState.VOTE_PAID;
            uint256 minerId = currentVote.arbiterId;
            Arbiter memory curMiner = existingArbiters[minerId];
            require(crbToken.transfer(curMiner.minerAddress, crbTokenPaymentForArbitration), "err transfering to arbiter for voting");
        
            
            emit ArbiterPaid(minerId, currentVote.vote, crbTokenPaymentForArbitration, now);
        }

    }

    /**
     * @dev creates a job
     *  -functionhash- unknown yet
     * @param paymentId The Id that all the booking info is under
     * @param disputedCRBTokens How many crb tokens are under dispute
     * @param host The host eth wallet address
     * @param guest The guest eth wallet address
     * @param arbitrationId If the job came from an appeal, the arbitrationId of the original job
     */
    function createJob(bytes32 paymentId, uint256 disputedCRBTokens, address host, address guest, uint256 arbitrationId)
        internal
        
    {
        uint256 arbitrationFee = normArbFee;
        //check to see if we have enough crb tokens in the wallet to do as promised
        uint256 totalPromisedCRBTokens = arbitrationFee.add(disputedCRBTokens);
        for (uint i=0; i<arbitrationJobs.length; i++) {
            // do something
            totalPromisedCRBTokens.add(arbitrationJobs[i].crbTokensArbitrationFee);
        }
        require (crbToken.balanceOf(address(this)) >= totalPromisedCRBTokens, "not enough crb tokens in contract to do job");
        //require (disputedCRBTokens > surgeArbFee); //make sure they have enough to pay for surge plus triggerman TODO: figure out triggerman cost sub norm arb cost
        uint256 timeRquested = now;
        uint256 curArbId = arbitrationJobs.length;
        ArbitrationJob memory currentJob = ArbitrationJob({
            arbitrationId:arbitrationId, 
            paymentId:paymentId, 
            timestamp:timeRquested, 
            minMinerTime:timeRquested.add(minMinerTime), 
            maxMinerTime:timeRquested.add(minMinerTime).add(maxMinerTime), 
            appealTimelimit:0,
            crbTokensArbitrationFee:arbitrationFee,
            arbiterVoteIds:new uint256[](arbitersPerJob),
            disputedAmountOfCRBTokens:disputedCRBTokens,
            host:host,
            guest:guest
        });
    
        arbitrationJobs.push(currentJob);
        addVotesToJob(arbitrationJobs[curArbId], curArbId);

        paymentIdToJobIds[paymentId].push(curArbId);
        //put into arbitration queue
        jobsInProgress.push(curArbId);
        
        emit ArbRequested(arbitrationId, paymentId, timeRquested, timeRquested.add(minMinerTime), timeRquested.add(maxMinerTime), disputedCRBTokens, arbitrationFee);
    }
    
    /**
     * @dev add votes to job
     *  -functionhash- unknown yet
     * @param currentJob The arbitration job we are adding votes to
     * @param currentJobId The Id of the arbitrationJob
     */
    function addVotesToJob(ArbitrationJob storage currentJob, uint256 currentJobId)
        internal
    {
        for (uint256 currentJobVoteIndex=0; currentJobVoteIndex<arbitersPerJob; currentJobVoteIndex++) {
            assignVote(currentJob, currentJobId, currentJobVoteIndex);
        }
    }
  
    /**
     * @dev crate vote at location index of job and replace old vote that was there if there was an old vote
     *  -functionhash- unknown yet
     * @param currentJob The arbitration job we are adding votes to
     * @param currentJobId The Id of the arbitrationJob
     * @param currentJobVoteIndex The index of the vote in the aribtration job vote array we are modifying
     */
    function assignVote(ArbitrationJob storage currentJob, uint256 currentJobId, uint256 currentJobVoteIndex)
        internal
    {
        ArbiterVote memory addVote = ArbiterVote({
            state:VoteState.NOT_ASSIGNED_TO_ARBITER, 
            arbitrationJobId:currentJobId, 
            vote:0, 
            arbiterId:0
        });
        uint256 voteIndex = arbVotes.push(addVote)-1;
        currentJob.arbiterVoteIds[currentJobVoteIndex] = voteIndex;
   }
  
    /**
     * @dev Internal function.  it removes an element from an array stored on
     *   the blockchain without keeping order at a O(1) efficency
     *  -functionhash- unknown yet
     * @param index The index of the array we are removing
     * @param arr The array we are modifying
     */
    function removeIndexFromArray (uint256 index, uint256 [] storage arr) 
        internal
    { //maybe make a memory version of this for functions that loaded everything into memory so it cost less gas
        require(index < arr.length, "index doesn't exist in array");
        uint lastIndex = arr.length.sub(1);
        arr[index] = arr[lastIndex];
        delete arr[lastIndex];
        arr.length = lastIndex;
    }
    
    /**
     * @dev Internal function.  it removes a miner from the mining queue
     *  -functionhash- unknown yet
     * @param index The index of the array we are removing
     */
    function removeMinerFromQueue (uint256 index) 
        internal
    { //maybe make a memory version of this for functions that loaded everything into memory so it cost less gas
        require(index >= 1, "can't remove dummy miner");
        require(index < arbitersMining.length, "index doens't exist in mining queue");
        uint lastIndex = arbitersMining.length.sub(1);
        arbitersMining[index] = arbitersMining[lastIndex];
        
        Arbiter storage curMiner = existingArbiters[arbitersMining[lastIndex].miningId];
        curMiner.miningArrayIndex = index;
        
        delete arbitersMining[lastIndex];
        arbitersMining.length = lastIndex;
    }

    
    
    /**
     * @dev penalize arbitors for not voting by taking some of their stake and
     *   taking them off the mining queue
     * 
     *  -functionhash- unknown yet
     * @param currentJob The arbitration job we are searching through for non voters
     * @param currentJobId The arbitration job id that corrasponds to the arbitration job we passed in
     */
    function penalizeArbitersForNotVoting (ArbitrationJob storage currentJob, uint256 currentJobId) 
        internal
    {
        uint256 [] memory jobVotes = currentJob.arbiterVoteIds;
        

        uint256 crbTokenTaken = 0;
        //trim non voters out and keep the ones who voted
        for (uint256 currentJobIndex = 0; currentJobIndex<jobVotes.length; currentJobIndex++) {
            if (jobVotes[currentJobIndex] != 0 && arbVotes[jobVotes[currentJobIndex]].state == VoteState.PENDING_VOTE) { //keep votes that happened
                crbTokenTaken += penalizeArbiter(jobVotes[currentJobIndex]);
                //replace bad vote slot in job with blank job to fill with a miner at a later date
                assignVote(currentJob, currentJobId, currentJobIndex);
            }
        }
        crbTokenTaken = crbTokenTaken.mul(percentPenTokensToFee) / 100; //calculate what is added to fee
        currentJob.crbTokensArbitrationFee += crbTokenTaken;
    }
    /**
     * @dev  selected miners from the mining pool to become Arbitors
     * 
     *  -functionhash- unknown yet
     * @param currentJob The arbitration job we are selecting miners for
     * @param arbId The arbitration job id that corrasponds to the arbitration job we passed in
     */
    function selectArbitersFromMiners (ArbitrationJob storage currentJob, uint256 arbId) 
        internal
    {
        
        uint256  [] memory voteIds = currentJob.arbiterVoteIds;
        MinerTicketHolder [] memory curTickets = arbitersMining; //make copy in memory
        
        //for arbieters that haven't voted, make them not vote again for this job
        for (uint256 j = 0 ;j<voteIds.length; j++) {
            ArbiterVote memory checkVote = arbVotes[voteIds[j]];
            if (checkVote.state == VoteState.VOTE_COMPLETE) {
                uint256 lottoIndex = existingArbiters[checkVote.arbiterId].miningArrayIndex;
                curTickets[lottoIndex].numLottoTickets = 0; //take away mining tickets for existing arbiter
            }
        }
        
        for (uint256 i = 0 ;i<voteIds.length; i++) {
            ArbiterVote storage currentVote = arbVotes[voteIds[i]];
            if (currentVote.state == VoteState.PENALIZED_NO_VOTE || currentVote.state == VoteState.NOT_ASSIGNED_TO_ARBITER) {
                uint256 arbiterId = selectArbiter(curTickets);
                require (arbiterId >0, "can't be the dummy miner...");
                uint256 miningArrayIndex = existingArbiters[arbiterId].miningArrayIndex;
                curTickets[miningArrayIndex].numLottoTickets = 0; //take away mining tickets for existing arbiter
                
                if (currentVote.state == VoteState.PENALIZED_NO_VOTE) {
                    ArbiterVote memory addVote = ArbiterVote({
                        state:VoteState.PENDING_VOTE, 
                        arbitrationJobId:arbId, 
                        vote:0, 
                        arbiterId:arbiterId
                    });
                    uint256 voteIndex = arbVotes.push(addVote)-1;
                    //replace new vote with old bad vote
                    voteIds[i] = voteIndex;
                    //push vote id to miner so they know they got a job to do
                    existingArbiters[arbiterId].arbiterVoteIds.push(voteIndex);
                } else if (currentVote.state == VoteState.NOT_ASSIGNED_TO_ARBITER) { //assgin to arbiter if not assigned yet
                    currentVote.state = VoteState.PENDING_VOTE;
                    currentVote.arbiterId = arbiterId;
                    //push vote id to miner so they know they got a job to do
                    existingArbiters[arbiterId].arbiterVoteIds.push(voteIds[i]);
                }
            
                
            }
        }
        
        currentJob.arbiterVoteIds = voteIds; //save new voter ids.  optimization so we don't read a ton of times from storage
    }
    /**
     * @dev needed to pay triggermen for doing any triggers
     * 
     *  -functionhash- unknown yet
     * @param pathCompleted The path we took in our triggering
     * @param currentJob The arbitration job we helped by triggering an event
     */
    function payTriggerman (uint256 pathCompleted, ArbitrationJob storage currentJob) 
        internal
    {
        //triggerman always pays himself
        uint256 crbTokenPaymentForTrigger = triggermanPayCRBTokenAmount[pathCompleted];
        currentJob.crbTokensArbitrationFee = currentJob.crbTokensArbitrationFee.sub(crbTokenPaymentForTrigger);
        require(crbToken.transfer(msg.sender, crbTokenPaymentForTrigger), "error paying / transfering to triggerman");
    }
    /**
     * @dev figures out how much to pay everyone then pays them.
     * 
     *  -functionhash- unknown yet
     * @param currentJob The job we are refunding the host / guest from
     */
    function abideByFinalVoteOfArbs (ArbitrationJob memory currentJob, uint256 arbitraionJobId) 
        internal
    {
        
        uint256 totalPercent = 0;
        for (uint256 j=0; j < currentJob.arbiterVoteIds.length; j++) {
            ArbiterVote memory currentVote = arbVotes[currentJob.arbiterVoteIds[j]];
            totalPercent += percentDisputedChoices[currentVote.vote];
        }
        uint256 medianPercent = totalPercent / currentJob.arbiterVoteIds.length;

        uint256 crbTokenForHost = 
        currentJob.disputedAmountOfCRBTokens.mul(medianPercent)/100;
        require(crbToken.transfer(currentJob.host, crbTokenForHost), "err transfering to host");

        uint256 crbTokenForGuest = currentJob.disputedAmountOfCRBTokens.
        sub(crbTokenForHost);
        require(crbToken.transfer(currentJob.guest, crbTokenForGuest), "err transfering to guest");
        
        
        emit ArbCompleted(arbitraionJobId, medianPercent, currentJob.paymentId, now);

    }

    /**
     * @dev internal helper function to penalize arbiters for missing a vote
     *  -functionhash- unknown yet
     * @param voteId The id of the vote that didn't get completed by the end time
     */
    function penalizeArbiter(uint256 voteId)
        internal
        returns (uint256)
    {
        ArbiterVote storage currentVote = arbVotes[voteId];
        require (currentVote.state == VoteState.PENDING_VOTE, "arbiter not in pending vote state, can't penalize");
        Arbiter storage curMiner = existingArbiters[currentVote.arbiterId];

        uint256 crbTokenTaken = (curMiner.currentCRBTokenStake).mul(crbTokenPenality) / 100;
        uint256 salvagedCRBTokens = curMiner.currentCRBTokenStake.sub(crbTokenTaken);
        
        if (salvagedCRBTokens > 0) {
            require(crbToken.transfer(curMiner.minerAddress, salvagedCRBTokens), "err transfering crb from bad arbiter");//take crb tokens from Arbiter
        }
        
        emit ArbiterPenalized(currentVote.arbiterId, voteId, crbTokenTaken,curMiner.currentCRBTokenStake, now);
        
        currentVote.state = VoteState.PENALIZED_NO_VOTE;
        curMiner.currentCRBTokenStake = 0;

        removeMinerFromQueue(curMiner.miningArrayIndex); //remove miner from mining because they didn't do their job

        //select one more Arbiter
        return crbTokenTaken;
    }
    /**
     * @dev internal function that helps select one arbiter
     *  -functionhash- unknown yet
     * @param curTickets A memory copy of all miners modified to set tickets to 0 where we blacklisted.
     *      A miner can't be picked twice for the same job
     */
    function selectArbiter(MinerTicketHolder [] memory curTickets)
        internal
        returns (uint256) //returns arbiter id of winner
    {
        //get number of total tickets
        uint256 numTicketsOut = 0; 
        for (uint256 i=0; i < curTickets.length; i++) {
            numTicketsOut = numTicketsOut.add(curTickets[i].numLottoTickets);
        }
        require (numTicketsOut > 2, "needs to have at least 2 tickets avalible to init a vote");//needs to be at least 2 tickets avalible

        uint256 winningLottoTicket =  getRandomNumber(1, numTicketsOut);
        uint256 winningMinerIndex = 0;
        uint256 curLottoTicket = curTickets[winningMinerIndex].numLottoTickets;
        while(curLottoTicket < winningLottoTicket) {
            winningMinerIndex = winningMinerIndex.add(1); //winner not found, try next index
            curLottoTicket = curLottoTicket.add(curTickets[winningMinerIndex].numLottoTickets);
        }
        
        return curTickets[winningMinerIndex].miningId;
    }
    /**
     * @dev our random number generator, need to check how expensive it is to
     *   call, might just use less info to generate the random number.  stolen
     *   from fomo3d game, LOL, lots of stuff stolen from their open source.
     *   They got skillz for being one of the best teams, their code is solId
     *  -functionhash- unknown yet
     * @param min The min amount that we want
     * @param max The max amount that we want to go up to (non inclusive)
     */
    function getRandomNumber (uint256 min, uint256 max) 
        internal
        returns (uint256)
    {
        nonce = (nonce+1)%255;
        //this might overflow and cause thrown mining requests
        uint256 rawRand = uint256(keccak256(abi.encodePacked(
            (block.timestamp).add
            (block.difficulty).add
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
            (block.gaslimit).add
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)).add
            (block.number).add(nonce)
        )));
        
        return (rawRand%(max-min))+min;
    }


    /**
     * @dev registers a mininer, but puts them in a approval needed state 
     *   the contract owner needs to review all of the pending miners and 
     *   approve them
     *  -functionhash- unknown yet
     */
    function registerNewUser()
        internal
        returns (uint256)
    {
        
        uint256 minerId = existingArbiters.length;


        Arbiter memory curMiner = Arbiter({
            accessState:ArbiterAccessState.PENDING_APPROVAL,
            minerAddress:msg.sender,
            currentCRBTokenStake:0, 
            arbitrationsCompleted:0, 
            arbitrationsAppealed:0, 
            miningArrayIndex:0,
            arbiterVoteIds:new uint256[](0)
        });
        existingArbiters.push(curMiner);
        addressToMinerId[msg.sender] = minerId;

        return minerId;
    }
    



}




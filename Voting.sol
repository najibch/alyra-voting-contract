// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";

// Smart Contract implementing a voting system. The Administrator is the owner.
contract Voting is Ownable {

//Variables
    // mapping of authorized voters (could be changed to array if we need to really reset)
    mapping (address=>Voter) private voters;
    // list of proposals (using array to be able to reset)
    Proposal[] public proposals;
    // Status of the current vote initialized at RegisteringVoters
    WorkflowStatus public currentStatus;
    // winning proposal
    Proposal winner;

//Structures
    // Represent a voter 
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    // Represent a proposal
    struct Proposal {
        string description;
        uint voteCount;
    }   

//Enum
    // Vote status
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

//Events

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

//Modifiers

    //Modifier to execute function only by registered voters
    modifier onlyRegisteredVoter {
        require(voters[msg.sender].isRegistered, "Voter is not registered !");
        _;
    }

//Functions

    //Administrator can register new voters
    function register(address _address) external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Vote ongoing. Not registering new voters.");
        require(!voters[_address].isRegistered, "Voter already registered in the list.");
        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    //Administrator can start the proposal registration
    function startProposalRegistration() external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Proposal period should start after registering voters.");
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters,WorkflowStatus.ProposalsRegistrationStarted);
    }

    //Adding a new proposal only for registered voters
   function addProposal(string memory proposalDescription) external onlyRegisteredVoter {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposal period should start before adding proposals.");
        Proposal memory newProposal = Proposal(proposalDescription,0);
        proposals.push(newProposal);
        emit ProposalRegistered(proposals.length -1);
    }

    //Administrator can end the proposal registration
   function endProposalRegistration() external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposal period should be ongoing to end it.");
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted,WorkflowStatus.ProposalsRegistrationEnded);
    }

    //Administrator can start the voting session when we have at least 2 proposals (If not it's not really a vote :))
    function startVotingSession() external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "End Proposal Registration before starting a vote.");
        require(proposals.length >= 2 , "At least 2 proposals to start a vote. Please Reopen proposal registration session.");
        currentStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,WorkflowStatus.VotingSessionStarted);
    }

    //Administrator can start the proposal registration
   function endVotingSession() external onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Voting should be ongoing to end it.");
        currentStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,WorkflowStatus.VotingSessionEnded);
    }

    //Registered voters can vote for their prefered proposal using the ID (they can have the Ids of proposals by using getProposals())
    function vote(uint proposalId) external onlyRegisteredVoter {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Voting session should be started before voting.");
        require(!voters[msg.sender].hasVoted, "You have aldready voted !");
        require (proposalId < proposals.length , "ProposalId not valid.");
        proposals[proposalId].voteCount++;
        voters[msg.sender].votedProposalId = proposalId;
        voters[msg.sender].hasVoted = true;
        emit Voted(msg.sender, proposalId);
    }

    //Administrator can count the votes and finish the vote
    function voteCounting() external onlyOwner{
        require(currentStatus == WorkflowStatus.VotingSessionEnded, "Voting session should be ended before starting the counting.");
        uint topVoteCount=0;
        bool exaequo;
        for (uint i=0; i<proposals.length; i++) {
            if(proposals[i].voteCount > topVoteCount){
                winner = proposals[i];
                topVoteCount=proposals[i].voteCount;
                exaequo = false;
                continue;
            }
            if(proposals[i].voteCount == topVoteCount){      
                exaequo= true;
            }
        }
        // If no winner we set the winner at No Winner :)
        if(exaequo){
            winner=Proposal("No Winner !",0);
        }
        currentStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,WorkflowStatus.VotesTallied);
    }

    //Return the winning Proposal
    function getWinner() external view returns (Proposal memory)  {
        require(currentStatus == WorkflowStatus.VotesTallied, "Please wait for the counting to be over.");
        return winner;
    }

    //Return the list of proposals ( public getter needs an index)
    function getProposals() external view returns(Proposal [] memory ){
        return proposals;
    }

    //reset proposals and winner for next vote. To reset voters we need to change it to an Array.
    function reset() external onlyOwner{
        delete proposals;
        delete winner;
        currentStatus = WorkflowStatus.RegisteringVoters;
    }

}
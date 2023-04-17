pragma solidity ^0.8.4;

import "./administrable.sol";

/// @title A fractional DAO-like contract whose decisions can be voted upon by its shareholders
/// @author Frederik W. L. Christoffersen
/// @notice This contract is used as a votable administerable business entity.
/// @custom:beaware This is a commercial contract.
contract Votable is Administrable {

    /// @notice Struct representing info of a Referendum.
    /// @param allowDivision Boolean stating if Referendum allows for gradual implementation.
    /// @param proposalFunctionNames Names of functions to be called during implementation.
    /// @param proposalArgumentData The parameters passed to the function calls as part of the implementation of the proposals.
    struct ReferendumInfo {
        bool allowDivision;
        string[] proposalFunctionNames;
        bytes[] proposalArgumentData;
    }

    /// @notice Mapping pointing to dynamic info of a Referendum given a unique Referendum instance.
    mapping(uint256 => ReferendumInfo) infoByReferendum;

    /// @notice Mapping pointing to favor numerator of a given Referendum.
    mapping(uint256 => uint256) favorNumeratorByReferendum;
    /// @notice Mapping pointing to favor denominator of a given Referendum.
    mapping(uint256 => uint256) favorDenominatorByReferendum;

    /// @notice Mapping pointing to against numerator of a given Referendum.
    mapping(uint256 => uint256) againstNumeratorByReferendum;
    /// @notice Mapping pointing to against denominator of a given Referendum.
    mapping(uint256 => uint256) againstDenominatorByReferendum;

    /// @notice Mapping pointing to amount proposals implemented of a given Referendum.
    mapping(uint256 => uint8) amountImplementedByReferendum;

    /// @notice Mapping pointing to a boolean stating if the holder of a given Shard has voted on the given Referendum.
    mapping(uint256 => mapping(bytes32 => bool)) hasVotedOnReferendum;

    /// @notice Mapping pointing to a boolean stating if a given Referendum is pending.
    mapping(uint256 => bool) pendingReferendums;

    /// @notice Mapping pointing to a boolean stating if a given Referendum is to be implemented.
    mapping(uint256 => bool) passedReferendums;


    /// @notice Event that triggers when a Referendum is issued.
    /// @param referendum The now pending Referendum that was issued.
    /// @param by The issuer of the Referendum.
    event ReferendumIssued(
        uint256 referendum,
        address by
        );

    /// @notice Event that triggers when a Referendum is closed.
    /// @param referendum The passed Referendum that was closed.
    /// @param result The result of the now closed Referendum.
    event ReferendumClosed(
        uint256 referendum,
        bool result
        );

    /// @notice Event that triggers when a whole Referendum has been implemented.
    /// @param referendum The passed Referendum that was implemented.
    event ReferendumImplemented(
        uint256 referendum
        );
    
    /// @notice Event that triggers when a Proposal is implemented.
    /// @param proposalFunctionName The names of the functions to be called as a result of the implementation of the proposals.
    /// @param proposalArgumentData The parameters passed to the function calls as part of the implementation of the proposals.    /// @param referendum The passed Referendum from which the Proposal was implemented.
    /// @param by The initiator of the Proposal implementation.
    event ProposalImplemented(
      string proposalFunctionName,
      bytes proposalArgumentData,
      uint256 referendum,
      address by
      );

    /// @notice Event that triggers when a vote is cast on a Referendum.
    /// @param referendum The referendum that was voted on.
    /// @param favor The boolean value signalling a FOR or AGAINST vote.
    /// @param by The voter.
    event VoteCast(
        uint256 referendum,
        bool favor,
        address by
        );

    /// @notice Modifier that makes sure msg.sender has NOT voted on a specific referendum.
    /// @param referendum The Referendum to be checked for.
    modifier hasNotVoted(uint256 referendum) {
        require(!hasVoted(referendum, msg.sender));
        _;

    }

    /// @notice Modifier that makes sure a given Referendum is pending.
    /// @param referendum The Referendum to be checked for.
    modifier onlyPendingReferendum(uint256 referendum) {
        require(referendumIsPending(referendum), "RNP");
        _;
    }

    /// @notice Modifier that makes sure a given Referendum is passed.
    /// @param referendum The Referendum to be checked for.
    modifier onlyPassedReferendum(uint256 referendum) {
        require(referendumIsPassed(referendum), "RNT");
        _;
    }

    /// @notice Modifier that makes sure a given Proposal exists within a given Referendum.
    /// @param referendum The Referendum to be checked for.
    /// @param proposalIndex The index of the proposal to be checked for.
    modifier onlyExistingProposal(uint256 referendum, uint8 proposalIndex) {
        require(proposalExists(referendum,proposalIndex), "PNE");
        _;
    }

    constructor() {
        _setPermit("iV",msg.sender,PermitState.administrator,address(this));
        _setPermit("iP",msg.sender,PermitState.administrator,address(this));
    }

    /// @notice Votes on a existing referendum, with a fraction corresponding to the shard of the holder.
    /// @param shard The Shard to vote with.
    /// @param referendum The referendum to be voted on.
    /// @param favor The boolean value signalling a FOR or AGAINST vote.
    function vote(bytes32 shard, uint256 referendum, bool favor) external onlyHolder(shard) onlyPendingReferendum(referendum) hasNotVoted(referendum) onlyIfActive {
        require(shardExisted(shard,referendum), "SNV");
        hasVotedOnReferendum[referendum][shard] = true;
        if (favor) {
            (uint256 numerator, uint256 denominator) = addFractions(favorNumeratorByReferendum[referendum],favorDenominatorByReferendum[referendum],infoByShard[shard].numerator,infoByShard[shard].denominator);
            (favorNumeratorByReferendum[referendum],favorDenominatorByReferendum[referendum]) = simplifyFraction(numerator, denominator);
        }
        else {
            (uint256 numerator, uint256 denominator) = addFractions(againstNumeratorByReferendum[referendum],againstDenominatorByReferendum[referendum],infoByShard[shard].numerator,infoByShard[shard].denominator);
            (againstNumeratorByReferendum[referendum],againstDenominatorByReferendum[referendum]) = simplifyFraction(numerator,denominator);
        }
        emit VoteCast(referendum, favor, msg.sender);
    }

    /// @notice The potential errors of the Proposals aren't checked for before implementation!!!
    /// @param proposalFunctionNames The names of the functions to be called as a result of the implementation of the proposals.
    /// @param proposalArgumentData The parameters passed to the function calls as part of the implementation of the proposals.
    /// @param allowDivision A boolean stating if the proposals of the Referendum are allowed to be incrementally executed.
    function issueVote(string[] memory proposalFunctionNames, bytes[] memory proposalArgumentData, bool allowDivision) external onlyWithPermit("iV") {
        _issueVote(proposalFunctionNames,proposalArgumentData,allowDivision,msg.sender);
    }

    /// @notice Implements a given Proposal, within a given passed Referendum.
    /// @param referendum The passed Referendum containing the Proposal.
    /// @param proposalIndex The index of the proposal to be implemented.
    function implementProposal(uint256 referendum, uint8 proposalIndex) external onlyWithPermit("iP") {
        _implementProposal(referendum,proposalIndex,msg.sender);
    }

    /// @notice Returns a boolean stating if a given permit is valid/exists or not.
    /// @param permitName The name of the permit to be checked for.
    function isValidPermit(string memory permitName) override public pure returns(bool) {
            bytes32 permitHash = keccak256(bytes(permitName));
            if (permitHash == keccak256(bytes("sNSHS"))) {
                return true;
            }
            if(permitHash == keccak256(bytes("mAT"))) {
                return true;
            }
            if (permitHash ==  keccak256(bytes("iV"))) {
                return true;
            }
            if (permitHash ==  keccak256(bytes("iD"))) {
                return true;
            }
            if (permitHash ==  keccak256(bytes("dD"))) {
                return true;
            }
            if (permitHash ==  keccak256(bytes("mB"))) {
                return true;
            }
            if (permitHash ==  keccak256(bytes("iP"))) {
                return true;
            }
            if (permitHash ==  keccak256(bytes("lE"))) {
                return true;
            }
            else {
                return false;
            }
    }

    /// @notice Returns a boolean stating if a given Shard Holder has voted on a given Referendum.
    /// @param referendum The Referendum to be checked for.
    /// @param account The address of the potential Shard Holder voter to be checked for.
    function hasVoted(uint256 referendum, address account) public view returns(bool) {
        return hasVotedOnReferendum[referendum][shardByOwner[account]];
    }

    /// @notice Returns a boolean stating if a given Referendum has been voted through (>=50% FAVOR) or not.
    /// @param referendum The Referendum to be checked for.
    function getReferendumResult(uint256 referendum) public view returns(bool) {
        // if forFraction is bigger than 50%, then the vote is FOR
        if ((favorNumeratorByReferendum[referendum] / favorDenominatorByReferendum[referendum]) * 2 > 1) {
            return true;
        }
        return false;
    }
    
    /// @notice Returns a boolean stating if a given Referendum is pending or not.
    /// @param referendum The Referendum to be checked for.
    function referendumIsPending(uint256 referendum) public view returns(bool) {
        return pendingReferendums[referendum] == true; 
    }

    /// @notice Returns a boolean stating if a given Referendum is passed or not.
    /// @param referendum The Referendum to be checked for.
    function referendumIsPassed(uint256 referendum) public view returns(bool) {
        return passedReferendums[referendum] == true; 
    }

    /// @notice Returns a boolean stating if a given Proposal exists within a given Referendum.
    /// @param referendum The Referendum to be checked for.
    /// @param proposalIndex The index of the proposal to be checked for.
    function proposalExists(uint256 referendum, uint8 proposalIndex) public view returns(bool) {
        return infoByReferendum[referendum].proposalFunctionNames.length > proposalIndex;
    }

    /// @notice The potential errors of the Proposals aren't checked for before implementation!!!
    /// @param proposalFunctionNames The names of the functions to be called as a result of the implementation of the proposals.
    /// @param proposalArgumentData The parameters passed to the function calls as part of the implementation of the proposals.
    /// @param allowDivision A boolean stating if the proposals of the Referendum are allowed to be incrementally executed.
    function _issueVote(string[] memory proposalFunctionNames, bytes[] memory proposalArgumentData, bool allowDivision, address by) internal onlyIfActive incrementClock {
        uint256 transferTime = clock;
        require(proposalFunctionNames.length == proposalArgumentData.length, "PCW");
        pendingReferendums[transferTime] = true;
        infoByReferendum[transferTime] = ReferendumInfo({
            allowDivision:allowDivision,
            proposalFunctionNames: proposalFunctionNames,
            proposalArgumentData: proposalArgumentData
            });
        favorDenominatorByReferendum[transferTime] = 1;
        againstDenominatorByReferendum[transferTime] = 1;
        emit ReferendumIssued(transferTime, by);
    }

    /// @notice Implements a given Proposal, within a given passed Referendum.
    /// @param referendum The passed Referendum containing the Proposal.
    /// @param proposalIndex The index of the proposal to be implemented.
    function _implementProposal(uint256 referendum, uint8 proposalIndex, address by) internal onlyIfActive {
        require(infoByReferendum[referendum].allowDivision, "GINA");
        require(amountImplementedByReferendum[referendum] == proposalIndex, "WPO");
        amountImplementedByReferendum[referendum] += 1;
        string memory proposalFunctionName = infoByReferendum[referendum].proposalFunctionNames[proposalIndex];
        bytes memory proposalArgumentData = infoByReferendum[referendum].proposalArgumentData[proposalIndex];
        bytes32 functionNameHash = keccak256(bytes(proposalFunctionName));
                    if (functionNameHash == keccak256(bytes("iV"))) {
                        (string[] memory proposalFunctionNames, bytes[] memory _proposalArgumentData, bool allowDivision) = abi.decode(proposalArgumentData, (string[], bytes[], bool));
                        _issueVote(proposalFunctionNames, _proposalArgumentData, allowDivision,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("sP"))) {
                        (string memory permitName, PermitState newState, address account) = abi.decode(proposalArgumentData, (string, PermitState,address));
                        _setPermit(permitName,account,newState,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("sBP"))) {
                        (string memory permitName, PermitState newState) = abi.decode(proposalArgumentData, (string, PermitState));
                        _setBasePermit(permitName,newState,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("sNSHS"))) {
                        (bool newState) = abi.decode(proposalArgumentData, (bool));
                        _setNonShardHolderState(newState,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("tT"))) {
                        (string memory fromBankName, address tokenAddress, uint256 value, address to) = abi.decode(proposalArgumentData, (string, address, uint256,address));
                        _transferTokenFromBank(fromBankName,tokenAddress,value,to,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("mT"))) {
                        (string memory fromBankName, string memory toBankName, address tokenAddress, uint256 value) = abi.decode(proposalArgumentData, (string, string, address, uint256));
                        _moveToken(fromBankName,toBankName,tokenAddress,value,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("iD"))) {
                        (string memory bankName, address tokenAddress, uint256 value) = abi.decode(proposalArgumentData, (string,address,uint256));
                        _issueDividend(bankName,tokenAddress,value,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("dD"))) {
                        (uint256 dividend) = abi.decode(proposalArgumentData, (uint256));
                        _dissolveDividend(dividend,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("cB"))) {
                        (string memory bankName, address bankAdmin) = abi.decode(proposalArgumentData, (string, address));
                        _createBank(bankName,bankAdmin,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("dB"))) {
                        (string memory bankName) = abi.decode(proposalArgumentData, (string));
                        _deleteBank(bankName,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("aBA"))) {
                        (string memory bankName, address bankAdmin) = abi.decode(proposalArgumentData, (string, address));
                        _addBankAdmin(bankName,bankAdmin,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("rBA"))) {
                        (string memory bankName, address bankAdmin) = abi.decode(proposalArgumentData, (string, address));
                        _removeBankAdmin(bankName,bankAdmin,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("rTA"))) {
                        (address tokenAddress) = abi.decode(proposalArgumentData, (address));
                        _registerTokenAddress(tokenAddress,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("urTA"))) {
                        (address tokenAddress) = abi.decode(proposalArgumentData, (address));
                        _unregisterTokenAddress(tokenAddress,address(this));
                    }
                    if (functionNameHash == keccak256(bytes("l"))) {
                        _liquidize(address(this));
                    }
        emit ProposalImplemented(proposalFunctionName, proposalArgumentData, referendum, by);
        if (amountImplementedByReferendum[referendum] == infoByReferendum[referendum].proposalFunctionNames.length) {
            emit ReferendumImplemented(referendum);
        }
    }


    /// @notice Closes a given Referendum, leading to a pass or not.
    /// @param referendum The Referendum to be closed.
    function _closeReferendum(uint256 referendum) internal onlyPendingReferendum(referendum) onlyIfActive {
        bool result = getReferendumResult(referendum);
        // remove the now closed Referendum from 'pendingReferendums'
        pendingReferendums[referendum] = false;
        if (result) { // if it got voted through
            passedReferendums[referendum] = true;
        }
        emit ReferendumClosed(referendum, result);
    }

}
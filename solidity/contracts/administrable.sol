// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.4;

import "./idea.sol";

/// @title An extension of the Idea providing an administrable interface.
/// @author Frederik W. L. Christoffersen
/// @notice This contract adds administrability via permits and internally closed money supplies.
contract Administrable is Idea {

    /// @notice An enum representing a Permit State of one of the many permits.
    /// @param unauthorized The permit is NOT authorized.
    /// @param authorized The permit is authorized.
    /// @param administrator The holder of the permit is not only authorized but also an administrator of it too.
    enum PermitState {
        unauthorized,
        authorized,
        administrator
    }

    /// @notice A struct representing the information of a Dividend given to all current Shard holders.
    /// @param tokenAddress The address of the token, in which the value of the Dividend is issued.
    /// @param value The original value/amount of the Dividend before claims.
    struct DividendInfo {
        address tokenAddress;
        uint256 value;
    }
    
    /// @notice A mapping pointing to an unsigned integer representing the amount of stored kinds of tokens of a bank.
    mapping(string => uint256) storedTokenAddressesByBank;

    /// @notice A mapping pointing to an unsigned integer representing the amount of admins of a bank.
    mapping(string => uint256) adminsByBank;

    /// @notice A mapping pointing to the a value/amount of a stored token of a Bank, given the name of it and the respective token address.
    mapping(string => mapping(address => uint256)) balanceByBank;

     /// @notice A mapping pointing to a boolean stating if an address is an if a given address is a valid Bank administrator that has restricted control of the Bank's funds.
    mapping(string => mapping(address => bool)) adminOfBank;

    /// @notice A mapping pointing to another mapping, pointing to a Permit State, given the address of a permit holder, given the name of the permit.
    /// @custom:illustration permits[permitName][address] == PermitState.authorized || PermitState.administrator;
    mapping(string => mapping(address => PermitState)) permits;

    /// @notice A mapping pointing to the info of a Dividend given the creation clock of the Dividend.
    mapping(uint256 => DividendInfo) infoByDividend;

    /// @notice A mapping pointing to the residual of a Dividend given the creation clock of the Dividend.
    mapping(uint256 => uint256) residualByDividend;

    /// @notice Mapping pointing to a boolean stating if the owner of a Shard has claimed their fair share of the Dividend, given the bank name and the shard.
    mapping(uint256 => mapping(bytes32  => bool)) hasActionCompleted;

    /// @notice Event that triggers when an action is taken by somebody.
    /// @param func The name of the function that was called.
    /// @param args The arguments passed to the function call.
    /// @param by The initiator of the action.
    event ActionTaken(
        string func,
        bytes args,
        address by
        );

    /// @notice Event that triggers when part of a dividend is claimed.
    /// @param dividendClock The clock tied to the dividend.
    /// @param value The value claimed.
    /// @param by The claimant of the dividend.
    event DividendClaimed(
        uint256 dividendClock,
        uint256 value,
        address by
        );

    /// @notice Modifier that makes sure msg.sender has a given permit.
    /// @param permitName The name of the permit to be checked for.
    modifier onlyWithPermit(string memory permitName) {
        require(hasPermit(permitName, msg.sender));
        _;
    }
    
    /// @notice Modifier that makes sure msg.sender is an admin of a given permit.
    /// @param permitName The name of the permit to be checked for.
    modifier onlyPermitAdmin(string memory permitName) {
        require(isPermitAdmin(permitName, msg.sender));
        _;
    }

    /// @notice Modifier that makes sure msg.sender is admin of a given bank.
    /// @param bankName The name of the Bank to be checked for.
    modifier onlyBankAdmin(string memory bankName) {
        require(isBankAdmin(bankName, msg.sender));
        _;
    }

    /// @notice Modifier that makes sure a given bank exists
    /// @param bankName The name of the Bank to be checked for.
    modifier onlyExistingBank(string memory bankName) {
        require(bankExists(bankName), "DNE");
        _;
    }
    
    /// @notice Modifier that makes sure a given dividend exists and is valid
    /// @param dividend The Dividend to be checked for.
    modifier onlyExistingDividend(uint256 dividend) {
        require(dividendExists(dividend));
        _;
    }

    /// @notice Constructor function connecting the Idea entity and creating a Bank with an administrator.
    constructor(uint256 amount) Idea(amount) {
        _createBank("",msg.sender);
        _setPermit("iS", msg.sender, PermitState.administrator);
        _setPermit("mD", msg.sender, PermitState.administrator);
        _setPermit("mB", msg.sender, PermitState.administrator);
        _setPermit("lE", msg.sender, PermitState.administrator);
        _setPermit("mAT", msg.sender, PermitState.administrator);
    }

    /// @notice Receive function that receives ether when there's no supplying data
    receive() external payable {
        _processTokenReceipt(address(0),msg.value,"");
    }

    /// @notice Receives Ether and adds it to the registry.
    /// @param bankName The name of the Bank where the ether is to be received.
    function receiveEther(string memory bankName) external payable {
        _processTokenReceipt(address(0),msg.value,bankName);
    }

    /// @notice Receives a specified token and adds it to the registry. Make sure 'token.approve()' is called beforehand.
    /// @param tokenAddress The address of the token to be received.
    /// @param value The value/amount of the token to be received.
    function receiveToken(address tokenAddress, uint256 value) external {
        _receiveToken(tokenAddress,value);
    }

    /// @notice Claims the owed liquid value corresponding to the shard holder's respective shard fraction after the entity has been liquidized/dissolved.
    /// @param tokenAddress The address of the token to be claimed.
    function claimLiquid(address tokenAddress) external onlyShardHolder {
        require(active == false, "SA");
        bytes32 shard = shardByOwner[msg.sender];
        require(!hasClaimedLiquid[tokenAddress][shard], "AC");
        hasClaimedLiquid[tokenAddress][shard] = true;
        uint256 liquidValue = liquid[tokenAddress] * infoByShard[shard].amount / totalShardAmountByClock[clock];
        require(liquidValue != 0, "E");
        liquidResidual[tokenAddress] -= liquidValue;
        _transferFunds(tokenAddress,liquidValue,msg.sender);
    }

    /// @notice Claims the value of an existing dividend corresponding to the shard holder's respective shard fraction.
    /// @param shard The shard that was valid at the clock of the Dividend creation
    /// @param dividend The dividend to be claimed.
    function claimDividend(bytes32 shard, uint256 dividend) external onlyHolder(shard) onlyIfActive {
        require(shardExisted(shard,dividend), "NAF");
        require(hasActionCompleted[dividend][shard] == false, "AC");
        hasActionCompleted[dividend][shard] = true;
        uint256 dividendValue = infoByDividend[dividend].value * infoByShard[shard].amount / totalShardAmountByClock[clock];
        require(dividendValue != 0, "DTS");
        residualByDividend[dividend] -= dividendValue;
        _transferFunds(msg.sender,infoByDividend[dividend].tokenAddress,dividendValue);
        emit DividendClaimed(dividend,dividendValue,msg.sender);
    }

    /// @notice Registers a token as either acceptable or unacceptable. Approves or denies any future receipts of said token unless set to other status.
    /// @param tokenAddress The token address whose status is to be set.
    /// @param status The status to be set.
    function setTokenStatus(address tokenAddress, bool status) external onlyWithPermit("sTS") onlyIfActive {
        _setTokenStatus(tokenAddress,status);
    }

    /// @notice Issues new shards and puts them for sale.
    /// @param tokenAddress The token address the shards are put for sale for.
    /// @param price The price per token.
    /// @param to The specifically set buyer of the issued shards. Open to anyone, if address(0).
    function issueShards(uint256 amount, address tokenAddress, uint256 price, address to) external onlyWithPermit("iS") {
        _issueShards(amount,tokenAddress,price,to);
    }

    /// @notice Creates and issues a Dividend (to all current shareholders) of a token amount from a given Bank.
    /// @param bankName The name of the Bank to issue the Dividend from.
    /// @param tokenAddress The address of the token to make up the Dividend.
    /// @param value The value/amount of the token to be issued in the Dividend.
    function issueDividend(string calldata bankName, address tokenAddress, uint256 value) external onlyWithPermit("mD") onlyBankAdmin(bankName) {
        _issueDividend(bankName,tokenAddress,value);  
    }

    /// @notice Dissolves a Dividend and moves its last contents to the '' Bank.
    /// @param dividend The Dividend to be dissolved.
    function dissolveDividend(uint256 dividend) external onlyWithPermit("mD") {
        _dissolveDividend(dividend);
    }

    /// @notice Creates a new Bank.
    /// @param name The name of the Bank to be created.
    /// @param admin The address of the initial bank admin.
    function createBank(string calldata name, address admin) external onlyWithPermit("mB") onlyIfActive {
       _createBank(name,admin);
    }

        /// @notice Sets the admin status within a specific Bank of a given account.
    /// @param bankName The name of the Bank from which the given account's admin status is to be set.
    /// @param admin The address of the account, whose admin status it to be set.
    /// @param status The admin status to be set.
    function setBankAdminStatus(string calldata bankName, address admin, bool status) internal onlyIfActive {
        _setBankAdminStatus(bankName,status,admin);
    }

    /// @notice Transfers a token bankAdmin a Bank to a recipient.
    /// @param bankName The name of the Bank from which the funds are to be transferred.
    /// @param tokenAddress The address of the token to be transferred - address(0) if ether
    /// @param value The value/amount of the funds to be transferred.
    /// @param to The recipient of the funds to be transferred.
    function transferFundsFromBank(string calldata bankName, address to, address tokenAddress, uint256 amount) external onlyBankAdmin(bankName) {
        _transferFundsFromBank(fromBankName,tokenAddress,value,to,toBankName);
    }

    /// @notice Internally moves funds from one Bank to another.
    /// @param fromBankName The name of the Bank from which the funds are to be moved.
    /// @param toBankName The name of the Bank to which the funds are to be moved.
    /// @param tokenAddress The address of the token to be moved - address(0) if ether
    /// @param amount The value/amount of the funds to be moved.
    function moveFunds(string calldata fromBankName, string calldata toBankName, address tokenAddress, uint256 amount) external onlyBankAdmin(fromBankName) {
        _moveFunds(fromBankName,toBankName,tokenAddress,amount);
    }

    /// @notice Sets the state of a specified permit of a given address.
    /// @param account The address, whose permit state is to be set.
    /// @param permitName The name of the permit, whose state is to be set.
    /// @param newState The new Permit State to be applied.
    function setPermit(string calldata permitName, address account, PermitState newState) external onlyPermitAdmin(permitName) {
        _setPermit(permitName,account,newState);
    }

    /// @notice Calls a function of an external contract.
    /// @param externalAddress The address of the external contract, whose function is to be called. 
    /// @param signature The signature of the function to be called.
    /// @param encodedArgs The encoded arguments to be passed as parameters in the function call.
    /// @param value The value to be sent through the function call.
    /// @param gas The maximum amount of gas to be spent on the function call.
    function callExternalAddress(
        address externalAddress,
        string calldata signature,
        bytes calldata encodedArgs,
        uint256 value) onlyPermitAdmin("mB") {_callExternalAddress(externalAddress,signature,encodedArgs,value);}

    /// @notice Liquidizes and dissolves the entity. This cannot be undone.
    function liquidize() external onlyWithPermit("lE") {
        _liquidize();
    }

    /// @notice Returns the balance of a bank.
    /// @param bankName The name of the Bank.
    /// @param tokenAddress The address of the token balance to check for.
    function getBankBalance(string calldata bankName, address tokenAddress) public view returns(uint256) {
        return balanceByBank[bankName][tokenAddress];
    }
    
    /// @notice Returns the token of a dividend.
    /// @param dividend The Dividend to be checked for.
    function getDividendToken(uint256 dividend) public view returns(address) {
        return infoByDividend[dividend].tokenAddress;
    }
    
    /// @notice Returns the total value of a dividend.
    /// @param dividend The Dividend to be checked for.
    function getDividendValue(uint256 dividend) public view returns(uint256) {
        return infoByDividend[dividend].value;
    }

    /// @notice Returns the residual value of a dividend.
    /// @param dividend The Dividend to be checked for.
    function getDividendResidual(uint256 dividend) public view returns(uint256) {
        return residualByDividend[dividend];
    }

    /// @notice Returns a boolean stating if a given Bank exists.
    /// @param bankName The name of the Bank to be checked for.
    function bankExists(string memory bankName) public view returns(bool) {
        return adminsByBank[bankName] != 0;
    }

    /// @notice Returns a boolean stating if a given Bank is empty.
    /// @param bankName The name of the Bank to be checked for.
    function bankIsEmpty(string memory bankName) public view returns(bool) {
        return storedTokenAddressesByBank[bankName] == 0 && balanceByBank[bankName][address(0)] == 0;
    }
    
    /// @notice Returns a boolean stating if a given Dividend exists.
    /// @param dividend The Dividend to be checked for.
    function dividendExists(uint256 dividend) public view returns(bool) {
      return residualByDividend[dividend] > 0;
    }

    /// @notice Returns a boolean stating if a given address is an admin of a given bank.
    /// @param account The address to be checked for.
    /// @param bankName The name of the Bank to be checked for.
    function isBankAdmin(string memory bankName, address account) public view returns(bool) {
        return adminOfBank[bankName][account] == true || isPermitAdmin("mB",account);
    }

    /// @notice Returns a boolean stating if a given address has a given permit or not.
    /// @param permitName The name of the permit to be checked for.
    /// @param account The address to be checked for.
    function hasPermit(string memory permitName, address account) public view returns(bool) {
        return permits[permitName][account] >= PermitState.authorized;
    }

    /// @notice Returns a boolean stating if a given address is an admin of a given permit or not.
    /// @param permitName The name of the permit to be checked for.
    /// @param account The address to be checked for.
    function isPermitAdmin(string memory permitName, address account) public view returns(bool) {
        return permits[permitName][account] == PermitState.administrator;
    }

    /// @notice Creates and issues a Dividend (to all current shareholders) of a token amount from a given Bank.
    /// @param bankName The name of the Bank to issue the Dividend from.
    /// @param tokenAddress The address of the token to make up the Dividend.
    /// @param value The value/amount of the token to be issued in the Dividend.
    function _issueDividend(string memory bankName, address tokenAddress, uint256 value) internal onlyIfActive onlyExistingBank(bankName) {
        require(value <= balanceByBank[bankName][tokenAddress], "IF");
        balanceByBank[bankName][tokenAddress] -= value;
        if (balanceByBank[bankName][tokenAddress] == 0 && tokenAddress != address(0)) {
            storedTokenAddressesByBank[bankName] -= 1;
        }
        infoByDividend[clock] = DividendInfo({
            tokenAddress:tokenAddress,
            value:value
        });
        residualByDividend[clock] = value;
        emit ActionTaken("iD",abi.encode(clock,bankName,tokenAddress,value),msg.sender);
    }

    /// @notice Dissolves a Dividend and moves its last contents to the '' Bank.
    /// @param dividend The Dividend to be dissolved.
    function _dissolveDividend(uint256 dividend) internal onlyIfActive {
        if (dividendExists(dividend)) {
            balanceByBank[""][infoByDividend[dividend].tokenAddress] += residualByDividend[dividend];
            residualByDividend[dividend] = 0; // -1 to distinguish between empty values;
            emit ActionTaken("dD",abi.encode(dividend),msg.sender);
        }
    }

    /// @notice Creates a new Bank.
    /// @param name The name of the Bank to be created.
    /// @param admin The address of the first Bank administrator.
    function _createBank(string memory name, address admin) internal onlyIfActive {
        if (!bankExists(name)) {
            adminOfBank[name][admin] = true;
            adminsByBank[name] = 1;
            emit ActionTaken("cB",abi.encode(name,admin),msg.sender);
        }
    }

    /// @notice Sets the admin status within a specific Bank of a given account.
    /// @param bankName The name of the Bank from which the given account's admin status is to be set.
    /// @param admin The address of the account, whose admin status it to be set.
    /// @param status The admin status to be set.
    function _setBankAdminStatus(string memory bankName, address admin, bool status) internal onlyIfActive {
        require(hasPermit("mB",admin),"NP");
        if (isBankAdmin(bankName,admin) != status) { // makes sure the status isn't already set
            if (!status && adminsByBank[bankName] == 1) {require(bankIsEmpty(bankName), "BE");} // can't remove last admin unless bank is empty
            adminOfBank[bankName][admin] = status;
            adminsByBank[bankName] += status ? 1 : -1;
            emit ActionTaken("sBA",abi.encode(bankName,bankAdmin,status),msg.sender);
        }
    }

    /// @notice Receives a specified token and adds it to the registry. Make sure 'token.approve()' is called beforehand.
    /// @param tokenAddress The address of the token to be received.
    /// @param value The value/amount of the token to be received.
    function _receiveToken(address tokenAddress, uint256 value) internal {
        require(tokenAddress != address(0));
        require(acceptsToken(tokenAddress),"UT");
        ERC20 token = ERC20(tokenAddress);
        require(token.transferFrom(msg.sender,address(this),value), "NT");
        _processTokenReceipt(tokenAddress,value);
    }

    /// @notice Calls a function of an external contract.
    /// @param externalAddress The address of the external contract, whose function is to be called. 
    /// @param signature The signature of the function to be called.
    /// @param encodedArgs The encoded arguments to be passed as parameters in the function call.
    /// @param value The value to be sent through the function call.
    function _callExternalAddress(
        address externalAddress,
        string memory signature,
        bytes memory encodedArgs,
        uint256 value) {
        
        // Encode the function arguments with the provided signature
        bytes memory data = abi.encodePacked(bytes4(keccak256(bytes(signature))), encodedArgs);

        // Call the external contract's function with specified value and gas
        (bool success, bytes memory returndata) = externalAddress.call{value: value}(data);

        // Require the external contract call to be successful
        require(success);

        // Require the bank's balance to be sufficient.
        require(balanceByBank[""][address(0)] >= value);

        // Update the bank's balance with any excess Ether sent.
        balanceByBank[""][address(0)] -= value;

        emit ActionTaken("cE",abi.encode(externalAddress,signature,encodedArgs,value));
    }

    /// @notice Transfers a token bankAdmin a Bank to a recipient.
    /// @param bankName The name of the Bank from which the funds are to be transferred.
    /// @param tokenAddress The address of the token to be transferred - address(0) if ether
    /// @param value The value/amount of the funds to be transferred.
    /// @param to The recipient of the funds to be transferred.
    function _transferFundsFromBank(string memory bankName, address to, address tokenAddress, uint256 amount) internal {
        require(balanceByBank[bankName][tokenAddress] >= amount, "IT");
        balanceByBank[bankName][tokenAddress] -= amount;
        _transferFunds(to,tokenAddress,amount);
        emit ActionTaken("tF",abi.encode(bankName,to,tokenAddress,amount));
    }

    /// @notice Internally moves funds from one Bank to another.
    /// @param fromBankName The name of the Bank from which the funds are to be moved.
    /// @param toBankName The name of the Bank to which the funds are to be moved.
    /// @param tokenAddress The address of the token to be moved - address(0) if ether
    /// @param amount The value/amount of the funds to be moved.
    function _moveFunds(string memory fromBankName, string memory toBankName, address tokenAddress, uint256 amount) internal onlyExistingBank(fromBankName) onlyExistingBank(toBankName) onlyIfActive {
        require(amount <= balanceByBank[fromBankName][tokenAddress], "IF");
        balanceByBank[fromBankName][tokenAddress] -= amount;
        if (tokenAddress != address(0)) {
            if (balanceByBank[fromBankName][tokenAddress] == 0) {
                storedTokenAddressesByBank[fromBankName] -= 1;

            }
            if (balanceByBank[toBankName][tokenAddress] == 0) {
                storedTokenAddressesByBank[toBankName] += 1;
            }
        }
        balanceByBank[toBankName][tokenAddress] += amount;
        emit ActionTaken("mF",abi.encode(fromBankName,toBankName,tokenAddress,amount),msg.sender);

    }

    /// @notice Sets the state of a specified permit of a given address.
    /// @param permitName The name of the permit, whose state is to be set.
    /// @param account The address, whose permit state is to be set.
    /// @param newState The new Permit State to be applied.
    function _setPermit(string memory permitName, address account, PermitState newState) internal onlyIfActive {
        if (permits[permitName][account] != newState) {
            permits[permitName][account] = newState;
            emit ActionTaken("sP",abi.encode(permitName,account,newState),msg.sender);
        }
    }

    /// @notice Issues new shards and puts them for sale.
    /// @param tokenAddress The token address the shards are put for sale for.
    /// @param price The price per token.
    /// @param to The specifically set buyer of the issued shards. Open to anyone, if address(0).
    function _issueShards(uint256 amount, address tokenAddress, uint256 price, address to) override internal {
        super._issueShards(amount,tokenAddress,price,to);
        emit ActionTaken("iS",abi.encode(amount,tokenAddress,price,to),msg.sender);
    }

    /// @notice Registers a token as either acceptable or unacceptable. Approves or denies any future receipts of said token unless set to other status.
    /// @param tokenAddress The token address whose status is to be set.
    /// @param status The status to be set.
    function _setTokenStatus(address tokenAddress, bool status) override internal {
        if (acceptsToken(tokenAddress) != status) {
            validTokenAddresses[tokenAddress] = status;
            emit ActionTaken("sTS",abi.encode(tokenAddress,bool),msg.sender);
        }
    }

    /// @notice Liquidizes and dissolves the entity. This cannot be undone.
    function _liquidize() override internal {
        super._liquidize();
        emit ActionTaken("lE","",msg.sender);
    }
    
    /// @notice Processes a token transfer and subtracts it from the token registry.
    /// @param fromBankName The name of the Bank where the token is to be transfered from.
    /// @param tokenAddress The address of the transferred token.
    /// @param value The value/amount of the transferred token.
    /// @param to The recipient of the token to be transferred.
    /// @param toBankName If the recipient is an Idea: The name of the Bank where the token is to be received.
    function _processTokenTransfer(string memory fromBankName, address tokenAddress, uint256 value, address to, string memory toBankName) internal onlyExistingBank(fromBankName) {
        liquid[tokenAddress] -= value;
        liquidResidual[tokenAddress] -= value;

        balanceByBank[fromBankName][tokenAddress] -= value;
        if (balanceByBank[fromBankName][tokenAddress] == 0 && tokenAddress != address(0)) {
            storedTokenAddressesByBank[fromBankName] -= 1;
        }
        emit ActionTaken("tT",abi.encode(fromBankName,tokenAddress,value,to,toBankName),msg.sender);
    }

    /// @notice Keeps track of a token receipt by adding it to the registry.
    /// @param tokenAddress The address of the received token.
    /// @param value The value/amount of the received token.
    function _processTokenReceipt(address tokenAddress,uint256 value) override internal onlyExistingBank(bankName) {
        liquid[tokenAddress] += value;
        liquidResidual[tokenAddress] += value;
        // Then: Bank logic
        if (balanceByBank[""][tokenAddress] == 0 && tokenAddress != address(0)) {
            storedTokenAddressesByBank[""] += 1;
        }
        balanceByBank[""][tokenAddress] += value;
        emit ActionTaken("rT",abi.encode(bankName,tokenAddress,value),msg.sender);

    }

    /// @notice Pays profit to the seller during a shard purchase. 
    /// @dev Is modified. Takes into account buying of issued shards.
    /// @param account The address of the seller.
    /// @param account The address of the token address.
    /// @param value The value to be sent to the seller as payment. 
    function _payProfitToSeller(address account, address tokenAddress, uint256 value) override internal {
        if (account == address(this)) { // if seller is this contract (msg.sender buys newly issued shards)
            if (tokenAddress == address(0)) {
                _processTokenReceipt(tokenAddress,value,"");
            }
            else {_receiveToken(tokenAddress,value,"");}
        }
        else {
            ERC20 token = ERC20(tokenAddress);
            require(token.transferFrom(msg.sender,account,value), "NT");
        }
        
    }

}
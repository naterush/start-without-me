contract Mortal {
    address owner;
    function Mortal() {
        owner = msg.sender;
    }
    modifier isOwner {
        if (msg.sender != owner)
        throw;
        _
    }
    function kill(address _to) isOwner {
        selfdestruct(_to);
    }
}

contract StartWithoutMe is Mortal {
    enum State { stWaitingForN, stPlaying, stClosed }
    State status;
    uint  startTime;
    string place;
    uint deposit;
    uint gracePeriod;
    uint playPeriod;
    uint maxTries;
    uint8 nChar;
    uint nPresent;
    uint totalDeposits;
    uint portion;
    mapping (address => uint) public deposits;
    mapping (address => uint) public nTries;
    mapping (address => uint) public commitment;
    mapping (address => bool) public present;

    modifier noDeposit() {
        if (deposits[msg.sender] != 0)
            throw;
        _
    }

    modifier hasDeposit() {
        if (deposits[msg.sender] == 0)
            throw;
        _
    }

    modifier noAmount() {
        if (msg.value > 0)
            throw;
        _
    }

    modifier isStatus(State check) {
        if (status != check)
            throw;
        _
    }

    modifier isPresent() {
        if (!present[msg.sender])
            throw;
        _
    }

    // Constructor
    function StartWithoutMe(uint _startTime, string _place, uint _deposit, uint _gracePeriod, uint _playPeriod, uint _maxTries) {
        startTime = _startTime;
        place = _place;
        deposit = _deposit;
        gracePeriod = _gracePeriod;
        playPeriod = _playPeriod;
        maxTries = _maxTries;
        nChar = uint8(-1);
        nPresent = 0;
        status = State.stWaitingForN;
    }

    // Users make the promise to come to meeting by makeing a deposit
    function i_promise_to_be_on_time() noDeposit() isStatus(State.stWaitingForN) {

        // wrong deposit amount?
        if (msg.value <= deposit)
            throw;

        deposits[msg.sender] = msg.value;
        totalDeposits += msg.value;
        evtDepositAccepted(msg.sender, msg.value);
    }

    // Users confirm they are present
    function i_am_here(string ch, string randomData) hasDeposit() noAmount() isStatus(State.stPlaying) {

        nTries[msg.sender] = nTries[msg.sender]+1;
        if (nTries[msg.sender] > maxTries)
            throw;
            
        commitment[msg.sender] = sha3(ch, randomData) returns (bytes32);
        
        evtCommittmentMade(msg.sender, commitment[msg.sender]);
    }

    // Meeting coordinator closes the game which releases the deposits and distributes the unclaimed deposits
    function closeAttendence() isStatus(State.stPlaying) noAmount() isOwner() {
        status = State.stClosed;
        portion = totalDeposits / nPresent;
    }

    // Each person present must call the retrieve function to the their portion.
    function retrieveMyReward(randomData) isStatus(State.stClosed) isPresent() {
        // Has the caller gotten their excess yet? We use present to notate
        // whether or not the user was there, and also whether or not they've
        // been paid out, thus the isPresent modifier above.
        
        if (compareCharAt(randomData, nChar))
        {
            // refund the users deposit
            uint amt2Send = deposits[msg.sender];
            deposits[msg.sender] = 0; // clear this out before send to avoid recursive exploit
            totalDeposits -= amt2Send;
            nPresent++;
            if (!msg.sender.send(amt2Send))
            {
                // No need to replace the above changes because of the throw
                evtDepositRefundFailed(msg.sender,amt2Send);
                throw;
            }
            present[msg.sender] = true;
            evtDepositRefunded(msg.sender,amt2Send);
            
            present[msg.sender] = false;
            if (!msg.sender.send(portion))
                throw;
            
            return;
        }
    
    // user sent wrong character
        evtFailedAttempt(msg.sender,ch);
    }

    // After two weeks, the owner may collect the remain balances of anyone
    // who has not retreived thier share. Possible feature add on. The owner could 
    // set an account that recieves the money at the end. For example, a charity,
    // or maybe the catering buisness, and then they are reimbursed.
    function finalClose() isStatus(State.stClosed) noAmount() isOwner() {
        // simply send the balance of the contract to the owner who may choose to
        // reimburse any remaining 'present' account (or not).
        kill(msg.sender);
    }

    // Coordinator sets the value of 'n'
    function setN(uint8 _n) isOwner noAmount {
        // to big?
        if (_n > 63)
            throw;

        // too early?
        if (now < (startTime + gracePeriod))
            throw;

        // too late?
        if (now > (startTime + gracePeriod + playPeriod))
            throw;

        // already set?
        if (nChar != uint8(-1))
            throw;

        nChar = _n;
        status = State.stPlaying;
    }

    function compareCharAt(string randomData, uint8 nChar) private returns (bool) {
    return commitment[msg.sender] == sha3(nChar, randomData);
    }

    event evtDepositAccepted(address addr, uint timeStamp);
    event evtCommittmentMade(address addr, uint commitment);
    event evtFailedAttempt(address addr, string ch);
    event evtDepositRefunded(address addr, uint amount);
    event evtDepositRefundFailed(address addr, uint amount);
}

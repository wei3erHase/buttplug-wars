pragma solidity >=0.8.4 <0.9.0;

contract ButtPlugWars {
    constructor() {
        // Keep3r.addJob(address(this))
        // kLP.approve(Keep3r, max_uint)
        // ticket = new ERC721
        // Sudoswap.deployPool(SALE, params, 5/9)
        // 5/9.approveAll(SudoPool)
    }

    enum TEAM {
        A,
        B
    }

    enum STATE {
        TICKET_SALE, // can buy tickets
        GAME_RUNNING, // set by the first addLiquidityToJob
        NEXT_TEAM, // round is over and next team should start theirs
        GAME_ENDED, // can unbondLiquidity &
        PRIZE_CEREMONY // can claim prize or honors
    }

    function buyTicket(uint256 _tokenId, TEAM _team) external payable {
        // assert state = TICKET_SALE || (GAME_RUNNING & match < 9)

        // assert msg.value between 0.05 and 1
        // 5/9.transferFrom(msg.sender, erc721)

        // shares[msg.sender] = msg.value * coeff (2 at match 1, 1 at match 8)
        // totalShares += shares
        // ticket.mint(supply + (_team) << 16, msg.sender)
    }

    function claimPrize(uint256 _tokenId) external {
        // assert state = GAME_ENDED
        // asert _tokenId is winner team
        // assert msg.sender = ticket.owner(_tokenId)

        // shares = shares[_tokenId]
        // claimedShares += shares
        // totalShares -= shares

        // prizeShares[msg.sender] += shares
        // totalPrizeShares += shares
        // ticket.burn(_tokenId)
    }

    function withdrawPrize(uint256 _tokenId) external {
        // assert state = PRIZE_CEREMONY
        // kLPshare = prizeShares[msg.sender] / totalPrizeShares * totalPrize
        // kLP.transfer(msg.sender, kLPshare)
    }

    function claimHonor(uint256 _tokenId) external {
        // assert state = PRIZE_CEREMONY
        // assert msg.sender = ticket.owner(_tokenId)
        // sales = Sudoswap.withdrawETH
        // totalSales += sales
        // shareCoefficient = shares[_tokenId] / totalShares
        // claimable = (shareCoefficient * totalSales) - claimed[_tokenId]
        // claimed[_tokenId] += claimable
        // transfer(msg.sender, claimable)
    }

    function returnTicket(uint256 _tokenId) external {
        // assert state = PRIZE_CEREMONY
        // assert msg.sender = ticket.owner(_tokenId)
        // claimHonor(_tokenId)
        // totalSales -= claimed[_tokenId]
        // totalShares -= shares[_tokenId]
        // ticket.burn(_tokenId)
        // 5/7.transfer(msg.sender, deposited[_tokenId])
    }

    /* Keep3r Management */

    function addLiquidityToJob() external {
        // assert state = GAME_RUNNING || TICKET_SALE
        // assert cooldown (3d) have passed

        // eth = balance(this)
        // kp3r = kp3r.balance(this)

        // eth -= (calc KP3Rs for ETH) / 2
        // kp3r += swap ETH for KP3Rs
        // mint kLPs

        // Keep3r.addLiquidityToJob(address(this), kLP, kLP.balance(this))
    }

    function unbondLiquidity() external {
        // assert state = GAME_ENDED
        // assert it's run only once

        // totalPrize = Keep3r.liquidityAmounts(address(this), kLP)
        // Keep3r.unbondLiquidityFromJob(address(this), kLP, totalPrize)
    }

    function withdrawLiquidity() external {
        // assert state = GAME_ENDED
        // reverts unless cooldown
        // Keep3r.withdrawLiquidityFromJob(address(this), kLP)
        // sets state to PRIZE_CEREMONY
        // set state = PRIZE_CEREMONY
    }

    modifier upkeep(address _keeper) {
        // assert Keep3r.isKeeper(_keeper)
        // assert 5/7.balanceOf(_keeper) >= matchNumber
        _;
        // Keep3r.worked(_keeper)
    }

    /* Game mechanics */

    function executeMove() external upkeep(msg.sender) {
        // _team = _readTeam(block.timestamp)
        // board = 5/9.board()

        /* try catch */
        // move = buttplug[_team].readMove(board)
        // depth = f(seed, _keeper, t(%4hrs))
        // newBoard = 5/9.mintMove(move, depth)
        /* if reverts, -1 point & NEXT_TEAM state */

        // seed = keccak(board);

        /* if checkmate */
        // if score[A] >= score[B] => matches[A]++
        // if score[B] >= score[A] => matches[B]++

        // sets state = NEXT_TEAM
        // matchNumber++

        // if matches[A] >= 5 (winner[A] = true) & state = GAME_ENDED
        // if matches[B] >= 5 (winner[B] = true) & state = GAME_ENDED
        /* else: no checkmate */
        // score[_team] += _calcScore(board,newBoard)
    }

    function _calcScore(uint256 _previousBoard, uint256 _newBoard) internal pure returns (int8 _score) {
        // counts w&b pieces on _previousBoard
        // counts w&b pieces on _newBoard
        // returns +1 if black eaten and no white eaten
        // returns -1 if no black eaten and white eaten
        // returns 0 otherwise
    }

    /* Vote mechanics */

    function voteButtPlug(address _buttPlug, uint256 _tokenId) external {
        // team = f(_tokenId)
        // prevButtPlug = previousVote[_tokenId]
        // weight[team][prevButtPlug] -= shares[_tokenId]
        // weight[team][buttplug] += shares[_tokenId]
        // prevButtPlug = _buttPlug
        // if weight > currentButPlug[team].weight
        // currentButPlug[team] = address
    }
}

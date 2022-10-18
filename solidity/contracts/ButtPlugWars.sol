pragma solidity >=0.8.4 <0.9.0;

import '../interfaces/IChess.sol';
import '../interfaces/IButtPlug.sol';
import '../interfaces/IKeep3r.sol';
import '../interfaces/IPairManager.sol';
import '../interfaces/ILSSVMPairFactory.sol';
import '../interfaces/ISwapRouter.sol';
import '../interfaces/IWeth9.sol';
import './ButtPlugTicket.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {ERC721} from 'isolmate/tokens/ERC721.sol';

contract ButtPlugWars {
    address constant KEEP3R = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;

    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address constant WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;

    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address constant FIVE_OUT_OF_NINE = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;
    uint256 constant CHECKMATE = 0x32562300110101000010010000000C0099999000BCDE0B000000001;

    address constant SUDOSWAP_FACTORY = address(0);

    address immutable TICKET_NFT;

    STATE public state = STATE.TICKET_SALE;
    GameState public gameState;

    mapping(TEAM => uint256) gameScore;
    mapping(TEAM => int256) matchScore;

    uint256 public canPlayNext;
    uint256 constant COOLDOWN = 30 minutes;

    struct GameState {
        uint256 matchNumber;
    }

    constructor() {
        IKeep3r(KEEP3R).addJob(address(this));

        IERC20(WETH_9).approve(SWAP_ROUTER, type(uint256).max);

        IERC20(KP3R_V1).approve(KP3R_LP, type(uint256).max);
        IERC20(WETH_9).approve(KP3R_LP, type(uint256).max);

        IPairManager(KP3R_LP).approve(KEEP3R, type(uint256).max);

        TICKET_NFT = address(new ButtPlugTicket());

        // address sudoPool = ILSSVMPairFactory(SUDOSWAP_FACTORY).createPairETH()
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

    error WrongValue();
    error WrongState();
    error WrongTeam();
    error WrongTicket();
    error WrongKeeper();
    error WrongTiming();
    error WrongMethod();

    mapping(uint256 => uint256) public bondedToken;
    mapping(uint256 => uint256) public ticketShares;
    uint256 public totalShares;

    /// @dev Allows the signer to purchase a NFT, bonding a 5/9 and paying ETH price
    function buyTicket(uint256 _tokenId, TEAM _team) external payable {
        if (state == STATE.GAME_ENDED || state == STATE.PRIZE_CEREMONY) revert WrongState();

        uint256 _value = msg.value;
        if (_value < 0.05 ether || _value > 1 ether) revert WrongValue();
        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(msg.sender, address(this), _tokenId);

        uint256 _ticketID = ButtPlugTicket(TICKET_NFT).mint(msg.sender, _team);
        bondedToken[_ticketID] = _tokenId;

        ticketShares[_ticketID] = _value * _shareCoefficient();
        totalShares += _value;
    }

    function _shareCoefficient() internal returns (uint256) {
        // coeff (2 at match 1, 1 at match 8)
        return 1;
    }

    mapping(address => uint256) public playerPrizeShares;
    uint256 totalPrizeShares;
    uint256 totalPrize;

    /// @dev Allows players (winner team) to burn their token in exchange for a share of the prize
    function claimPrize(uint256 _ticketID) external onlyTicketOwner(_ticketID) {
        if (state != STATE.GAME_ENDED) revert WrongState();

        TEAM _team = TEAM(_ticketID >> 59);
        if (gameScore[_team] < 5) revert WrongTeam();

        uint256 _shares = ticketShares[_ticketID];
        playerPrizeShares[msg.sender] += _shares;
        totalPrizeShares += _shares;

        delete ticketShares[_ticketID];
        totalShares -= _shares;

        ButtPlugTicket(TICKET_NFT).burn(_ticketID);
        uint256 _tokenId = bondedToken[_ticketID];
        // sudoswap add _tokenId as liquidity
    }

    /// @dev Allow players who claimed prize to withdraw their funds
    function withdrawPrize() external {
        if (state != STATE.PRIZE_CEREMONY) revert WrongState();

        uint256 _withdrawnPrize = playerPrizeShares[msg.sender] * totalPrize / totalPrizeShares;
        IPairManager(KP3R_LP).transfer(msg.sender, _withdrawnPrize);

        delete playerPrizeShares[msg.sender];
    }

    /// @dev Allows players (who didn't claim the prize) to withdraw ETH from the pool sales
    function claimHonor(uint256 _ticketID) external onlyTicketOwner(_ticketID) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongState();

        // sales = Sudoswap.withdrawETH
        // totalSales += sales
        // shareCoefficient = shares[_ticketID] / totalShares
        // claimable = (shareCoefficient * totalSales) - claimed[_tokenId]
        // claimed[_tokenId] += claimable
        // transfer(msg.sender, claimable)
    }

    mapping(uint256 => uint256) claimedSales;
    uint256 totalSales;

    /// @dev Allows players to return their ticket and get the bonded NFT withdrawn
    function returnTicket(uint256 _ticketID) external onlyTicketOwner(_ticketID) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongState();

        // claimHonor()
        totalSales -= claimedSales[_ticketID];
        totalShares -= ticketShares[_ticketID];

        ButtPlugTicket(TICKET_NFT).burn(_ticketID);

        uint256 _tokenId = bondedToken[_ticketID];
        IERC20(FIVE_OUT_OF_NINE).transfer(msg.sender, _tokenId);
    }

    /* Keep3r Management */

    uint256 public addLiquidityCooldown;

    /// @dev Open method, allows signer to swap ETH => KP3R, mints kLP and adds to job
    function addLiquidity() external {
        if (state == STATE.GAME_ENDED || state == STATE.PRIZE_CEREMONY) revert WrongState();

        if (block.timestamp < addLiquidityCooldown) revert WrongTiming();
        addLiquidityCooldown = block.timestamp + 3 days;

        uint256 _eth = address(this).balance;
        IWeth(WETH_9).deposit{value: _eth}();

        ISwapRouter.ExactInputSingleParams memory _params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WETH_9,
            tokenOut: KP3R_V1,
            fee: 10_000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _eth / 2,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        ISwapRouter(SWAP_ROUTER).exactInputSingle(_params);

        uint256 wethBalance = IERC20(WETH_9).balanceOf(address(this));
        uint256 kp3rBalance = IERC20(KP3R_V1).balanceOf(address(this));

        uint256 kLPBalance = IPairManager(KP3R_LP).mint(kp3rBalance, wethBalance, 0, 0, address(this));
        IKeep3r(KEEP3R).addLiquidityToJob(address(this), KP3R_LP, kLPBalance);
    }

    /// @dev Called at checkmate routine, if one of the teams has score == 5
    function unbondLiquidity() internal {
        totalPrize = IKeep3r(KEEP3R).liquidityAmount(address(this), KP3R_LP);
        IKeep3r(KEEP3R).unbondLiquidityFromJob(address(this), KP3R_LP, totalPrize);
        state = STATE.GAME_ENDED;
    }

    /// @dev Open method, allows signer (after unbonding) to withdraw kLPs
    function withdrawLiquidity() external {
        if (state != STATE.GAME_ENDED) revert WrongState();
        /// @dev Method reverts unless 2w cooldown since unbond tx
        IKeep3r(KEEP3R).withdrawLiquidityFromJob(address(this), KP3R_LP, address(this));
        state = STATE.PRIZE_CEREMONY;
    }

    modifier upkeep(address _keeper) {
        if (!IKeep3r(KEEP3R).isKeeper(_keeper) || IERC20(FIVE_OUT_OF_NINE).balanceOf(_keeper) < gameState.matchNumber) {
            revert WrongKeeper();
        }
        _;
        IKeep3r(KEEP3R).worked(_keeper);
    }

    /* Game mechanics */

    function executeMove() external upkeep(msg.sender) {
        TEAM _team = _getTeam();
        uint256 _board = IChess(FIVE_OUT_OF_NINE).board();

        try ButtPlugWars(this).playMove(_board, _team) {
            uint256 _newBoard = IChess(FIVE_OUT_OF_NINE).board();
            if (_newBoard == CHECKMATE) {
                if (matchScore[TEAM.A] >= matchScore[TEAM.B]) gameScore[TEAM.A]++;
                if (matchScore[TEAM.B] >= matchScore[TEAM.A]) gameScore[TEAM.B]++;
                ++gameState.matchNumber;
                canPlayNext = _getNextPeriod();
            } else {
                matchScore[_team] += _calcScore(_board, _newBoard);
                canPlayNext = block.timestamp + COOLDOWN;
            }
        } // if playMove() reverts, team gets -1 point and next team is to play
        catch {
            --matchScore[_team];
            canPlayNext = _getNextPeriod();
        }
    }

    uint256 constant PERIOD = 5 days;

    function playMove(uint256 _board, TEAM _team) external {
        if (msg.sender != address(this)) revert WrongMethod();

        address _buttPlug = buttPlug[_team];
        uint256 _move = IButtPlug(_buttPlug).readMove(_board);
        uint256 _depth = _calcDepth(_board, msg.sender);
        IChess(FIVE_OUT_OF_NINE).mintMove(_move, _depth);
    }

    function _getTeam() internal view returns (TEAM _team) {
        uint256 _timestamp = block.timestamp;
        _team = TEAM((_timestamp - (_timestamp % PERIOD)) % 2);
    }

    function _getNextPeriod() internal view returns (uint256 _nextPeriod) {
        uint256 _timestamp = block.timestamp;
        _nextPeriod = (_timestamp + PERIOD) - ((_timestamp + PERIOD) % PERIOD);
    }

    function _calcDepth(uint256 _salt, address _keeper) internal view returns (uint256 _depth) {}

    function _calcScore(uint256 _previousBoard, uint256 _newBoard) internal pure returns (int8 _score) {
        // counts w&b pieces on _previousBoard
        // counts w&b pieces on _newBoard
        // returns +1 if black eaten and no white eaten
        // returns -1 if no black eaten and white eaten
        // returns 0 otherwise
    }

    /* Vote mechanics */

    mapping(address => uint256) buttPlugVotes;
    mapping(uint256 => uint256) ticketVoteWeight;
    mapping(uint256 => address) ticketVote;
    mapping(TEAM => address) buttPlug;

    /// @dev Allows players to vote for their preferred ButtPlug
    function voteButtPlug(address _buttPlug, uint256 _ticketID) external onlyTicketOwner(_ticketID) {
        if (_buttPlug == address(0)) revert WrongValue();

        TEAM _team = TEAM(_ticketID >> 59);
        uint256 _weight = ticketShares[_ticketID];

        address _previousVote = ticketVote[_ticketID];
        if (_previousVote != address(0)) buttPlugVotes[_previousVote] -= _weight;
        ticketVote[_ticketID] = _buttPlug;
        buttPlugVotes[_buttPlug] += _weight;

        if (buttPlugVotes[_buttPlug] > buttPlugVotes[buttPlug[_team]]) buttPlug[_team] = _buttPlug;
    }

    modifier onlyTicketOwner(uint256 _ticketID) {
        if (ButtPlugTicket(TICKET_NFT).ownerOf(_ticketID) != msg.sender) revert WrongTicket();
        _;
    }

    function onERC721Received(address operator, address from, uint256 id, bytes calldata data)
        external
        returns (bytes4)
    {
        return 0x150b7a02;
    }
}

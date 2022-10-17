pragma solidity >=0.8.4 <0.9.0;

import '../interfaces/IKeep3r.sol';
import '../interfaces/IPairManager.sol';
import '../interfaces/ILSSVMPairFactory.sol';
import '../interfaces/ISwapRouter.sol';
import '../interfaces/IWeth9.sol';
import './ButtPlugTicket.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {SafeTransferLib} from 'isolmate/utils/SafeTransferLib.sol';

contract ButtPlugWars {
    using SafeTransferLib for address payable;

    address constant KEEP3R = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;

    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address constant WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;

    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address constant FIVE_OUT_OF_NINE = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;

    address constant SUDOSWAP_FACTORY = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    address constant SUDOSWAP_BONDING_CURVE = 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0;

    address immutable TICKET_NFT;
    address immutable SUDOSWAP_POOL;

    STATE public state = STATE.TICKET_SALE;
    GameState public gameState;

    mapping(TEAM => uint256) gameScore;
    mapping(TEAM => uint256) matchScore;

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
        uint256[] memory _initialNFTIDs = new uint256[](0);

        // TODO: setup curve / delta
        SUDOSWAP_POOL = address(
            ILSSVMPairFactory(SUDOSWAP_FACTORY).createPairETH({
                _nft: IERC721(FIVE_OUT_OF_NINE),
                _bondingCurve: ICurve(SUDOSWAP_BONDING_CURVE),
                _assetRecipient: payable(address(this)),
                _poolType: LSSVMPair.PoolType.NFT,
                _delta: 0,
                _fee: 0,
                _spotPrice: 0,
                _initialNFTIDs: _initialNFTIDs
            })
        );
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
    error WrongNFT();
    error WrongTicket();
    error WrongKeeper();
    error WrongTiming();

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

        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _ticketID);
    }

    /// @dev Allow players who claimed prize to withdraw their funds
    function withdrawPrize() external {
        if (state != STATE.PRIZE_CEREMONY) revert WrongState();

        uint256 _withdrawnPrize = playerPrizeShares[msg.sender] * totalPrize / totalPrizeShares;
        IPairManager(KP3R_LP).transfer(msg.sender, _withdrawnPrize);

        delete playerPrizeShares[msg.sender];
    }

    uint256 constant BASE = 1 ether;
    mapping(uint256 => uint256) claimed;

    /// @dev Allows players (who didn't claim the prize) to withdraw ETH from the pool sales
    function claimHonor(uint256 _ticketID) external onlyTicketOwner(_ticketID) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongState();
        _claimHonor(_ticketID);
    }

    function _claimHonor(uint256 _ticketID) internal {
        uint256 _sales = address(this).balance;
        LSSVMPairETH(SUDOSWAP_POOL).withdrawAllETH();
        _sales = address(this).balance - _sales;

        totalSales += _sales;

        uint256 shareCoefficient = BASE * ticketShares[_ticketID] / totalShares;
        uint256 _claimable = (shareCoefficient * totalSales / BASE) - claimed[_ticketID];
        claimed[_ticketID] += _claimable;

        payable(msg.sender).safeTransferETH(_claimable);
    }

    mapping(uint256 => uint256) claimedSales;
    uint256 totalSales;

    /// @dev Allows players to return their ticket and get the bonded NFT withdrawn
    function returnTicket(uint256 _ticketID) external onlyTicketOwner(_ticketID) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongState();

        _claimHonor(_ticketID);
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

    function onERC721Received(address, address _from, uint256 _id, bytes calldata) external returns (bytes4) {
        if (msg.sender != FIVE_OUT_OF_NINE) revert WrongNFT();
        // if token is newly minted transfer to sudoswap pool
        if (_from == address(0)) ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _id);
        return 0x150b7a02;
    }
}

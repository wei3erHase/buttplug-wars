// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IButtPlug, IChess} from 'interfaces/Game.sol';
import {IKeep3r, IPairManager} from 'interfaces/Keep3r.sol';
import {LSSVMPair, LSSVMPairETH, ILSSVMPairFactory, ICurve, IERC721} from 'interfaces/Sudoswap.sol';
import {ISwapRouter} from 'interfaces/Uniswap.sol';
import {IERC20, IWeth} from 'interfaces/ERC20.sol';

import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {SafeTransferLib} from 'isolmate/utils/SafeTransferLib.sol';

contract ButtPlugWars is ERC721 {
    using SafeTransferLib for address payable;

    /* Address registry */
    address constant THE_RABBIT = 0xC5233C3b46C83ADEE1039D340094173f0f7c1EcF;
    address constant FIVE_OUT_OF_NINE = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;

    address constant WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address constant KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;

    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant KEEP3R = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;
    address constant SUDOSWAP_FACTORY = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    address constant SUDOSWAP_EXPONENTIAL_CURVE = 0x432f962D8209781da23fB37b6B59ee15dE7d9841;
    address public immutable SUDOSWAP_POOL;

    /* IERC721 */
    address public immutable owner;
    uint256 public totalSupply;

    /* Game mechanics */

    enum TEAM {
        A,
        B
    }

    enum STATE {
        TICKET_SALE, // can buy badges
        GAME_RUNNING, // set by the first pushLiquidityToJob
        GAME_ENDED, // can unbondLiquidity
        PREPARATIONS, // waits until liquidity is unbonded
        PRIZE_CEREMONY // can claim prize or honors
    }

    uint256 constant BASE = 1 ether;
    uint256 constant PERIOD = 5 days;
    uint256 constant COOLDOWN = 30 minutes;
    uint256 constant LIQUIDITY_COOLDOWN = 3 days;
    uint256 constant CHECKMATE = 0x3256230011111100000000000000000099999900BCDECB000000001;

    mapping(TEAM => uint256) public gameScore;
    mapping(TEAM => int256) public matchScore;
    uint256 public matchNumber;
    uint256 public canPlayNext;
    uint256 public canPushLiquidity;

    STATE public state = STATE.TICKET_SALE;

    /* Badge mechanics */
    uint256 public totalShares;
    mapping(uint256 => uint256) public badgeShares;
    mapping(uint256 => uint256) public bondedToken;

    /* Vote mechanics */
    mapping(TEAM => address) buttPlug;
    mapping(address => uint256) buttPlugVotes;
    mapping(uint256 => address) badgeVote;
    mapping(uint256 => uint256) badgeVoteWeight;

    /* Prize mechanics */
    uint256 totalPrize;
    uint256 totalPrizeShares;
    mapping(address => uint256) public playerPrizeShares;

    uint256 claimableSales;
    mapping(uint256 => uint256) claimedSales;

    constructor() ERC721('ButtPlugBadge', unicode'♙') {
        // emit token aprovals
        IERC20(WETH_9).approve(SWAP_ROUTER, type(uint256).max);
        IERC20(KP3R_V1).approve(KP3R_LP, type(uint256).max);
        IERC20(WETH_9).approve(KP3R_LP, type(uint256).max);
        IPairManager(KP3R_LP).approve(KEEP3R, type(uint256).max);

        // create Keep3r job
        IKeep3r(KEEP3R).addJob(address(this));
        canPushLiquidity = block.timestamp + 14 days;

        // create Sudoswap pool
        SUDOSWAP_POOL = address(
            ILSSVMPairFactory(SUDOSWAP_FACTORY).createPairETH({
                _nft: IERC721(FIVE_OUT_OF_NINE),
                _bondingCurve: ICurve(SUDOSWAP_EXPONENTIAL_CURVE),
                _assetRecipient: payable(address(this)),
                _poolType: LSSVMPair.PoolType.NFT,
                _spotPrice: 590000000000000000, // 0.059 ETH
                _delta: 1059000000000000000, // 5.9 %
                _fee: 0,
                _initialNFTIDs: new uint256[](0)
            })
        );

        // set the owner of the ERC721 for royalties
        owner = THE_RABBIT;
    }

    error WrongValue();
    error WrongTeam();
    error WrongNFT();
    error WrongBadge();
    error WrongKeeper();
    error WrongTiming();
    error WrongMethod();

    /* Badge Management */

    /// @dev Allows the signer to purchase a NFT, bonding a 5/9 and paying ETH price
    function buyBadge(uint256 _tokenId, TEAM _team) external payable returns (uint256 _badgeID) {
        if (state >= STATE.GAME_ENDED) revert WrongTiming();

        uint256 _value = msg.value;
        if (_value < 0.05 ether || _value > 1 ether) revert WrongValue();
        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(msg.sender, address(this), _tokenId);

        _badgeID = _mint(msg.sender, _team);
        bondedToken[_badgeID] = _tokenId;

        badgeShares[_badgeID] = (_value * _shareCoefficient()) / BASE;
        totalShares += _value;
    }

    function _shareCoefficient() internal returns (uint256) {
        return 2 * BASE - (BASE * matchNumber / 8);
    }

    /// @dev Allows players (winner team) to burn their token in exchange for a share of the prize
    function claimPrize(uint256 _badgeID) external onlyBadgeOwner(_badgeID) {
        if (state != STATE.PREPARATIONS) revert WrongTiming();

        TEAM _team = TEAM(_badgeID >> 59);
        if (gameScore[_team] < 5) revert WrongTeam();

        uint256 _shares = badgeShares[_badgeID];
        playerPrizeShares[msg.sender] += _shares;
        totalPrizeShares += _shares;

        delete badgeShares[_badgeID];
        totalShares -= _shares;

        _burn(_badgeID);
        uint256 _tokenId = bondedToken[_badgeID];

        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _tokenId);
    }

    /// @dev Allow players who claimed prize to withdraw their funds
    function withdrawPrize() external {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();

        uint256 _withdrawnPrize = playerPrizeShares[msg.sender] * totalPrize / totalPrizeShares;
        IPairManager(KP3R_LP).transfer(msg.sender, _withdrawnPrize);

        delete playerPrizeShares[msg.sender];
    }

    /// @dev Allows players (who didn't claim the prize) to withdraw ETH from the pool sales
    function claimHonor(uint256 _badgeID) external onlyBadgeOwner(_badgeID) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();
        _claimHonor(_badgeID);
    }

    function _claimHonor(uint256 _badgeID) internal {
        uint256 _sales = address(this).balance;
        LSSVMPairETH(SUDOSWAP_POOL).withdrawAllETH();
        _sales = address(this).balance - _sales;

        claimableSales += _sales;

        uint256 shareCoefficient = BASE * badgeShares[_badgeID] / totalShares;
        uint256 _claimable = (shareCoefficient * claimableSales / BASE) - claimedSales[_badgeID];
        claimedSales[_badgeID] += _claimable;

        payable(msg.sender).safeTransferETH(_claimable);
    }

    /// @dev Allows players to return their badge and get the bonded NFT withdrawn
    function returnBadge(uint256 _badgeID) external onlyBadgeOwner(_badgeID) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();

        _claimHonor(_badgeID);
        claimableSales -= claimedSales[_badgeID];
        totalShares -= badgeShares[_badgeID];

        _burn(_badgeID);

        uint256 _tokenId = bondedToken[_badgeID];
        IERC20(FIVE_OUT_OF_NINE).transfer(msg.sender, _tokenId);
    }

    modifier onlyBadgeOwner(uint256 _badgeID) {
        if (ownerOf[_badgeID] != msg.sender) revert WrongBadge();
        _;
    }

    /* Keep3r Management */

    /// @dev Open method, allows signer to swap ETH => KP3R, mints kLP and adds to job
    function pushLiquidity() external {
        if (state >= STATE.GAME_ENDED) revert WrongTiming();
        if (state == STATE.TICKET_SALE) _initializeGame();

        if (block.timestamp < canPushLiquidity) revert WrongTiming();
        canPushLiquidity = block.timestamp + LIQUIDITY_COOLDOWN;

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

    function _initializeGame() internal {
        state = STATE.GAME_RUNNING;
        ++matchNumber;
    }

    /// @dev Called at checkmate routine, if one of the teams has score == 5
    function unbondLiquidity() external {
        if (state != STATE.GAME_ENDED) revert WrongTiming();
        totalPrize = IKeep3r(KEEP3R).liquidityAmount(address(this), KP3R_LP);
        IKeep3r(KEEP3R).unbondLiquidityFromJob(address(this), KP3R_LP, totalPrize);
        state = STATE.PREPARATIONS;
    }

    /// @dev Open method, allows signer (after unbonding) to withdraw kLPs
    function withdrawLiquidity() external {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        /// @dev Method reverts unless 2w cooldown since unbond tx
        IKeep3r(KEEP3R).withdrawLiquidityFromJob(address(this), KP3R_LP, address(this));
        state = STATE.PRIZE_CEREMONY;
    }

    /// @dev Handles Keep3r mechanism and payment
    modifier upkeep(address _keeper) {
        if (!IKeep3r(KEEP3R).isKeeper(_keeper) || IERC20(FIVE_OUT_OF_NINE).balanceOf(_keeper) < matchNumber) {
            revert WrongKeeper();
        }
        _;
        IKeep3r(KEEP3R).worked(_keeper);
    }

    /* Game mechanics */

    function executeMove() external upkeep(msg.sender) {
        if ((state != STATE.GAME_RUNNING) || (block.timestamp < canPlayNext)) revert WrongTiming();

        TEAM _team = _getTeam();
        uint256 _board = IChess(FIVE_OUT_OF_NINE).board();

        bool _success;
        try ButtPlugWars(this).playMove(_board, _team) {
            _success = true;
        } catch {}

        if (_success) {
            uint256 _newBoard = IChess(FIVE_OUT_OF_NINE).board();
            if (_newBoard == CHECKMATE) {
                if (matchScore[TEAM.A] >= matchScore[TEAM.B]) gameScore[TEAM.A]++;
                if (matchScore[TEAM.B] >= matchScore[TEAM.A]) gameScore[TEAM.B]++;
                ++matchNumber;
                if (matchNumber >= 5) _verifyWinner();
                canPlayNext = _getRoundTimestamp(block.timestamp + PERIOD, PERIOD);
            } else {
                matchScore[_team] += _calcScore(_board, _newBoard);
                canPlayNext = block.timestamp + COOLDOWN;
            }
        } else {
            // if playMove() reverts, team gets -1 point and next team is to play
            --matchScore[_team];
            canPlayNext = _getRoundTimestamp(block.timestamp + PERIOD, PERIOD);
        }
    }

    function _verifyWinner() internal {
        if ((gameScore[TEAM.A] >= 5) || gameScore[TEAM.B] >= 5) state = STATE.GAME_ENDED;
    }

    function playMove(uint256 _board, TEAM _team) external {
        if (msg.sender != address(this)) revert WrongMethod();

        address _buttPlug = buttPlug[_team];
        uint256 _move = IButtPlug(_buttPlug).readMove(_board);
        uint256 _depth = _calcDepth(_board, msg.sender);
        IChess(FIVE_OUT_OF_NINE).mintMove(_move, _depth);
    }

    function _getRoundTimestamp(uint256 _timestamp, uint256 _period) internal view returns (uint256 _roundTimestamp) {
        _roundTimestamp = _timestamp - (_timestamp % _period);
    }

    function _getTeam() internal view returns (TEAM _team) {
        uint256 _timestamp = block.timestamp;
        _team = TEAM((_getRoundTimestamp(_timestamp, PERIOD) % PERIOD) % 2);
    }

    function _calcDepth(uint256 _salt, address _keeper) internal view returns (uint256 _depth) {
        uint256 _timeVariable = _getRoundTimestamp(block.timestamp, COOLDOWN);
        _depth = 3 + uint256(keccak256(abi.encode(_salt, _keeper, _timeVariable))) % 8;
    }

    function _calcScore(uint256 _previousBoard, uint256 _newBoard) internal pure returns (int8 _score) {
        // counts w&b pieces on _previousBoard
        // counts w&b pieces on _newBoard
        // returns +1 if black eaten and no white eaten
        // returns -1 if no black eaten and white eaten
        // returns 0 otherwise
    }

    /* Vote mechanics */

    /// @dev Allows players to vote for their preferred ButtPlug
    function voteButtPlug(address _buttPlug, uint256 _badgeID) external onlyBadgeOwner(_badgeID) {
        if (_buttPlug == address(0)) revert WrongValue();

        TEAM _team = TEAM(_badgeID >> 59);
        uint256 _weight = badgeShares[_badgeID];

        address _previousVote = badgeVote[_badgeID];
        if (_previousVote != address(0)) buttPlugVotes[_previousVote] -= _weight;
        badgeVote[_badgeID] = _buttPlug;
        buttPlugVotes[_buttPlug] += _weight;

        if (buttPlugVotes[_buttPlug] > buttPlugVotes[buttPlug[_team]]) buttPlug[_team] = _buttPlug;
    }

    function _mint(address _receiver, ButtPlugWars.TEAM _team) internal returns (uint256 _badgeID) {
        _badgeID = ++totalSupply;
        _badgeID += uint256(_team) << 59;
        _mint(_receiver, _badgeID);
    }

    function _burn(uint256 _badgeID) internal override {
        totalSupply--;
        super._burn(_badgeID);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {}

    function onERC721Received(address, address _from, uint256 _id, bytes calldata) external returns (bytes4) {
        if (msg.sender != FIVE_OUT_OF_NINE) revert WrongNFT();
        // if token is newly minted transfer to sudoswap pool
        if (_from == address(0)) ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _id);
        return 0x150b7a02;
    }
}

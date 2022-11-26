// SPDX-License-Identifier: MIT

/*

  by             .__________                 ___ ___
  __  _  __ ____ |__\_____  \  ___________  /   |   \_____    ______ ____
  \ \/ \/ // __ \|  | _(__  <_/ __ \_  __ \/    ~    \__  \  /  ___// __ \
   \     /\  ___/|  |/       \  ___/|  | \/\    Y    // __ \_\___ \\  ___/
    \/\_/  \___  >__/______  /\___  >__|    \___|_  /(____  /____  >\___  >
               \/          \/     \/              \/      \/     \/     \/*/

pragma solidity >=0.8.4 <0.9.0;

import {IButtPlug, IChess, IDescriptorPlug} from 'interfaces/Game.sol';
import {IKeep3r, IPairManager} from 'interfaces/Keep3r.sol';
import {LSSVMPair, LSSVMPairETH, ILSSVMPairFactory, ICurve, IERC721} from 'interfaces/Sudoswap.sol';
import {ISwapRouter} from 'interfaces/Uniswap.sol';
import {IERC20, IWeth} from 'interfaces/ERC20.sol';

import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {SafeTransferLib} from 'isolmate/utils/SafeTransferLib.sol';
import {Math} from 'openzeppelin/utils/math/Math.sol';

/// @notice Contract will not be audited, proceed at your own risk
/// @dev THE_RABBIT will not be responsible for any loss of funds
contract ButtPlugWars is ERC721 {
    using SafeTransferLib for address payable;
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                            ADDRESS REGISTRY
    //////////////////////////////////////////////////////////////*/

    address constant THE_RABBIT = 0x5dD028D0832739008c5308490e6522ce04342E10;
    address constant FIVE_OUT_OF_NINE = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;

    address constant WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address constant KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;

    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant KEEP3R = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;
    address constant SUDOSWAP_FACTORY = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    address constant SUDOSWAP_XYK_CURVE = 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0;
    address public immutable SUDOSWAP_POOL;
    address public nftDescriptor;

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /* IERC721 */
    address public immutable owner;
    uint256 totalPlayers;

    /* Roadmap */
    enum STATE {
        ANNOUNCEMENT, // rabbit can cancel event
        TICKET_SALE, // can mint badges
        GAME_RUNNING, // game runs, can mint badges
        GAME_OVER, // game stops, can unbondLiquidity
        PREPARATIONS, // can claim prize, waits until kLPs are unbonded
        PRIZE_CEREMONY, // can withdraw prize or honors
        CANCELLED // a critical bug was found
    }

    STATE state = STATE.ANNOUNCEMENT;

    uint256 canStartSales;
    uint256 canPlayNext;
    uint256 canPushLiquidity;
    uint256 canUpdateSpotPriceNext;

    /* Game mechanics */
    enum TEAM {
        ZERO,
        ONE,
        STAFF
    }

    uint256 constant MAX_UINT = type(uint256).max;
    uint256 constant PERIOD = 5 days;
    uint256 constant COOLDOWN = 30 minutes;
    uint256 constant LIQUIDITY_COOLDOWN = 3 days;
    uint256 constant CHECKMATE = 0x3256230011111100000000000000000099999900BCDECB000000001;
    /// @dev Magic number by @fiveOutOfNine
    uint256 constant MAGIC_NUMBER = 0xDB5D33CB1BADB2BAA99A59238A179D71B69959551349138D30B289;
    uint256 constant BUTT_PLUG_GAS_LIMIT = 20_000_000;

    mapping(TEAM => uint256) matchesWon;
    mapping(TEAM => int256) matchScore;
    uint256 matchMoves;
    uint256 matchNumber;

    /* Badge mechanics */
    uint256 totalShares;
    mapping(uint256 => uint256) badgeShares;
    mapping(uint256 => uint256) bondedToken;

    /* NFT whitelisting mechanics */
    uint256 genesis;
    mapping(uint256 => bool) whitelistedToken;

    /* Vote mechanics */
    mapping(TEAM => address) buttPlug;
    mapping(TEAM => mapping(address => uint256)) buttPlugVotes;
    mapping(uint256 => int256) score;
    mapping(uint256 => mapping(uint256 => int256)) lastUpdatedScore;
    mapping(uint256 => address) badgeButtPlugVote;

    /* Prize mechanics */
    uint256 totalPrize;
    uint256 totalPrizeShares;
    mapping(address => uint256) playerPrizeShares;

    uint256 claimableSales;
    mapping(address => uint256) claimedSales;
    mapping(address => uint256) playerHonorShares;
    uint256 totalHonorShares;

    error WrongValue(); // badge minting value should be between 0.05 and 1
    error WrongTeam(); // only winners can claim the prize
    error WrongNFT(); // an unknown NFT was sent to the contract
    error WrongBadge(); // only the badge owner can access
    error WrongKeeper(); // keeper doesn't fulfill the required params
    error WrongTiming(); // method called at wrong roadmap state or cooldown
    error WrongMethod(); // method should not be externally called

    /*///////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    constructor() ERC721('ButtPlugBadge', unicode'♙') {
        // emit token aprovals
        IERC20(WETH_9).approve(SWAP_ROUTER, MAX_UINT);
        IERC20(KP3R_V1).approve(KP3R_LP, MAX_UINT);
        IERC20(WETH_9).approve(KP3R_LP, MAX_UINT);
        IPairManager(KP3R_LP).approve(KEEP3R, MAX_UINT);

        // create Keep3r job
        IKeep3r(KEEP3R).addJob(address(this));

        // create Sudoswap pool
        SUDOSWAP_POOL = address(
            ILSSVMPairFactory(SUDOSWAP_FACTORY).createPairETH({
                _nft: IERC721(FIVE_OUT_OF_NINE),
                _bondingCurve: ICurve(SUDOSWAP_XYK_CURVE),
                _assetRecipient: payable(address(this)),
                _poolType: LSSVMPair.PoolType.NFT,
                _spotPrice: 59000000000000000, // 0.059 ETH
                _delta: 1,
                _fee: 0,
                _initialNFTIDs: new uint256[](0)
            })
        );

        // set the owner of the ERC721 for royalties
        owner = THE_RABBIT;
        canStartSales = block.timestamp + 2 * PERIOD;

        // mint scoreboard token to itself
        _mint(address(this), 0);
        genesis = IERC20(FIVE_OUT_OF_NINE).totalSupply();
    }

    /// @dev Permissioned method, allows rabbit to cancel the event
    function cancelEvent() external onlyRabbit {
        if (state != STATE.ANNOUNCEMENT) revert WrongTiming();

        state = STATE.CANCELLED;
    }

    /// @dev Permissioned method, allows rabbit to change the nftDescriptor address
    function setNftDescriptor(address _nftDescriptor) external onlyRabbit {
        nftDescriptor = _nftDescriptor;
    }

    modifier onlyRabbit() {
        if (msg.sender != THE_RABBIT) revert WrongMethod();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            BADGE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows the signer to mint a Player NFT, bonding a 5/9 and paying ETH price
    function mintPlayerBadge(uint256 _tokenId, TEAM _team) external payable returns (uint256 _badgeId) {
        if ((state < STATE.TICKET_SALE) || (state >= STATE.GAME_OVER)) revert WrongTiming();
        _validateFiveOutOfNine(_tokenId);

        uint256 _value = msg.value;
        if (_value < 0.05 ether || _value > 1 ether) revert WrongValue();
        uint256 _shares = _value.sqrt();

        _badgeId = ++totalPlayers + (uint256(_team) << 59);
        _mint(msg.sender, _badgeId);

        bondedToken[_badgeId] = _tokenId;
        badgeShares[_badgeId] = _shares;
        totalShares += _shares;

        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    /// @dev Allows the signer to register a ButtPlug NFT
    function mintButtPlugBadge(address _buttPlug) external returns (uint256 _badgeId) {
        if ((state < STATE.TICKET_SALE) || (state >= STATE.GAME_OVER)) revert WrongTiming();

        _badgeId = _calculateButtPlugBadge(_buttPlug, TEAM.STAFF);
        _mint(_buttPlug, _badgeId);
    }

    /// @dev Open method, allows anyone to mint a buttPlug's score badge to its owner
    function mintButtPlugScoreBadge(address _buttPlug, TEAM _team) external returns (uint256 _badgeId) {
        if ((state < STATE.TICKET_SALE) || (state >= STATE.GAME_OVER)) revert WrongTiming();
        address _owner = IButtPlug(_buttPlug).owner();
        _badgeId = _calculateButtPlugBadge(_buttPlug, _team);
        _mint(_owner, _badgeId);
    }

    /// @dev Allows players (winner team) claim a share of the prize acording to their value sent
    function claimPrize(uint256 _badgeId) external onlyBadgeOwner(_badgeId) {
        if (state != STATE.PREPARATIONS) revert WrongTiming();

        TEAM _team = _getTeam(_badgeId);
        if (matchesWon[_team] < 5) revert WrongTeam();

        int256 _badgeScore = _getScore(_badgeId);
        bool _isPositive = _badgeScore > 0;
        uint256 _shares = _isPositive ? uint256(_badgeScore) : badgeShares[_badgeId];

        playerPrizeShares[msg.sender] += _shares;
        totalPrizeShares += _shares;

        super.transferFrom(msg.sender, address(this), _badgeId);
        _returnNftIfStaked(_badgeId);
    }

    /// @dev Allow players who claimed prize to withdraw their funds
    function withdrawPrize() external {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();

        uint256 _withdrawnPrize = playerPrizeShares[msg.sender] * totalPrize / totalPrizeShares;
        delete playerPrizeShares[msg.sender];

        IPairManager(KP3R_LP).transfer(msg.sender, _withdrawnPrize);
    }

    /// @dev Allows badge owners to claim ETH from the pool sales according to their score
    function claimHonor(uint256 _badgeId) external onlyBadgeOwner(_badgeId) {
        if (state != STATE.PREPARATIONS) revert WrongTiming();

        uint256 _shares = badgeShares[_badgeId];
        playerHonorShares[msg.sender] += _shares;
        totalHonorShares += _shares;

        super.transferFrom(msg.sender, address(this), _badgeId);
        _returnNftIfStaked(_badgeId);
    }

    /// @dev Allows players to withdraw their correspondant ETH from the pool sales
    function withdrawHonor() external {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();

        uint256 _claimableShares = claimableSales.mulDiv(playerHonorShares[msg.sender], totalHonorShares);
        uint256 _claimable = _claimableShares - claimedSales[msg.sender];
        claimedSales[msg.sender] += _claimable;

        payable(msg.sender).safeTransferETH(_claimable);
    }

    function _returnNftIfStaked(uint256 _badgeId) internal {
        if (_badgeId < 1 << 60) {
            uint256 _tokenId = bondedToken[_badgeId];
            ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), msg.sender, _tokenId);
        }
    }

    function _getTeam(uint256 _badgeId) internal pure returns (TEAM _team) {
        return TEAM(uint8(_badgeId >> 59));
    }

    modifier onlyBadgeOwner(uint256 _badgeId) {
        if (ownerOf[_badgeId] != msg.sender) revert WrongBadge();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            ROADMAP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Open method, allows signer to start ticket sale
    function startEvent() external {
        uint256 _timestamp = block.timestamp;
        if ((state != STATE.ANNOUNCEMENT) || (_timestamp < canStartSales)) revert WrongTiming();

        canPushLiquidity = _timestamp + 2 * PERIOD;
        state = STATE.TICKET_SALE;
    }

    /// @dev Open method, allows signer to swap ETH => KP3R, mints kLP and adds to job
    function pushLiquidity() external {
        if (state >= STATE.GAME_OVER) revert WrongTiming();
        if (state == STATE.TICKET_SALE) {
            state = STATE.GAME_RUNNING;
            ++matchNumber;
        }

        if (block.timestamp < canPushLiquidity) revert WrongTiming();
        canPushLiquidity = block.timestamp + LIQUIDITY_COOLDOWN;

        uint256 _eth = address(this).balance - claimableSales;
        if (_eth < 0.05 ether) revert WrongTiming();

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
        totalPrize += kLPBalance;
        IKeep3r(KEEP3R).addLiquidityToJob(address(this), KP3R_LP, kLPBalance);
    }

    /// @dev Open method, allows signer (after game ended) to start unbond period
    function unbondLiquidity() external {
        if (state != STATE.GAME_OVER) revert WrongTiming();
        totalPrize = IKeep3r(KEEP3R).liquidityAmount(address(this), KP3R_LP);
        IKeep3r(KEEP3R).unbondLiquidityFromJob(address(this), KP3R_LP, totalPrize);
        state = STATE.PREPARATIONS;
    }

    /// @dev Open method, allows signer (after unbonding) to withdraw all staked kLPs
    function withdrawLiquidity() external {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        // Method reverts unless 2w cooldown since unbond tx
        IKeep3r(KEEP3R).withdrawLiquidityFromJob(address(this), KP3R_LP, address(this));
        state = STATE.PRIZE_CEREMONY;
    }

    /// @dev Open method, allows signer (after game is over) to reduce pool spotPrice
    function updateSpotPrice() external {
        uint256 _timestamp = block.timestamp;
        if (state <= STATE.GAME_OVER || _timestamp < canUpdateSpotPriceNext) revert WrongTiming();

        canUpdateSpotPriceNext = _timestamp + PERIOD;
        uint128 _spotPrice = LSSVMPair(SUDOSWAP_POOL).spotPrice();
        LSSVMPair(SUDOSWAP_POOL).changeSpotPrice(_spotPrice * 5 / 9);
    }

    /// @dev Handles Keep3r mechanism and payment
    modifier upkeep(address _keeper) {
        if (!IKeep3r(KEEP3R).isKeeper(_keeper) || IERC20(FIVE_OUT_OF_NINE).balanceOf(_keeper) < matchNumber) {
            revert WrongKeeper();
        }
        _;
        IKeep3r(KEEP3R).worked(_keeper);
    }

    /*///////////////////////////////////////////////////////////////
                            GAME MECHANICS
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by keepers to execute the next move
    function executeMove() external upkeep(msg.sender) {
        if ((state != STATE.GAME_RUNNING) || (block.timestamp < canPlayNext)) revert WrongTiming();

        // each match is limited to 59 moves
        if (++matchMoves > 59) _checkMateRoutine();

        TEAM _team = TEAM((_roundT(block.timestamp, PERIOD) / PERIOD) % 2);
        address _buttPlug = buttPlug[_team];

        if (_buttPlug == address(0)) {
            // if team does not have a buttplug, skip turn
            canPlayNext = _roundT(block.timestamp + PERIOD, PERIOD);
            return;
        }

        uint256 _buttPlugBadgeId = _calculateButtPlugBadge(_buttPlug, _team);
        uint256 _buttPlugVotes = buttPlugVotes[_team][_buttPlug];

        uint256 _board = IChess(FIVE_OUT_OF_NINE).board();

        int8 _score;
        bool _isCheckmate;
        // gameplay is wrapped in a try/catch block to punish reverts
        try ButtPlugWars(this).playMove{gas: BUTT_PLUG_GAS_LIMIT}(_board, _buttPlug) {
            uint256 _newBoard = IChess(FIVE_OUT_OF_NINE).board();
            _isCheckmate = _newBoard == CHECKMATE;
            if (_isCheckmate) {
                _score = 3;
                canPlayNext = _roundT(block.timestamp + PERIOD, PERIOD);
            } else {
                _score = _calcMoveScore(_board, _newBoard);
                canPlayNext = block.timestamp + COOLDOWN;
            }
        } catch {
            // if buttplug or move reverts
            _score = -2;
            canPlayNext = _roundT(block.timestamp + PERIOD, PERIOD);
        }

        matchScore[_team] += _score;
        score[_buttPlugBadgeId] += _score * int256(_buttPlugVotes);

        if (_isCheckmate) _checkMateRoutine();
    }

    /// @notice Externally called to try catch
    /// @dev Called with a gasLimit of BUTT_PLUG_GAS_LIMIT
    function playMove(uint256 _board, address _buttPlug) external {
        if (msg.sender != address(this)) revert WrongMethod();

        uint256 _move = IButtPlug(_buttPlug).readMove(_board);
        uint256 _depth = _calcDepth(_board, msg.sender);
        IChess(FIVE_OUT_OF_NINE).mintMove(_move, _depth);
    }

    function _checkMateRoutine() internal {
        if (matchScore[TEAM.ZERO] >= matchScore[TEAM.ONE]) matchesWon[TEAM.ZERO]++;
        if (matchScore[TEAM.ONE] >= matchScore[TEAM.ZERO]) matchesWon[TEAM.ONE]++;

        delete matchMoves;
        delete matchScore[TEAM.ZERO];
        delete matchScore[TEAM.ONE];

        // verifies if game has ended
        if ((matchesWon[TEAM.ZERO] == 5) || matchesWon[TEAM.ONE] == 5) {
            state = STATE.GAME_OVER;
            // all remaining ETH will be considered to distribute as sales
            claimableSales = address(this).balance;
            canPlayNext = MAX_UINT;
            return;
        }
    }

    function _roundT(uint256 _timestamp, uint256 _period) internal pure returns (uint256 _roundTimestamp) {
        _roundTimestamp = _timestamp - (_timestamp % _period);
    }

    function _calcDepth(uint256 _salt, address _keeper) internal view virtual returns (uint256 _depth) {
        uint256 _timeVariable = _roundT(block.timestamp, COOLDOWN);
        _depth = 3 + uint256(keccak256(abi.encode(_salt, _keeper, _timeVariable))) % 8;
    }

    /// @notice Adds +2 when eating a black piece, and substracts 1 when a white piece is eaten
    function _calcMoveScore(uint256 _previousBoard, uint256 _newBoard) internal pure returns (int8 _score) {
        (uint8 _whitePiecesBefore, uint8 _blackPiecesBefore) = _countPieces(_previousBoard);
        (uint8 _whitePiecesAfter, uint8 _blackPiecesAfter) = _countPieces(_newBoard);

        _score += 2 * int8(_blackPiecesBefore - _blackPiecesAfter);
        _score -= int8(_whitePiecesBefore - _whitePiecesAfter);
    }

    /// @dev Efficiently loops through the board uint256 to search for pieces and count each color
    function _countPieces(uint256 _board) internal pure returns (uint8 _whitePieces, uint8 _blackPieces) {
        uint256 _space;
        for (uint256 i = MAGIC_NUMBER; i != 0; i >>= 6) {
            _space = (_board >> ((i & 0x3F) << 2)) & 0xF;
            if (_space == 0) continue;
            _space >> 3 == 1 ? _whitePieces++ : _blackPieces++;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            VOTE MECHANICS
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows players to vote for their preferred ButtPlug
    function voteButtPlug(address _buttPlug, uint256 _badgeId) external onlyBadgeOwner(_badgeId) {
        if (_buttPlug == address(0)) revert WrongValue();
        if (_badgeId > 1 << 60) revert WrongMethod();

        TEAM _team = _getTeam(_badgeId);
        uint256 _weight = badgeShares[_badgeId];

        address _previousVote = badgeButtPlugVote[_badgeId];
        if (_previousVote != address(0)) {
            uint256 _previousButtPlugBadge = _calculateButtPlugBadge(_previousVote, _team);
            buttPlugVotes[_team][_previousVote] -= _weight;
            score[_badgeId] += score[_previousButtPlugBadge] - lastUpdatedScore[_badgeId][_previousButtPlugBadge];
        }

        uint256 _currentButtPlugBadge = _calculateButtPlugBadge(_buttPlug, _team);
        lastUpdatedScore[_badgeId][_currentButtPlugBadge] = score[_currentButtPlugBadge];
        badgeButtPlugVote[_badgeId] = _buttPlug;
        buttPlugVotes[_team][_buttPlug] += _weight;

        if (buttPlugVotes[_team][_buttPlug] > buttPlugVotes[_team][buttPlug[_team]]) buttPlug[_team] = _buttPlug;
    }

    function _getScore(uint256 _badgeId) internal view returns (int256 _score) {
        TEAM _team = _getTeam(_badgeId);
        uint256 _currentButtPlugBadge = _calculateButtPlugBadge(badgeButtPlugVote[_badgeId], _team);
        return score[_badgeId] + score[_currentButtPlugBadge] - lastUpdatedScore[_badgeId][_currentButtPlugBadge];
    }

    /*///////////////////////////////////////////////////////////////
                                ERC721
    //////////////////////////////////////////////////////////////*/

    function onERC721Received(address, address _from, uint256 _id, bytes calldata) external returns (bytes4) {
        if (msg.sender != FIVE_OUT_OF_NINE) revert WrongNFT();
        // if token is newly minted transfer to sudoswap pool
        if (_from == address(0)) {
            whitelistedToken[_id] = true;
            ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _id);
            _increaseSudoswapDelta();
        }

        return 0x150b7a02;
    }

    function _validateFiveOutOfNine(uint256 _id) internal {
        if (_id >= genesis && !whitelistedToken[_id]) revert WrongNFT();
    }

    function _increaseSudoswapDelta() internal {
        uint128 _currentDelta = LSSVMPair(SUDOSWAP_POOL).delta();
        LSSVMPair(SUDOSWAP_POOL).changeDelta(++_currentDelta);
    }

    function _calculateButtPlugBadge(address _buttPlug, TEAM _team) internal pure returns (uint256 _badgeId) {
        return uint256(uint160(_buttPlug)) << 69 + uint256(_team) << 59;
    }

    /// @dev Avoids transference of ButtPlug Badges
    function transferFrom(address _from, address _to, uint256 _badgeId) public virtual override {
        if (_getTeam(_badgeId) == TEAM.STAFF) revert WrongMethod();
        super.transferFrom(_from, _to, _badgeId);
    }

    function tokenURI(uint256 _badgeId) public view virtual override returns (string memory) {
        // Scoreboard metadata
        if (_badgeId == 0) {
            IDescriptorPlug.ScoreboardData memory _scoreboardData = IDescriptorPlug.ScoreboardData({
                state: uint8(state),
                matchNumber: matchNumber,
                matchMoves: matchMoves,
                matchesWonZERO: matchesWon[TEAM.ZERO],
                matchesWonONE: matchesWon[TEAM.ONE],
                matchScoreZERO: matchScore[TEAM.ZERO],
                matchScoreONE: matchScore[TEAM.ONE],
                buttPlugA: buttPlug[TEAM.ZERO],
                buttPlugB: buttPlug[TEAM.ONE]
            });

            return IDescriptorPlug(nftDescriptor).getScoreboardMetadata(_scoreboardData);
        }

        IDescriptorPlug.GameData memory _gameData =
            IDescriptorPlug.GameData({totalPlayers: totalPlayers, totalShares: totalShares, totalPrize: totalPrize});

        TEAM _team = _getTeam(_badgeId);

        IDescriptorPlug.BadgeData memory _badgeData =
            IDescriptorPlug.BadgeData({team: uint8(_team), badgeId: _badgeId, badgeShares: badgeShares[_badgeId]});

        // Player metadata
        if (_badgeId < 1 << 60) {
            IDescriptorPlug.PlayerData memory _playerData = IDescriptorPlug.PlayerData({
                score: _getScore(_badgeId),
                badgeButtPlugVote: badgeButtPlugVote[_badgeId],
                bondedToken: bondedToken[_badgeId]
            });

            return IDescriptorPlug(nftDescriptor).getPlayerBadgeMetadata(_gameData, _badgeData, _playerData);
        }

        // ButtPlug metadata
        if (_badgeId > 1 << 60) {
            address _buttPlug = address(uint160(_badgeId >> 69));
            uint256 _board = IChess(FIVE_OUT_OF_NINE).board();
            (uint256 _simMove, uint256 _simGasUsed) = _simulateButtPlug(_buttPlug, _board);

            IDescriptorPlug.ButtPlugData memory _buttPlugData = IDescriptorPlug.ButtPlugData({
                board: _board,
                simulatedMove: _simMove,
                simulatedGasSpent: _simGasUsed,
                buttPlugVotes: buttPlugVotes[_team][_buttPlug]
            });

            return IDescriptorPlug(nftDescriptor).getButtPlugBadgeMetadata(_gameData, _badgeData, _buttPlugData);
        }

        revert WrongNFT();
    }

    function _simulateButtPlug(address _buttPlug, uint256 _board)
        internal
        view
        returns (uint256 _simMove, uint256 _simGasUsed)
    {
        uint256 _gasLeft = gasleft();
        try IButtPlug(_buttPlug).readMove(_board) returns (uint256 _move) {
            _simMove = _move;
            _simGasUsed = _gasLeft - gasleft();
        } catch {
            _simGasUsed = _gasLeft - gasleft();
            return (0, _simGasUsed);
        }
    }

    /*///////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        if (msg.sender == SUDOSWAP_POOL) claimableSales += msg.value;
        return;
    }
}

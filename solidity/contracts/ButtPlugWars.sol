// SPDX-License-Identifier: MIT

/*

  by             .__________                 ___ ___
  __  _  __ ____ |__\_____  \  ___________  /   |   \_____    ______ ____
  \ \/ \/ // __ \|  | _(__  <_/ __ \_  __ \/    ~    \__  \  /  ___// __ \
   \     /\  ___/|  |/       \  ___/|  | \/\    Y    // __ \_\___ \\  ___/
    \/\_/  \___  >__/______  /\___  >__|    \___|_  /(____  /____  >\___  >
               \/          \/     \/              \/      \/     \/     \/*/

pragma solidity >=0.8.4 <0.9.0;

import {GameSchema} from './GameSchema.sol';
import {ERC721} from 'isolmate/tokens/ERC721.sol';

import {IButtPlug, IChess} from 'interfaces/IGame.sol';
import {IKeep3r, IPairManager} from 'interfaces/IKeep3r.sol';
import {LSSVMPair, LSSVMPairETH, ILSSVMPairFactory, ICurve, IERC721} from 'interfaces/ISudoswap.sol';
import {ISwapRouter} from 'interfaces/IUniswap.sol';
import {IERC20, IWeth} from 'interfaces/IERC20.sol';

import {SafeTransferLib} from 'isolmate/utils/SafeTransferLib.sol';
import {Math} from 'openzeppelin-contracts/utils/math/Math.sol';

/// @notice Contract will not be audited, proceed at your own risk
/// @dev THE_RABBIT will not be responsible for any loss of funds
contract ButtPlugWars is GameSchema, ERC721 {
    using SafeTransferLib for address payable;
    using Math for uint256;

    /**
     * TODO:
     * move every var to GameSchema (fix tests)
     * avoid re-submitting medals for kLPs
     * test distribution with voteParticipation
     * remove surplus state variables
     * resolve mulDiv for signed int
     * fix getScore internal calculation
     */

    /*///////////////////////////////////////////////////////////////
                            ADDRESS REGISTRY
    //////////////////////////////////////////////////////////////*/

    address immutable THE_RABBIT;
    address immutable FIVE_OUT_OF_NINE;
    address immutable WETH_9;
    address immutable KP3R_V1;
    address immutable KP3R_LP;
    address immutable SWAP_ROUTER;
    address immutable KEEP3R;
    address immutable SUDOSWAP_FACTORY;
    address immutable SUDOSWAP_CURVE;
    address public immutable SUDOSWAP_POOL;
    address public nftDescriptor;

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /* IERC721 */
    address public immutable owner;

    /* NFT whitelisting mechanics */
    uint256 public immutable genesis;
    mapping(uint256 => bool) public whitelistedToken;

    /*///////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    uint32 immutable PERIOD;
    uint32 immutable COOLDOWN;
    bool bunnySaysSo;

    struct Registry {
        address masterOfCeremony;
        address fiveOutOfNine;
        address weth;
        address kp3rV1;
        address keep3rLP;
        address keep3r;
        address uniswapRouter;
        address sudoswapFactory;
        address sudoswapCurve;
    }

    constructor(Registry memory _registry, uint32 _period, uint32 _cooldown) ERC721('ChessOlympiads', unicode'{♙}') {
        THE_RABBIT = _registry.masterOfCeremony;
        FIVE_OUT_OF_NINE = _registry.fiveOutOfNine;
        WETH_9 = _registry.weth;
        KP3R_V1 = _registry.kp3rV1;
        KP3R_LP = _registry.keep3rLP;
        SWAP_ROUTER = _registry.uniswapRouter;
        KEEP3R = _registry.keep3r;
        SUDOSWAP_FACTORY = _registry.sudoswapFactory;
        SUDOSWAP_CURVE = _registry.sudoswapCurve;

        PERIOD = _period;
        COOLDOWN = _cooldown;

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
                _bondingCurve: ICurve(SUDOSWAP_CURVE),
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
        // records supply of fiveOutOfNine to whitelist pre-genesis tokens
        genesis = IERC20(FIVE_OUT_OF_NINE).totalSupply();
    }

    /// @dev Permissioned method, allows rabbit to cancel the event
    function saySo() external onlyRabbit {
        if (state == STATE.ANNOUNCEMENT) state = STATE.CANCELLED;
        else bunnySaysSo = true;
    }

    modifier onlyRabbit() {
        if (msg.sender != THE_RABBIT) revert WrongMethod();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            BADGE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows the signer to mint a Player NFT, bonding a 5/9 and paying ETH price
    function mintPlayerBadge(uint256 _tokenId) external payable returns (uint256 _badgeId) {
        if (state < STATE.TICKET_SALE || state >= STATE.GAME_OVER) revert WrongTiming();

        _validateFiveOutOfNine(_tokenId);

        uint256 _value = msg.value;
        if (_value < 0.05 ether || _value > 1 ether) revert WrongValue();
        uint256 _weight = _value.sqrt();

        // players can only mint badges from the not-playing team
        TEAM _team = TEAM((_roundT(block.timestamp, PERIOD) / PERIOD) % 2);
        _team = _team == TEAM.ZERO ? TEAM.ONE : TEAM.ZERO;
        // a player cannot be minted for a soon-to-win team
        if (matchesWon[_team] == 4) revert WrongTeam();

        _badgeId = ++totalPlayers + (_tokenId << 16) + (uint256(_team) << 32);
        _safeMint(msg.sender, _badgeId);
        badgeWeight[_badgeId] = _weight;

        // msg.sender must approve the FiveOutOfNine transfer
        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    /// @dev Allows the signer to register a ButtPlug NFT
    function mintButtPlugBadge(address _buttPlug) external returns (uint256 _badgeId) {
        if ((state < STATE.TICKET_SALE) || (state >= STATE.GAME_OVER)) revert WrongTiming();

        // buttPlug contract must have an owner view method
        address _owner = IButtPlug(_buttPlug).owner();

        _badgeId = _calculateButtPlugBadge(_buttPlug, TEAM.STAFF);
        _safeMint(_owner, _badgeId);
    }

    /// @dev Allows player to merge his badges' weight and score into a Medal NFT
    function mintMedal(uint256[] memory _badgeIds) external returns (uint256 _badgeId) {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        uint256 _totalWeight;
        uint256 _totalScore;

        uint256 _weight;
        uint256 _score;
        for (uint256 _i; _i < _badgeIds.length; _i++) {
            (_weight, _score) = _processBadge(_badgeIds[_i]);
            _totalWeight += _weight;
            _totalScore += _score;
        }

        // adds weight and score to scoreboard token
        badgeWeight[0] += _totalWeight;
        score[0] += int256(_totalScore);

        // TODO: create an identifiable ID for the medal
        _badgeId = uint256(uint256(uint160(msg.sender)) << 64) + (uint256(TEAM.MEDAL) << 32);
        badgeWeight[_badgeId] = _totalWeight;
        score[_badgeId] = int256(_totalScore);

        // TODO: Medal NFT description
        _safeMint(msg.sender, _badgeId);
    }

    function _processBadge(uint256 _badgeId) internal returns (uint256 _weight, uint256 _score) {
        TEAM _team = _getTeam(_badgeId);
        if (_team > TEAM.STAFF) revert WrongTeam();

        // if bunny says so, all badges are winners
        if (matchesWon[_team] >= 5 || bunnySaysSo) _weight = badgeWeight[_badgeId];

        // only positive score is accounted
        int256 _badgeScore = _getScore(_badgeId);
        _score = _badgeScore >= 0 ? uint256(_badgeScore) : 1;

        // msg.sender should be the owner
        transferFrom(msg.sender, address(this), _badgeId);
        _returnNftIfStaked(_badgeId);
    }

    /// @dev Allow players who claimed prize to withdraw their rewards
    function withdrawRewards(uint256 _badgeId) external onlyBadgeAllowed(_badgeId) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();
        if (_getTeam(_badgeId) != TEAM.MEDAL) revert WrongTeam();

        // safe because medals should have only positive score values
        uint256 _claimableSales = totalSales.mulDiv(uint256(score[_badgeId]), uint256(score[0]));
        uint256 _claimable = _claimableSales - claimedSales[_badgeId];

        // prize should be withdrawn only once per medal
        if (claimedSales[_badgeId] == 0) {
            IPairManager(KP3R_LP).balanceOf(address(this));
            // payable(0).safeTransferETH(totalPrize.mulDiv(badgeWeight[_badgeId], badgeWeight[0]));
            IPairManager(KP3R_LP).transfer(msg.sender, totalPrize.mulDiv(badgeWeight[_badgeId], badgeWeight[0]));
            claimedSales[_badgeId]++;
        }

        claimedSales[_badgeId] += _claimable;
        payable(msg.sender).safeTransferETH(_claimable);
    }

    function withdrawStakedNft(uint256 _badgeId) external onlyBadgeAllowed(_badgeId) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();
        _returnNftIfStaked(_badgeId);
    }

    function _returnNftIfStaked(uint256 _badgeId) internal {
        if (_badgeId < 1 << 60) {
            uint256 _tokenId = uint16(_badgeId >> 16);
            ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), msg.sender, _tokenId);
        }
    }

    modifier onlyBadgeAllowed(uint256 _badgeId) {
        address _sender = msg.sender;
        address _owner = ownerOf[_badgeId];
        if (_owner != _sender && !isApprovedForAll[_owner][_sender] && _sender != getApproved[_badgeId]) {
            revert WrongBadge();
        }
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
        uint256 _timestamp = block.timestamp;
        if (state >= STATE.GAME_OVER || _timestamp < canPushLiquidity) revert WrongTiming();
        if (state == STATE.TICKET_SALE) {
            state = STATE.GAME_RUNNING;
            ++matchNumber;
        }

        uint256 _eth = address(this).balance - totalSales;
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
        IKeep3r(KEEP3R).addLiquidityToJob(address(this), KP3R_LP, kLPBalance);

        totalPrize += kLPBalance;
        canPushLiquidity = _timestamp + PERIOD;
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
        _increaseSudoswapDelta();
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
        uint256 _timestamp = block.timestamp;
        uint256 _periodStart = _roundT(_timestamp, PERIOD);
        if ((state != STATE.GAME_RUNNING) || (_timestamp < canPlayNext)) revert WrongTiming();

        TEAM _team = TEAM((_periodStart / PERIOD) % 2);
        address _buttPlug = buttPlug[_team];

        if (_buttPlug == address(0)) {
            // if team does not have a buttplug, skip turn
            canPlayNext = _periodStart + PERIOD;
            return;
        }

        uint256 _votes = votes[_team][_buttPlug];
        uint256 _buttPlugBadgeId = _calculateButtPlugBadge(_buttPlug, _team);

        int8 _score;
        bool _isCheckmate;

        uint256 _board = IChess(FIVE_OUT_OF_NINE).board();
        // gameplay is wrapped in a try/catch block to punish reverts
        try ButtPlugWars(this).playMove{gas: BUTT_PLUG_GAS_LIMIT}(_board, _buttPlug) {
            uint256 _newBoard = IChess(FIVE_OUT_OF_NINE).board();
            _isCheckmate = _newBoard == CHECKMATE;
            if (_isCheckmate) {
                _score = 3;
                canPlayNext = _periodStart + PERIOD;
            } else {
                _score = _calcMoveScore(_board, _newBoard);
                canPlayNext = _timestamp + COOLDOWN;
            }
        } catch {
            // if buttplug or move reverts
            _score = -2;
            canPlayNext = _periodStart + PERIOD;
        }

        matchScore[_team] += _score;
        score[_buttPlugBadgeId] += _score * int256(_votes);

        // each match is limited to 69 moves
        if (_isCheckmate || ++matchMoves > 69) _checkMateRoutine();
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
        if (_gameOver()) {
            state = STATE.GAME_OVER;
            // all remaining ETH will be considered to distribute as sales
            totalSales = address(this).balance;
            canPlayNext = MAX_UINT;
            return;
        }
    }

    function _gameOver() internal view returns (bool) {
        // if bunny says so, current match was the last one
        return matchesWon[TEAM.ZERO] == 5 || matchesWon[TEAM.ONE] == 5 || bunnySaysSo;
    }

    function _roundT(uint256 _timestamp, uint256 _period) internal pure returns (uint256 _roundTimestamp) {
        _roundTimestamp = _timestamp - (_timestamp % _period);
    }

    function _calcDepth(uint256 _salt, address _keeper) internal view virtual returns (uint256 _depth) {
        uint256 _timeVariable = _roundT(block.timestamp, COOLDOWN);
        _depth = 3 + uint256(keccak256(abi.encode(_salt, _keeper, _timeVariable))) % 8;
    }

    /// @notice Adds +2 when eating a black piece, and substracts 1 when a white piece is eaten
    /// @dev Supports having more pieces than before, situation that should not be possible in production
    function _calcMoveScore(uint256 _previousBoard, uint256 _newBoard) internal pure returns (int8 _score) {
        (int8 _whitePiecesBefore, int8 _blackPiecesBefore) = _countPieces(_previousBoard);
        (int8 _whitePiecesAfter, int8 _blackPiecesAfter) = _countPieces(_newBoard);

        _score += 2 * (_blackPiecesBefore - _blackPiecesAfter);
        _score -= _whitePiecesBefore - _whitePiecesAfter;
    }

    /// @dev Efficiently loops through the board uint256 to search for pieces and count each color
    function _countPieces(uint256 _board) internal pure returns (int8 _whitePieces, int8 _blackPieces) {
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
    function voteButtPlug(address _buttPlug, uint256 _badgeId) external {
        if (_buttPlug == address(0)) revert WrongValue();
        _voteButtPlug(_buttPlug, _badgeId);
    }

    function voteButtPlug(address _buttPlug, uint256[] memory _badgeIds) external {
        if (_buttPlug == address(0)) revert WrongValue();
        for (uint256 _i; _i < _badgeIds.length; _i++) {
            _voteButtPlug(_buttPlug, _badgeIds[_i]);
        }
    }

    function _voteButtPlug(address _buttPlug, uint256 _badgeId) internal onlyBadgeAllowed(_badgeId) {
        TEAM _team = _getTeam(_badgeId);
        if (_team >= TEAM.STAFF) revert WrongTeam();

        uint256 _weight = badgeWeight[_badgeId];
        address _previousVote = vote[_badgeId];

        uint256 _buttPlugBadgeId;
        uint256 _voteParticipation;
        if (_previousVote != address(0)) {
            _buttPlugBadgeId = _calculateButtPlugBadge(_previousVote, _team);
            votes[_team][_previousVote] -= _weight;
            _voteParticipation = voteParticipation[_badgeId][_previousVote];
            int256 _lastVoteScore = score[_buttPlugBadgeId] - lastUpdatedScore[_badgeId][_buttPlugBadgeId];
            if (_lastVoteScore >= 0) {
                score[_badgeId] += int256(uint256(_lastVoteScore).mulDiv(_voteParticipation, BASE));
            } else {
                score[_badgeId] -= int256(uint256(-_lastVoteScore).mulDiv(_voteParticipation, BASE));
            }
        }

        _buttPlugBadgeId = _calculateButtPlugBadge(_buttPlug, _team);

        vote[_badgeId] = _buttPlug;
        votes[_team][_buttPlug] += _weight;
        lastUpdatedScore[_badgeId][_buttPlugBadgeId] = score[_buttPlugBadgeId];
        voteParticipation[_badgeId][_buttPlug] = _weight.mulDiv(BASE, votes[_team][_buttPlug]);

        if (votes[_team][_buttPlug] > votes[_team][buttPlug[_team]]) buttPlug[_team] = _buttPlug;
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

    function _validateFiveOutOfNine(uint256 _id) internal view {
        if (_id >= genesis && !whitelistedToken[_id]) revert WrongNFT();
    }

    function _increaseSudoswapDelta() internal {
        uint128 _currentDelta = LSSVMPair(SUDOSWAP_POOL).delta();
        LSSVMPair(SUDOSWAP_POOL).changeDelta(++_currentDelta);
    }

    /*///////////////////////////////////////////////////////////////
                          DELEGATE TOKEN URI
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _badgeId) public view virtual override returns (string memory) {
        if (ownerOf[_badgeId] == address(0)) revert WrongNFT();
        (bool _success, bytes memory _data) =
            address(this).staticcall(abi.encodeWithSignature('_tokenURI(uint256)', _badgeId));

        assembly {
            switch _success
            // delegatecall returns 0 on error.
            case 0 { revert(add(_data, 32), returndatasize()) }
            default { return(add(_data, 32), returndatasize()) }
        }
    }

    function _tokenURI(uint256) external {
        if (msg.sender != address(this)) revert WrongMethod();

        (bool _success, bytes memory _data) = address(nftDescriptor).delegatecall(msg.data);
        assembly {
            switch _success
            // delegatecall returns 0 on error.
            case 0 { revert(add(_data, 32), returndatasize()) }
            default { return(add(_data, 32), returndatasize()) }
        }
    }

    /// @dev Permissioned method, allows rabbit to change the nftDescriptor address
    function setNftDescriptor(address _nftDescriptor) external onlyRabbit {
        nftDescriptor = _nftDescriptor;
    }

    /*///////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        if (msg.sender == SUDOSWAP_POOL) totalSales += msg.value;
        return;
    }
}

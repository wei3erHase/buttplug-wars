// SPDX-License-Identifier: MIT

/*

  by             .__________                 ___ ___
  __  _  __ ____ |__\_____  \  ___________  /   |   \_____    ______ ____
  \ \/ \/ // __ \|  | _(__  <_/ __ \_  __ \/    ~    \__  \  /  ___// __ \
   \     /\  ___/|  |/       \  ___/|  | \/\    Y    // __ \_\___ \\  ___/
    \/\_/  \___  >__/______  /\___  >__|    \___|_  /(____  /____  >\___  >
               \/          \/     \/              \/      \/     \/     \/*/

pragma solidity >=0.8.4 <0.9.0;

import {NFTDescriptor} from './NFTDescriptor.sol';
import {GameSchema} from './GameSchema.sol';
import {IButtPlug, IChess, IDescriptorPlug} from 'interfaces/IGame.sol';
import {IKeep3r, IPairManager} from 'interfaces/IKeep3r.sol';
import {LSSVMPair, LSSVMPairETH, ILSSVMPairFactory, ICurve, IERC721} from 'interfaces/ISudoswap.sol';
import {ISwapRouter} from 'interfaces/IUniswap.sol';
import {IERC20, IWeth} from 'interfaces/IERC20.sol';

import {FiveOutOfNineUtils, Chess} from './FiveOutOfNineUtils.sol';
import {Jeison, Strings, IntStrings} from './Jeison.sol';

import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {SafeTransferLib} from 'isolmate/utils/SafeTransferLib.sol';
import {Math} from 'openzeppelin-contracts/utils/math/Math.sol';

/// @notice Contract will not be audited, proceed at your own risk
/// @dev THE_RABBIT will not be responsible for any loss of funds
contract ButtPlugWars is GameSchema, ERC721 {
    using SafeTransferLib for address payable;
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                            ADDRESS REGISTRY
    //////////////////////////////////////////////////////////////*/

    address immutable THE_RABBIT; // = 0x5dD028D0832739008c5308490e6522ce04342E10;
    address immutable FIVE_OUT_OF_NINE; // = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;

    address immutable WETH_9; // = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address immutable KP3R_V1; // = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address immutable KP3R_LP; // = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;

    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address immutable KEEP3R; // = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;
    address immutable SUDOSWAP_FACTORY; // = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    address immutable SUDOSWAP_XYK_CURVE; // = 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0;
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

    constructor(
        address _fiveOutOfNine,
        address _weth,
        address _keep3r,
        address _kLP,
        address _sudoswapFactory,
        address _xykCurve
    ) ERC721('ButtPlugBadge', unicode'♙') {
        THE_RABBIT = msg.sender;
        FIVE_OUT_OF_NINE = _fiveOutOfNine;
        WETH_9 = _weth;
        KEEP3R = _keep3r;
        KP3R_LP = _kLP;
        KP3R_V1 = IKeep3r(_keep3r).keep3rV1();
        SUDOSWAP_FACTORY = _sudoswapFactory;
        SUDOSWAP_XYK_CURVE = _xykCurve;

        nftDescriptor = address(new NFTDescriptor());

        // WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        // KEEP3R = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;
        // KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;
        // KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
        // SUDOSWAP_FACTORY = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
        // SUDOSWAP_XYK_CURVE = 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0;

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
        if (_team >= TEAM.STAFF) revert WrongTeam();

        _validateFiveOutOfNine(_tokenId);

        uint256 _value = msg.value;
        if (_value < 0.05 ether || _value > 1 ether) revert WrongValue();
        uint256 _shares = _value.sqrt();

        _badgeId = ++totalPlayers + (uint256(_team) << 32);
        _mint(msg.sender, _badgeId);

        bondedToken[_badgeId] = _tokenId;
        badgeShares[_badgeId] = _shares;
        totalShares += _shares;

        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    /// @dev Allows the signer to register a ButtPlug NFT
    function mintButtPlugBadge(address _buttPlug) external returns (uint256 _badgeId) {
        if ((state < STATE.TICKET_SALE) || (state >= STATE.GAME_OVER)) revert WrongTiming();
        address _owner = IButtPlug(_buttPlug).owner();

        _badgeId = _calculateButtPlugBadge(_buttPlug, TEAM.STAFF);
        _mint(_owner, _badgeId);
    }

    function getBadgeId(uint256 _playerNumber) external view returns (uint256 _badgeId) {
        if (ownerOf[_playerNumber] != address(0)) return _playerNumber;
        _playerNumber = _playerNumber + (uint256(TEAM.ONE) << 32);
        if (ownerOf[_playerNumber] != address(0)) return _playerNumber;
        revert WrongNFT();
    }

    function getBadgeId(address _buttPlug) external view returns (uint256 _badgeId) {
        _badgeId = _calculateButtPlugBadge(_buttPlug, TEAM.STAFF);
        if (ownerOf[_badgeId] == address(0)) revert WrongNFT();
    }

    /// @dev Allows players (winner team) claim a share of the prize acording to their value sent
    function claimPrize(uint256 _badgeId) external {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        _claimPrize(_badgeId);
    }

    function claimPrize(uint256[] memory _badgeIds) external {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        for (uint256 _i; _i < _badgeIds.length; _i++) {
            _claimPrize(_badgeIds[_i]);
        }
    }

    function _claimPrize(uint256 _badgeId) internal onlyBadgeOwner(_badgeId) {
        TEAM _team = _getTeam(_badgeId);
        if (matchesWon[_team] < 5) revert WrongTeam();

        uint256 _shares = badgeShares[_badgeId];
        _shares *= _shares; // prize is claimed by inputted ETH (weight^2)
        playerPrizeShares[msg.sender] += _shares;
        totalPrizeShares += _shares;

        transferFrom(msg.sender, address(this), _badgeId);
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
    function claimHonor(uint256 _badgeId) external {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        _claimHonor(_badgeId);
    }

    function claimHonor(uint256[] memory _badgeIds) external {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        for (uint256 _i; _i < _badgeIds.length; _i++) {
            _claimHonor(_badgeIds[_i]);
        }
    }

    function _claimHonor(uint256 _badgeId) internal onlyBadgeOwner(_badgeId) {
        int256 _badgeScore = _getScore(_badgeId);
        bool _isPositive = _badgeScore > 0;
        uint256 _shares = _isPositive ? uint256(_badgeScore) : 1;

        playerHonorShares[msg.sender] += _shares;
        totalHonorShares += _shares;

        transferFrom(msg.sender, address(this), _badgeId);
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
        if ((state != STATE.GAME_RUNNING) || (_timestamp < canPlayNext)) revert WrongTiming();

        // each match is limited to 59 moves
        if (++matchMoves > 59) _checkMateRoutine();

        TEAM _team = TEAM((_roundT(_timestamp, PERIOD) / PERIOD) % 2);
        address _buttPlug = buttPlug[_team];

        if (_buttPlug == address(0)) {
            // if team does not have a buttplug, skip turn
            canPlayNext = _roundT(_timestamp + PERIOD, PERIOD);
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
                canPlayNext = _roundT(_timestamp + PERIOD, PERIOD);
            } else {
                _score = _calcMoveScore(_board, _newBoard);
                canPlayNext = _timestamp + COOLDOWN;
            }
        } catch {
            // if buttplug or move reverts
            _score = -2;
            canPlayNext = _roundT(_timestamp + PERIOD, PERIOD);
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
        if (_gameOver()) {
            state = STATE.GAME_OVER;
            // all remaining ETH will be considered to distribute as sales
            claimableSales = address(this).balance;
            canPlayNext = MAX_UINT;
            return;
        }
    }

    function _gameOver() internal view returns (bool) {
        return matchesWon[TEAM.ZERO] == 5 || matchesWon[TEAM.ONE] == 5;
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

    function _voteButtPlug(address _buttPlug, uint256 _badgeId) internal onlyBadgeOwner(_badgeId) {
        TEAM _team = _getTeam(_badgeId);
        if (_team == TEAM.STAFF) revert WrongBadge();

        uint256 _weight = badgeShares[_badgeId];
        address _previousVote = badgeButtPlugVote[_badgeId];
        if (_previousVote != address(0)) {
            uint256 _previousButtPlugBadge = _calculateButtPlugBadge(_previousVote, _team);
            buttPlugVotes[_team][_previousVote] -= _weight;
            uint256 _previousParticipation = participationBoost[_badgeId][_previousVote];
            score[_badgeId] += int256(_previousParticipation)
                * (score[_previousButtPlugBadge] - lastUpdatedScore[_badgeId][_previousButtPlugBadge]) / int256(BASE);
        }

        uint256 _currentButtPlugBadge = _calculateButtPlugBadge(_buttPlug, _team);
        lastUpdatedScore[_badgeId][_currentButtPlugBadge] = score[_currentButtPlugBadge];
        badgeButtPlugVote[_badgeId] = _buttPlug;
        buttPlugVotes[_team][_buttPlug] += _weight;
        participationBoost[_badgeId][_buttPlug] = (BASE * _weight) / buttPlugVotes[_team][_buttPlug];

        if (buttPlugVotes[_team][_buttPlug] > buttPlugVotes[_team][buttPlug[_team]]) buttPlug[_team] = _buttPlug;
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
        if (msg.sender == SUDOSWAP_POOL) claimableSales += msg.value;
        return;
    }
}

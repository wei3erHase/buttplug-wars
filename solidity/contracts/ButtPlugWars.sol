// SPDX-License-Identifier: MIT

/*

  by             .__________                 ___ ___
  __  _  __ ____ |__\_____  \  ___________  /   |   \_____    ______ ____
  \ \/ \/ // __ \|  | _(__  <_/ __ \_  __ \/    ~    \__  \  /  ___// __ \
   \     /\  ___/|  |/       \  ___/|  | \/\    Y    // __ \_\___ \\  ___/
    \/\_/  \___  >__/______  /\___  >__|    \___|_  /(____  /____  >\___  >
               \/          \/     \/              \/      \/     \/     \/

*/

pragma solidity >=0.8.4 <0.9.0;

import {IButtPlug, IChess} from 'interfaces/Game.sol';
import {IKeep3r, IPairManager} from 'interfaces/Keep3r.sol';
import {LSSVMPair, LSSVMPairETH, ILSSVMPairFactory, ICurve, IERC721} from 'interfaces/Sudoswap.sol';
import {ISwapRouter} from 'interfaces/Uniswap.sol';
import {IERC20, IWeth} from 'interfaces/ERC20.sol';

import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {SafeTransferLib} from 'isolmate/utils/SafeTransferLib.sol';
import {Base64} from './Base64.sol';

/// @notice Contract will not be audited, proceed at your own risk
/// @dev THE_RABBIT will not be responsible for any loss of funds
contract ButtPlugWars is ERC721 {
    using SafeTransferLib for address payable;

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

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /* IERC721 */
    address public immutable owner;
    uint256 public totalSupply;

    /* Roadmap */
    enum STATE {
        ANNOUNCEMENT, // rabbit can cancel event
        TICKET_SALE, // can mint badges (@ x2)
        GAME_RUNNING, // game runs, can mint badges (@ x2->1)
        GAME_OVER, // game stops, can unbondLiquidity
        PREPARATIONS, // can claim prize, waits until kLPs are unbonded
        PRIZE_CEREMONY, // can withdraw prize or honors
        CANCELLED // a critical bug was found
    }

    STATE public state = STATE.ANNOUNCEMENT;
    uint256 public canStartSales;

    /* Game mechanics */
    enum TEAM {
        A,
        B,
        KEEPER
    }

    uint256 constant BASE = 1 ether;
    uint256 constant PERIOD = 5 days;
    uint256 constant COOLDOWN = 30 minutes;
    uint256 constant LIQUIDITY_COOLDOWN = 3 days;
    uint256 constant CHECKMATE = 0x3256230011111100000000000000000099999900BCDECB000000001;
    /// @dev Magic number by @fiveOutOfNine
    uint256 constant MAGIC_NUMBER = 0xDB5D33CB1BADB2BAA99A59238A179D71B69959551349138D30B289;

    mapping(TEAM => uint256) public matchesWon;
    mapping(TEAM => int256) public matchScore;
    uint256 matchTotalMoves;
    uint256 public matchNumber;
    uint256 public canPlayNext;
    uint256 public canPushLiquidity;

    /* Badge mechanics */
    uint256 public totalShares;
    mapping(uint256 => uint256) public badgeShares;
    mapping(uint256 => uint256) public bondedToken;

    /* Vote mechanics */
    mapping(TEAM => address) buttPlug;
    mapping(TEAM => mapping(address => uint256)) buttPlugVotes;
    mapping(uint256 => int256) score;
    mapping(uint256 => mapping(uint256 => int256)) lastUpdatedScore;
    mapping(uint256 => address) public badgeVote;
    mapping(uint256 => uint256) public canVoteNext;

    /* Prize mechanics */
    uint256 totalPrize;
    uint256 totalPrizeShares;
    mapping(address => uint256) playerPrizeShares;

    uint256 claimableSales;
    mapping(uint256 => uint256) claimedSales;
    uint256 public canUpdateSpotPriceNext;

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
        IERC20(WETH_9).approve(SWAP_ROUTER, type(uint256).max);
        IERC20(KP3R_V1).approve(KP3R_LP, type(uint256).max);
        IERC20(WETH_9).approve(KP3R_LP, type(uint256).max);
        IPairManager(KP3R_LP).approve(KEEP3R, type(uint256).max);

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
    }

    /// @dev Permissioned method, allows rabbit to cancel the event
    function cancelEvent() external {
        if (msg.sender != THE_RABBIT) revert WrongMethod();
        if (state != STATE.ANNOUNCEMENT) revert WrongTiming();

        state = STATE.CANCELLED;
    }

    /// @dev Open method, allows signer to start ticket sale
    function startEvent() external honorablyUpkeep {
        uint256 _timestamp = block.timestamp;
        if ((state != STATE.ANNOUNCEMENT) || (_timestamp < canStartSales)) revert WrongTiming();

        state = STATE.TICKET_SALE;
        canPushLiquidity = _timestamp + 2 * PERIOD;
    }

    /*///////////////////////////////////////////////////////////////
                            BADGE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows the signer to purchase a NFT, bonding a 5/9 and paying ETH price
    function buyBadge(uint256 _tokenId, TEAM _team) external payable returns (uint256 _badgeId) {
        if ((state < STATE.TICKET_SALE) || (state >= STATE.GAME_OVER)) revert WrongTiming();

        uint256 _value = msg.value;
        if (_value < 0.05 ether || _value > 1 ether) revert WrongValue();
        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(msg.sender, address(this), _tokenId);

        _badgeId = _mint(msg.sender, _team);
        bondedToken[_badgeId] = _tokenId;

        uint256 _shares = (_value * _shareCoefficient()) / BASE;
        badgeShares[_badgeId] = _shares;
        totalShares += _shares;
    }

    function _shareCoefficient() internal view returns (uint256) {
        return 2 * BASE - (BASE * matchNumber / 8);
    }

    /// @dev Allows players (winner team) to burn their token in exchange for a share of the prize
    function claimPrize(uint256 _badgeId) external onlyBadgeOwner(_badgeId) {
        if (state != STATE.PREPARATIONS) revert WrongTiming();

        TEAM _team = TEAM(uint8(_badgeId >> 59));
        if (matchesWon[_team] < 5) revert WrongTeam();

        uint256 _shares = badgeShares[_badgeId];
        playerPrizeShares[msg.sender] += _shares;
        totalPrizeShares += _shares;

        delete badgeShares[_badgeId];
        totalShares -= _shares;

        _burn(_badgeId);
        uint256 _tokenId = bondedToken[_badgeId];
        if (_tokenId != 0) {
            ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _tokenId);
            _increaseSudoswapDelta();
        }
    }

    /// @dev Allow players who claimed prize to withdraw their funds
    function withdrawPrize() external {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();

        uint256 _withdrawnPrize = playerPrizeShares[msg.sender] * totalPrize / totalPrizeShares;
        IPairManager(KP3R_LP).transfer(msg.sender, _withdrawnPrize);

        delete playerPrizeShares[msg.sender];
    }

    /// @dev Allows players (who didn't claim the prize) to withdraw ETH from the pool sales
    function claimHonor(uint256 _badgeId) external onlyBadgeOwner(_badgeId) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();
        _claimHonor(_badgeId);
    }

    function _claimHonor(uint256 _badgeId) internal {
        uint256 shareCoefficient = BASE * badgeShares[_badgeId] / totalShares;
        uint256 _claimable = (shareCoefficient * claimableSales / BASE) - claimedSales[_badgeId];
        claimedSales[_badgeId] += _claimable;

        payable(msg.sender).safeTransferETH(_claimable);
    }

    /// @dev Allows players to return their badge and get the bonded NFT withdrawn
    function returnBadge(uint256 _badgeId) external onlyBadgeOwner(_badgeId) {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();
        if (_badgeId > 1 << 60) revert WrongMethod();

        _claimHonor(_badgeId);
        claimableSales -= claimedSales[_badgeId];
        totalShares -= badgeShares[_badgeId];

        _burn(_badgeId);

        uint256 _tokenId = bondedToken[_badgeId];
        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    modifier onlyBadgeOwner(uint256 _badgeId) {
        if (ownerOf[_badgeId] != msg.sender) revert WrongBadge();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            KEEP3R MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Open method, allows signer to swap ETH => KP3R, mints kLP and adds to job
    function pushLiquidity() external honorablyUpkeep {
        if (state >= STATE.GAME_OVER) revert WrongTiming();
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

    /// @dev Open method, allows signer (after game ended) to start unbond period
    function unbondLiquidity() external honorablyUpkeep {
        if (state != STATE.GAME_OVER) revert WrongTiming();
        totalPrize = IKeep3r(KEEP3R).liquidityAmount(address(this), KP3R_LP);
        IKeep3r(KEEP3R).unbondLiquidityFromJob(address(this), KP3R_LP, totalPrize);
        state = STATE.PREPARATIONS;
    }

    /// @dev Open method, allows signer (after unbonding) to withdraw kLPs
    function withdrawLiquidity() external honorablyUpkeep {
        if (state != STATE.PREPARATIONS) revert WrongTiming();
        /// @dev Method reverts unless 2w cooldown since unbond tx
        IKeep3r(KEEP3R).withdrawLiquidityFromJob(address(this), KP3R_LP, address(this));
        state = STATE.PRIZE_CEREMONY;
    }

    /// @dev Open method, allows signer (after game is over) to reduce pool spotPrice
    function updateSpotPrice() external {
        uint256 _timestamp = block.timestamp;
        if (state <= STATE.GAME_OVER || _timestamp < canUpdateSpotPriceNext) revert WrongTiming();

        uint128 _spotPrice = LSSVMPair(SUDOSWAP_POOL).spotPrice();
        LSSVMPair(SUDOSWAP_POOL).changeSpotPrice(_spotPrice * 5 / 9);
        canUpdateSpotPriceNext = _timestamp + 59 days;
    }

    /// @dev Handles Keep3r mechanism and payment
    modifier upkeep(address _keeper) {
        if (!IKeep3r(KEEP3R).isKeeper(_keeper) || IERC20(FIVE_OUT_OF_NINE).balanceOf(_keeper) < matchNumber) {
            revert WrongKeeper();
        }
        _;
        IKeep3r(KEEP3R).worked(_keeper);
    }

    /// @dev Rewards signer with inflation on their NFT to claim later for sales§
    modifier honorablyUpkeep() {
        uint256 _initialGas = gasleft();
        uint256 _keeperBadgeId = _getOrMintKeeperBadge(msg.sender);
        _;
        uint256 _inflation = (_initialGas - gasleft()) * 15e9;
        badgeShares[_keeperBadgeId] += _inflation;
        totalShares += _inflation;
    }

    /*///////////////////////////////////////////////////////////////
                            GAME MECHANICS
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by keepers to execute the next move
    function executeMove() external upkeep(msg.sender) {
        if ((state != STATE.GAME_RUNNING) || (block.timestamp < canPlayNext)) revert WrongTiming();

        if (++matchTotalMoves > 59) _checkMateRoutine();

        TEAM _team = _getTeam();
        uint256 _board = IChess(FIVE_OUT_OF_NINE).board();
        address _buttPlug = buttPlug[_team];
        uint256 _buttPlugBadgeId = _getOrMintButtPlugBadge(_buttPlug, _team);
        uint256 _buttPlugVotes = buttPlugVotes[_team][_buttPlug];
        uint256 _inflation = _buttPlugVotes * 59 / 10_000;
        badgeShares[_buttPlugBadgeId] += _inflation;
        totalShares += _inflation;

        try ButtPlugWars(this).playMove(_board, _buttPlug) {
            uint256 _newBoard = IChess(FIVE_OUT_OF_NINE).board();
            if (_newBoard != CHECKMATE) {
                int8 _score = _calcScore(_board, _newBoard);
                matchScore[_team] += _score;
                score[_buttPlugBadgeId] += _score * int256(_buttPlugVotes);
                canPlayNext = block.timestamp + COOLDOWN;
            } else {
                score[_buttPlugBadgeId] += 3 * int256(_buttPlugVotes);
                _checkMateRoutine();
            }
        } catch {
            // if playMove() reverts, team gets -1 point, buttPlug -2 * weigth, and next team is to play
            --matchScore[_team];
            score[_buttPlugBadgeId] -= 2 * int256(buttPlugVotes[_team][_buttPlug]);
            canPlayNext = _getRoundTimestamp(block.timestamp + PERIOD, PERIOD);
        }
    }

    function _checkMateRoutine() internal {
        if (matchScore[TEAM.A] >= matchScore[TEAM.B]) matchesWon[TEAM.A]++;
        if (matchScore[TEAM.B] >= matchScore[TEAM.A]) matchesWon[TEAM.B]++;
        if (++matchNumber >= 5) _verifyWinner();
        canPlayNext = _getRoundTimestamp(block.timestamp + PERIOD, PERIOD);
        delete matchTotalMoves;
    }

    function playMove(uint256 _board, address _buttPlug) external {
        if (msg.sender != address(this)) revert WrongMethod();

        uint256 _move = IButtPlug(_buttPlug).readMove(_board);
        uint256 _depth = _calcDepth(_board, msg.sender);
        IChess(FIVE_OUT_OF_NINE).mintMove(_move, _depth);
    }

    function _getRoundTimestamp(uint256 _timestamp, uint256 _period) internal pure returns (uint256 _roundTimestamp) {
        _roundTimestamp = _timestamp - (_timestamp % _period);
    }

    function _getTeam() internal view returns (TEAM _team) {
        _team = TEAM((_getRoundTimestamp(block.timestamp, PERIOD) / PERIOD) % 2);
    }

    function _calcDepth(uint256 _salt, address _keeper) internal view returns (uint256 _depth) {
        uint256 _timeVariable = _getRoundTimestamp(block.timestamp, COOLDOWN);
        _depth = 3 + uint256(keccak256(abi.encode(_salt, _keeper, _timeVariable))) % 8;
    }

    function _calcScore(uint256 _previousBoard, uint256 _newBoard) internal pure returns (int8 _score) {
        (uint8 _whitePiecesBefore, uint8 _blackPiecesBefore) = _countPieces(_previousBoard);
        (uint8 _whitePiecesAfter, uint8 _blackPiecesAfter) = _countPieces(_newBoard);

        _score -= int8(_whitePiecesBefore - _whitePiecesAfter);
        _score += 2 * int8(_blackPiecesBefore - _blackPiecesAfter);
    }

    function _countPieces(uint256 _board) internal pure returns (uint8 _whitePieces, uint8 _blackPieces) {
        uint256 _space;
        for (uint256 i = MAGIC_NUMBER; i != 0; i >>= 6) {
            _space = (_board >> ((i & 0x3F) << 2)) & 0xF;
            if (_space == 0) continue;
            _space >> 3 == 1 ? _whitePieces++ : _blackPieces++;
        }
    }

    function _verifyWinner() internal {
        if ((matchesWon[TEAM.A] >= 5) || matchesWon[TEAM.B] >= 5) state = STATE.GAME_OVER;
        if ((matchesWon[TEAM.A] >= 5) || matchesWon[TEAM.B] >= 5) state = STATE.GAME_OVER;
    }

    /*///////////////////////////////////////////////////////////////
                            VOTE MECHANICS
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows players to vote for their preferred ButtPlug
    function voteButtPlug(address _buttPlug, uint256 _badgeId, uint32 _lockTime) external onlyBadgeOwner(_badgeId) {
        if (_buttPlug == address(0)) revert WrongValue();
        if (_badgeId > 1 << 60) revert WrongMethod();

        uint256 _timestamp = block.timestamp;
        if (_timestamp < canVoteNext[_badgeId]) revert WrongTiming();
        // Locking allows external actors to bribe players
        canVoteNext[_badgeId] = _timestamp + uint256(_lockTime);

        TEAM _team = TEAM(uint8(_badgeId >> 59));
        uint256 _weight = badgeShares[_badgeId];

        address _previousVote = badgeVote[_badgeId];
        if (_previousVote != address(0)) {
            uint256 _previousButtPlug = _calculateButtPlugBadge(_previousVote, _team);
            buttPlugVotes[_team][_previousVote] -= _weight;
            score[_badgeId] += score[_previousButtPlug] - lastUpdatedScore[_badgeId][_previousButtPlug];
        }

        uint256 _currentButtPlug = _calculateButtPlugBadge(_buttPlug, _team);
        lastUpdatedScore[_badgeId][_currentButtPlug] = score[_currentButtPlug];
        badgeVote[_badgeId] = _buttPlug;
        buttPlugVotes[_team][_buttPlug] += _weight;

        if (buttPlugVotes[_team][_buttPlug] > buttPlugVotes[_team][buttPlug[_team]]) buttPlug[_team] = _buttPlug;
    }

    function _getScore(uint256 _badgeId) internal view returns (int256 _score) {
        TEAM _team = TEAM(uint8(_badgeId >> 59));
        uint256 _currentButtPlug = _calculateButtPlugBadge(badgeVote[_badgeId], _team);
        return score[_badgeId] + score[_currentButtPlug] - lastUpdatedScore[_badgeId][_currentButtPlug];
    }

    /*///////////////////////////////////////////////////////////////
                                ERC721
    //////////////////////////////////////////////////////////////*/

    function _mint(address _receiver, TEAM _team) internal returns (uint256 _badgeId) {
        _badgeId = ++totalSupply;
        _badgeId += uint256(_team) << 59;
        _mint(_receiver, _badgeId);
    }

    function _burn(uint256 _badgeId) internal override {
        totalSupply--;
        super._burn(_badgeId);
    }

    function tokenURI(uint256 _badgeId) public view virtual override returns (string memory) {
        string memory _json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "ButtPlugBadge",',
                        '"image_data": "',
                        _getSvg(_badgeId),
                        '",',
                        '"attributes": [{"trait_type": "Weigth", "value": ',
                        _uint2str(badgeShares[_badgeId]),
                        '}]}'
                    )
                )
            )
        );
        return string(abi.encodePacked('data:application/json;base64,', _json));
    }

    function onERC721Received(address, address _from, uint256 _id, bytes calldata) external returns (bytes4) {
        if (msg.sender != FIVE_OUT_OF_NINE) revert WrongNFT();
        // if token is newly minted transfer to sudoswap pool
        if (_from == address(0)) {
            ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _id);
            _increaseSudoswapDelta();
        }

        return 0x150b7a02;
    }

    function _increaseSudoswapDelta() internal {
        uint128 _currentDelta = LSSVMPair(SUDOSWAP_POOL).delta();
        LSSVMPair(SUDOSWAP_POOL).changeDelta(++_currentDelta);
    }

    function _getOrMintButtPlugBadge(address _buttPlug, TEAM _team) internal returns (uint256 _badgeId) {
        _badgeId = _calculateButtPlugBadge(_buttPlug, _team);
        if (ownerOf[_badgeId] != _buttPlug) _mint(_buttPlug, _badgeId);
    }

    function _calculateButtPlugBadge(address _buttPlug, TEAM _team) internal pure returns (uint256 _badgeId) {
        return uint160(_buttPlug) << 69 + uint8(_team) << 59;
    }

    /// @notice Will revert if keeper has transferred his badge
    function _getOrMintKeeperBadge(address _keeper) internal returns (uint256 _badgeId) {
        _badgeId = uint160(_keeper) << 69 + uint8(TEAM.KEEPER) << 59;
        if (ownerOf[_badgeId] != _keeper) _mint(_keeper, _badgeId);
    }

    function transferFrom(address _from, address _to, uint256 _badgeId) public virtual override {
        if (_badgeId > 1 << 60 && state < STATE.GAME_OVER) revert WrongTiming();
        super.transferFrom(_from, _to, _badgeId);
    }

    function _getSvg(uint256 tokenId) internal view returns (string memory) {
        TEAM _team = TEAM(tokenId >> 59);
        string memory _svg =
            "<svg width='300px' height='300px' viewBox='0 0 300 300' fill='none' xmlns='http://www.w3.org/2000/svg'><path width='48' height='48' fill='white' d='M0 0H300V300H0V0z'/><path d='M275 25H193L168 89C196 95 220 113 232 137L275 25Z' fill='#2F88FF' stroke='black' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/><path d='M106 25H25L67 137C79 113 103 95 131 89L106 25Z' fill='#2F88FF' stroke='black' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/><path d='M243 181C243 233 201 275 150 275C98 275 56 233 56 181 C56 165 60 150 67 137 C79 113 103 95 131 89 C137 88 143 87 150 87 C156 87 162 88 168 89 C196 95 220 113 232 137C239 150.561 243.75 165.449 243 181Z' fill='";

        if (matchesWon[_team] >= 5) {
            _svg = string(abi.encodePacked(_svg, '#FEA914'));
        } else {
            if (_team == TEAM.A) _svg = string(abi.encodePacked(_svg, '#2F88FF'));
            else _svg = string(abi.encodePacked(_svg, '#C1292E'));
        }

        _svg = string(
            abi.encodePacked(
                _svg,
                "' stroke='black' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/><svg viewBox='-115 -25 300 100'><path "
            )
        );

        if (_team == TEAM.A) _svg = string(abi.encodePacked(_svg, "d='M5,90 l30,-80 30,80 M20,50 l30,0' "));
        else _svg = string(abi.encodePacked(_svg, "d='M5,5 c80,0 80,45 0,45 c80,0 80,45 0,45z' "));

        _svg = string(
            abi.encodePacked(
                _svg,
                "stroke='white' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/></svg><text x='50%' y='80%' stroke='black' dominant-baseline='middle' text-anchor='middle'>",
                _uint2str(tokenId % (1 << 59)),
                '</text></svg>'
            )
        );

        return _svg;
    }

    function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) return '0';
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    receive() external payable {
        if (msg.sender == SUDOSWAP_POOL) claimableSales += msg.value;
        return;
    }
}

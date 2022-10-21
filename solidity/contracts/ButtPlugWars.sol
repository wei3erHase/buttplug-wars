// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IButtPlug, IChess} from 'interfaces/Game.sol';
import {IKeep3r, IPairManager} from 'interfaces/Keep3r.sol';
import {LSSVMPair, LSSVMPairETH, ILSSVMPairFactory, ICurve, IERC721} from 'interfaces/Sudoswap.sol';
import {ISwapRouter} from 'interfaces/Uniswap.sol';
import {IERC20, IWeth} from 'interfaces/ERC20.sol';

import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {SafeTransferLib} from 'isolmate/utils/SafeTransferLib.sol';
import {Base64} from './Base64.sol';

contract ButtPlugWars is ERC721 {
    using SafeTransferLib for address payable;

    /*///////////////////////////////////////////////////////////////
                            ADDRESS REGISTRY
    //////////////////////////////////////////////////////////////*/

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
        GAME_ENDED, // game stops, can unbondLiquidity
        PREPARATIONS, // can claim prize, waits until kLPs are unbonded
        PRIZE_CEREMONY, // can withdraw prize or honors
        CANCELLED
    }

    STATE public state = STATE.ANNOUNCEMENT;
    uint256 canStartSales;

    /* Game mechanics */
    enum TEAM {
        A,
        B
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

    /* Badge mechanics */
    uint256 public totalShares;
    mapping(uint256 => uint256) public badgeShares;
    mapping(uint256 => uint256) public bondedToken;

    /* Vote mechanics */
    mapping(TEAM => address) buttPlug;
    mapping(TEAM => mapping(address => uint256)) buttPlugVotes;
    mapping(uint256 => address) public badgeVote;
    mapping(uint256 => uint256) public canVoteNext;

    /* Prize mechanics */
    uint256 totalPrize;
    uint256 totalPrizeShares;
    mapping(address => uint256) playerPrizeShares;

    uint256 claimableSales;
    mapping(uint256 => uint256) claimedSales;

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
        canStartSales = block.timestamp + 2 * PERIOD;
    }

    /// @dev Permissioned method, allows rabbit to cancel the event
    function cancelEvent() external {
        if (msg.sender != THE_RABBIT) revert WrongMethod();
        if (state != STATE.ANNOUNCEMENT) revert WrongTiming();

        state = STATE.CANCELLED;
    }

    /// @dev Open method, allows signer to start ticket sale
    function startEvent() external {
        uint256 _timestamp = block.timestamp;
        if ((state != STATE.ANNOUNCEMENT) || (_timestamp < canStartSales)) revert WrongTiming();

        state = STATE.TICKET_SALE;
        canPushLiquidity = _timestamp + 2 * PERIOD;
    }

    /*///////////////////////////////////////////////////////////////
                            BADGE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows the signer to purchase a NFT, bonding a 5/9 and paying ETH price
    function buyBadge(uint256 _tokenId, TEAM _team) external payable returns (uint256 _badgeID) {
        if (state >= STATE.GAME_ENDED) revert WrongTiming();

        uint256 _value = msg.value;
        if (_value < 0.05 ether || _value > 1 ether) revert WrongValue();
        ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(msg.sender, address(this), _tokenId);

        _badgeID = _mint(msg.sender, _team);
        bondedToken[_badgeID] = _tokenId;

        uint256 _shares = (_value * _shareCoefficient()) / BASE;
        badgeShares[_badgeID] = _shares;
        totalShares += _shares;
    }

    function _shareCoefficient() internal view returns (uint256) {
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

    /*///////////////////////////////////////////////////////////////
                            KEEP3R MANAGEMENT
    //////////////////////////////////////////////////////////////*/

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

    /// @dev Open method, allows signer (after game ended) to start unbond period
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

    /*///////////////////////////////////////////////////////////////
                            GAME MECHANICS
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by keepers to execute the next move
    function executeMove() external upkeep(msg.sender) {
        if ((state != STATE.GAME_RUNNING) || (block.timestamp < canPlayNext)) revert WrongTiming();

        TEAM _team = _getTeam();
        uint256 _board = IChess(FIVE_OUT_OF_NINE).board();

        try ButtPlugWars(this).playMove(_board, _team) {
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
        } catch {
            // if playMove() reverts, team gets -1 point and next team is to play
            --matchScore[_team];
            canPlayNext = _getRoundTimestamp(block.timestamp + PERIOD, PERIOD);
        }
    }

    function playMove(uint256 _board, TEAM _team) external {
        if (msg.sender != address(this)) revert WrongMethod();

        address _buttPlug = buttPlug[_team];
        uint256 _move = IButtPlug(_buttPlug).readMove(_board);
        uint256 _depth = _calcDepth(_board, msg.sender);
        IChess(FIVE_OUT_OF_NINE).mintMove(_move, _depth);
    }

    function _getRoundTimestamp(uint256 _timestamp, uint256 _period) internal pure returns (uint256 _roundTimestamp) {
        _roundTimestamp = _timestamp - (_timestamp % _period);
    }

    function _getTeam() internal view returns (TEAM _team) {
        _team = TEAM((_getRoundTimestamp(block.timestamp, PERIOD) % PERIOD) % 2);
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

    function _verifyWinner() internal {
        if ((gameScore[TEAM.A] >= 5) || gameScore[TEAM.B] >= 5) state = STATE.GAME_ENDED;
    }

    /*///////////////////////////////////////////////////////////////
                            VOTE MECHANICS
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows players to vote for their preferred ButtPlug
    function voteButtPlug(address _buttPlug, uint256 _badgeID, uint32 _lockTime) external onlyBadgeOwner(_badgeID) {
        if (_buttPlug == address(0)) revert WrongValue();

        uint256 _timestamp = block.timestamp;
        if (_timestamp < canVoteNext[_badgeID]) revert WrongTiming();
        // Locking allows external actors to bribe players
        canVoteNext[_badgeID] = _timestamp + uint256(_lockTime);

        TEAM _team = TEAM(_badgeID >> 59);
        uint256 _weight = badgeShares[_badgeID];

        address _previousVote = badgeVote[_badgeID];
        if (_previousVote != address(0)) buttPlugVotes[_team][_previousVote] -= _weight;
        badgeVote[_badgeID] = _buttPlug;
        buttPlugVotes[_team][_buttPlug] += _weight;

        if (buttPlugVotes[_team][_buttPlug] > buttPlugVotes[_team][buttPlug[_team]]) buttPlug[_team] = _buttPlug;
    }

    /*///////////////////////////////////////////////////////////////
                                ERC721
    //////////////////////////////////////////////////////////////*/

    function _mint(address _receiver, ButtPlugWars.TEAM _team) internal returns (uint256 _badgeID) {
        _badgeID = ++totalSupply;
        _badgeID += uint256(_team) << 59;
        _mint(_receiver, _badgeID);
    }

    function _burn(uint256 _badgeID) internal override {
        totalSupply--;
        super._burn(_badgeID);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "ButtPlugBadge",',
                        '"image_data": "',
                        _getSvg(tokenId),
                        '",',
                        '"attributes": [{"trait_type": "Weigth", "value": ',
                        _uint2str(badgeShares[tokenId]),
                        '}]}'
                    )
                )
            )
        );
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function onERC721Received(address, address _from, uint256 _id, bytes calldata) external returns (bytes4) {
        if (msg.sender != FIVE_OUT_OF_NINE) revert WrongNFT();
        // if token is newly minted transfer to sudoswap pool
        if (_from == address(0)) ERC721(FIVE_OUT_OF_NINE).safeTransferFrom(address(this), SUDOSWAP_POOL, _id);
        return 0x150b7a02;
    }

    function _getSvg(uint256 tokenId) internal view returns (string memory) {
        string memory svg;
        svg = "<svg width='350px' height='350px'";
        // concats SVG <3
        svg = string(
            abi.encodePacked(
                svg,
                " viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'> <path d='M11.55 18.46C11.3516 18.4577 11.1617 18.3789 11.02 18.24L5.32001 12.53C5.19492 12.3935 5.12553 12.2151 5.12553 12.03C5.12553 11.8449 5.19492 11.6665 5.32001 11.53L13.71 3C13.8505 2.85931 14.0412 2.78017 14.24 2.78H19.99C20.1863 2.78 20.3745 2.85796 20.5133 2.99674C20.652 3.13552 20.73 3.32374 20.73 3.52L20.8 9.2C20.8003 9.40188 20.7213 9.5958 20.58 9.74L12.07 18.25C11.9282 18.3812 11.7432 18.4559 11.55 18.46ZM6.90001 12L11.55 16.64L19.3 8.89L19.25 4.27H14.56L6.90001 12Z' fill='red'/> <path d='M14.35 21.25C14.2512 21.2522 14.153 21.2338 14.0618 21.1959C13.9705 21.158 13.8882 21.1015 13.82 21.03L2.52 9.73999C2.38752 9.59782 2.3154 9.40977 2.31883 9.21547C2.32226 9.02117 2.40097 8.83578 2.53838 8.69837C2.67579 8.56096 2.86118 8.48224 3.05548 8.47882C3.24978 8.47539 3.43783 8.54751 3.58 8.67999L14.88 20C15.0205 20.1406 15.0993 20.3312 15.0993 20.53C15.0993 20.7287 15.0205 20.9194 14.88 21.06C14.7353 21.1907 14.5448 21.259 14.35 21.25Z' fill='red'/> <path d='M6.5 21.19C6.31632 21.1867 6.13951 21.1195 6 21L2.55 17.55C2.47884 17.4774 2.42276 17.3914 2.385 17.297C2.34724 17.2026 2.32855 17.1017 2.33 17C2.33 16.59 2.33 16.58 6.45 12.58C6.59063 12.4395 6.78125 12.3607 6.98 12.3607C7.17876 12.3607 7.36938 12.4395 7.51 12.58C7.65046 12.7206 7.72934 12.9112 7.72934 13.11C7.72934 13.3087 7.65046 13.4994 7.51 13.64C6.22001 14.91 4.82 16.29 4.12 17L6.5 19.38L9.86 16C9.92895 15.9292 10.0114 15.873 10.1024 15.8346C10.1934 15.7962 10.2912 15.7764 10.39 15.7764C10.4888 15.7764 10.5866 15.7962 10.6776 15.8346C10.7686 15.873 10.8511 15.9292 10.92 16C11.0605 16.1406 11.1393 16.3312 11.1393 16.53C11.1393 16.7287 11.0605 16.9194 10.92 17.06L7 21C6.8614 21.121 6.68402 21.1884 6.5 21.19Z' fill='red'/> </svg>"
            )
        );
        return svg;
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
}

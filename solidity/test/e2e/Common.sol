// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';

import {IChess, IButtPlug} from 'interfaces/IGame.sol';
import {LSSVMPair, ILSSVMPairFactory} from 'interfaces/ISudoswap.sol';
import {ButtPlugWars, IKeep3r} from 'contracts/ButtPlugWars.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {Engine} from 'fiveoutofnine/Engine.sol';

contract CommonE2EBase is DSTestFull {
    uint256 constant FORK_BLOCK = 15730000;

    address user = label('user');
    address owner = label('owner');
    ButtPlugWarsForTest buttPlugWars;
    ERC721 fiveOutOfNine = ERC721(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    IKeep3r keep3r = IKeep3r(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
    LSSVMPair sudoPool;
    IChess chess = IChess(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address constant ETH_WHALE = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address constant FIVEOUTOFNINE_WHALE = 0xC5233C3b46C83ADEE1039D340094173f0f7c1EcF;
    address constant KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;
    address constant WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant SUDOSWAP_FACTORY = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    address constant SUDOSWAP_XYK_CURVE = 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

        vm.startPrank(ETH_WHALE);
        payable(FIVEOUTOFNINE_WHALE).transfer(100 ether);
        vm.stopPrank();

        vm.startPrank(FIVEOUTOFNINE_WHALE);

        keep3r.bond(KP3R_V1, 0);
        vm.warp(block.timestamp + 3 days + 1);
        keep3r.activate(KP3R_V1);

        buttPlugWars =
        new ButtPlugWarsForTest(address(fiveOutOfNine), WETH_9, address(keep3r), KP3R_LP, SUDOSWAP_FACTORY, SUDOSWAP_XYK_CURVE);
        sudoPool = LSSVMPair(buttPlugWars.SUDOSWAP_POOL());
    }
}

contract ButtPlugWarsForTest is ButtPlugWars {
    constructor(
        address _fiveOutOfNine,
        address _weth,
        address _keep3r,
        address _kLP,
        address _sudoswapFactory,
        address _xykCurve
    ) ButtPlugWars(_fiveOutOfNine, _weth, _keep3r, _kLP, _sudoswapFactory, _xykCurve) {}

    function getState() external view returns (STATE) {
        return state;
    }

    function getTeamButtPlug(uint8 _team) public returns (address _buttPlug) {
        return buttPlug[TEAM(_team)];
    }

    function getCanPlayNext() public returns (uint256 _canPlayNext) {
        return canPlayNext;
    }

    function simulateButtPlug(IButtPlug _buttPlug, uint256 _depth, uint256 _steps)
        public
        returns (int8 _score, uint8 _isCheckmate, uint256 _gasUsed)
    {
        uint256 _initialGas = gasleft();
        uint256 _move;
        uint256 _board;
        uint256 _newBoard;

        for (uint8 _i; _i < _steps; ++_i) {
            _board = IChess(FIVE_OUT_OF_NINE).board();
            _move = IButtPlug(_buttPlug).readMove(_board);
            IChess(FIVE_OUT_OF_NINE).mintMove(_move, _depth);
            _newBoard = IChess(FIVE_OUT_OF_NINE).board();
            if (_newBoard == CHECKMATE) return (_score, ++_i, _initialGas - gasleft());
            _score += _calcMoveScore(_board, _newBoard);
        }
        return (_score, 0, _initialGas - gasleft());
    }

    function logSimulation(int8 _score, uint8 _isCheckmate, uint256 _gasUsed) public view {
        console.logString('score:');
        console.logInt(_score);
        console.logString('isCheckmate?');
        console.logUint(_isCheckmate);
        console.logString('gasUsed:');
        console.logUint(_gasUsed);
        console.logString('eth blocks used:');
        console.logUint(_gasUsed / 30e6);
    }

    function logBadgeWeigth(uint256 _badgeId) public view {
        console.logString('badge ID and weigth');
        console.logUint(_badgeId);
        console.logUint(badgeShares[_badgeId]);
    }

    function logBadgeScore(uint256 _badgeId) public view returns (int256 _score) {
        console.logString('badge ID and score');
        console.logUint(_badgeId);
        console.logInt(_getScore(_badgeId));
        return _getScore(_badgeId);
    }

    function logGameScore() public view {
        console.logString('team ZERO won');
        console.logUint(matchesWon[TEAM.ZERO]);
        console.logString('team ONE won');
        console.logUint(matchesWon[TEAM.ONE]);
    }

    function logMatchScore() public view {
        console.logString('team ZERO score');
        console.logInt(matchScore[TEAM.ZERO]);
        console.logString('team ONE score');
        console.logInt(matchScore[TEAM.ZERO]);
    }

    function _calcDepth(uint256, address) internal view virtual override returns (uint256) {
        return 3;
    }
}

contract ButtPlugForTest is IButtPlug {
    uint256 depth = 7;
    address buttPlugWars;
    address public owner;

    constructor(address _buttPlugWars) {
        buttPlugWars = _buttPlugWars;
        owner = msg.sender;
    }

    function setDepth(uint256 _depth) external {
        depth = _depth;
    }

    function readMove(uint256 _board) external view returns (uint256 _move) {
        (_move,) = Engine.searchMove(_board, depth);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';

import {IChess, IButtPlug} from 'interfaces/Game.sol';
import {LSSVMPair, ILSSVMPairFactory} from 'interfaces/Sudoswap.sol';
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
    address ETH_WHALE = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address FIVEOUTOFNINE_WHALE = 0xC5233C3b46C83ADEE1039D340094173f0f7c1EcF;
    address KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

        vm.startPrank(ETH_WHALE);
        payable(FIVEOUTOFNINE_WHALE).transfer(100 ether);
        vm.stopPrank();

        vm.startPrank(FIVEOUTOFNINE_WHALE);

        keep3r.bond(KP3R_V1, 0);
        vm.warp(block.timestamp + 3 days + 1);
        keep3r.activate(KP3R_V1);

        buttPlugWars = new ButtPlugWarsForTest();
        sudoPool = LSSVMPair(buttPlugWars.SUDOSWAP_POOL());
    }
}

contract ButtPlugWarsForTest is ButtPlugWars {
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
            _score += _calcScore(_board, _newBoard);
        }
        return (_score, 0, _initialGas - gasleft());
    }

    function logScore(int8 _score, uint8 _isCheckmate, uint256 _gasUsed) public view {
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
}

contract ButtPlugForTest is IButtPlug {
    uint256 depth = 10;
    address buttPlugWars;

    constructor(address _buttPlugWars) {
        buttPlugWars = _buttPlugWars;
    }

    function setDepth(uint256 _depth) external {
        depth = _depth;
    }

    function readMove(uint256 _board) external view returns (uint256 _move) {
        (_move,) = Engine.searchMove(_board, depth);
    }

    function claimHonor(uint256 _badgeID) external {
        ButtPlugWars(payable(buttPlugWars)).claimHonor(_badgeID);
    }

    function claimPrize(uint256 _badgeID) external {
        ButtPlugWars(payable(buttPlugWars)).claimPrize(_badgeID);
    }

    function withdrawPrize() external {
        ButtPlugWars(payable(buttPlugWars)).withdrawPrize();
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {console} from 'forge-std/console.sol';
import {IChess, IButtPlug} from 'interfaces/IGame.sol';
import {ButtPlugWars} from 'contracts/ButtPlugWars.sol';

contract ButtPlugWarsForTest is ButtPlugWars {
    constructor(ButtPlugWars.Registry memory _registry, uint32 _period, uint32 _cooldown)
        ButtPlugWars(_registry, _period, _cooldown)
    {}

    function getTeamButtPlug(uint8 _team) public view returns (address _buttPlug) {
        return buttPlug[TEAM(_team)];
    }

    function getScore(uint256 _badgeId) public view returns (int256 _score) {
        return _calcScore(_badgeId);
    }

    function getWeight(uint256 _badgeId) public pure returns (uint256 _weight) {
        return _getBadgeWeight(_badgeId);
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

    function _getDepth(uint256, address) internal view virtual override returns (uint256) {
        return 3;
    }
}

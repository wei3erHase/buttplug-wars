// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {IButtPlug} from 'interfaces/IGame.sol';
import {Engine} from 'fiveoutofnine/Engine.sol';

contract ButtPlugForTest is IButtPlug {
    uint256 depth = 7;
    address public owner;
    mapping(uint256 => uint256) knownMoves;

    constructor() {
        owner = msg.sender;
    }

    function setMove(uint256 _board, uint256 _move) external {
        knownMoves[_board] = _move;
    }

    function setDepth(uint256 _depth) external {
        depth = _depth;
    }

    function readMove(uint256 _board) external view returns (uint256 _move) {
        _move = knownMoves[_board];
        if (_move == 0) (_move,) = Engine.searchMove(_board, depth);
    }

    receive() external payable {}
}

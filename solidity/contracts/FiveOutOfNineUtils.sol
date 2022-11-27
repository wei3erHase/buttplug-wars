// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {Chess} from 'fiveoutofnine/Chess.sol';
import {Strings} from 'openzeppelin/utils/Strings.sol';

import {Math} from 'openzeppelin/utils/math/Math.sol';

library FiveOutOfNineUtils {
    using Math for uint256;
    using Chess for uint256;

    /*///////////////////////////////////////////////////////////////
                              FIVEOUTOFNINE
    //////////////////////////////////////////////////////////////*/

    function drawMove(uint256 _board, uint256 _fromIndex) internal pure returns (string memory) {
        string memory boardString = '```\n';

        if (_board & 1 == 0) _board = _board.rotate();
        else _fromIndex = ((7 - (_fromIndex >> 3)) << 3) + (7 - (_fromIndex & 7));

        for (uint256 index = 0x24A2CC34E4524D455665A6DC75E8628E4966A6AAECB6EC72CF4D76; index != 0; index >>= 6) {
            uint256 indexToDraw = index & 0x3F;
            boardString = string(
                abi.encodePacked(
                    boardString,
                    indexToDraw & 7 == 6 ? string(abi.encodePacked(Strings.toString((indexToDraw >> 3)), ' ')) : '',
                    indexToDraw == _fromIndex ? '*' : getPieceChar((_board >> (indexToDraw << 2)) & 0xF),
                    indexToDraw & 7 == 1 && indexToDraw != 9 ? '\n' : indexToDraw != 9 ? ' ' : ''
                )
            );
        }

        boardString = string(abi.encodePacked(boardString, '\n  a b c d e f\n```'));

        return boardString;
    }

    /// @notice Maps pieces to its corresponding unicode character.
    /// @param _piece A piece.
    /// @return The unicode character corresponding to `_piece`. It returns ``.'' otherwise.
    function getPieceChar(uint256 _piece) internal pure returns (string memory) {
        if (_piece == 1) return unicode'♟';
        if (_piece == 2) return unicode'♝';
        if (_piece == 3) return unicode'♜';
        if (_piece == 4) return unicode'♞';
        if (_piece == 5) return unicode'♛';
        if (_piece == 6) return unicode'♚';
        if (_piece == 9) return unicode'♙';
        if (_piece == 0xA) return unicode'♗';
        if (_piece == 0xB) return unicode'♖';
        if (_piece == 0xC) return unicode'♘';
        if (_piece == 0xD) return unicode'♕';
        if (_piece == 0xE) return unicode'♔';
        return unicode'·';
    }
}

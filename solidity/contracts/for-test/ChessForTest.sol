// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {IChess} from 'interfaces/IGame.sol';
import {ERC721, ERC721TokenReceiver} from 'isolmate/tokens/ERC721.sol';

contract ChessForTest is IChess, ERC721 {
    enum Board {
        NEW_BOARD,
        BLACK_CAPTURE,
        BOTH_CAPTURES
    }

    mapping(Board => uint256) boards;
    uint256 public totalSupply;
    bool public isCheckmate;

    uint256 constant INITIAL_SUPPLY = 10;

    /// @notice Chess is set to loop in: new board, +2 points, -1 point, +3 (checkmate = new board)
    constructor() ERC721('ChessForTest', unicode'♙') {
        boards[Board.NEW_BOARD] = 0x03256230011111100000000000000000099999900bcdecb000000001;
        boards[Board.BLACK_CAPTURE] = 0x03256230011011100000000000000000099999900bcdecb000000001;
        boards[Board.BOTH_CAPTURES] = 0x03256230011011100000000000000000099909900bcdecb000000001;
        for (uint256 _i; _i < INITIAL_SUPPLY; _i++) {
            _safeMint(msg.sender, _i);
        }
        totalSupply = INITIAL_SUPPLY;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {}

    function setCheckmate(bool _bool) external {
        isCheckmate = _bool;
    }

    function board() external view returns (uint256 _board) {
        if (isCheckmate) return boards[Board.NEW_BOARD];
        return boards[Board((totalSupply - INITIAL_SUPPLY) % 3)];
    }

    function mintMove(uint256, uint256) external payable {
        _mint(msg.sender, totalSupply);
        if (address(msg.sender).code.length != 0) {
            bytes memory _calldata;
            ERC721TokenReceiver(msg.sender).onERC721Received(address(0), address(0), totalSupply, _calldata);
        }
        ++totalSupply;
    }
}

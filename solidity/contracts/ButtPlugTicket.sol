pragma solidity >=0.8.4 <0.9.0;

import {ERC721} from 'isolmate/tokens/ERC721.sol';
import './ButtPlugWars.sol';

contract ButtPlugTicket is ERC721 {
    address immutable owner;
    // TODO: override transfer functions to modify supply
    uint256 public totalSupply;

    constructor() ERC721('ButtPlugTicket', unicode'♙') {
        owner = msg.sender;
    }

    function mint(address _receiver, ButtPlugWars.TEAM _team) external onlyGame returns (uint256 _ticketID) {
        _ticketID = ++totalSupply;
        _ticketID += uint256(_team) << 59;
        _mint(_receiver, _ticketID);
    }

    function burn(uint256 _ticketID) external onlyGame {
        totalSupply--;
        _burn(_ticketID);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {}

    error OnlyGame();

    modifier onlyGame() {
        if (msg.sender != owner) {
            revert OnlyGame();
        }
        _;
    }
}

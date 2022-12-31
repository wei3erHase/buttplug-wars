// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {ButtPlugWars} from '../ButtPlugWars.sol';

contract ChessOlympiadsForTest is ButtPlugWars {
    constructor(address _masterOfCeremony, address _chessForTest)
        ButtPlugWars('ChessOlympiadsForTest', _masterOfCeremony, _chessForTest, 2 minutes, 1 minutes)
    {}

    function reset() external {
        if (state != STATE.PRIZE_CEREMONY) revert WrongTiming();

        delete bunnySaysSo;
        delete canPlayNext;
        delete totalPrize;
        delete totalSales;
        delete matchMoves;
        delete matchesWon[TEAM.ZERO];
        delete matchesWon[TEAM.ONE];
        delete matchScore[TEAM.ZERO];
        delete matchScore[TEAM.ONE];

        state = STATE.TICKET_SALE;
    }
}

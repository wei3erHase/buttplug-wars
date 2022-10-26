// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {IChess, IButtPlug} from 'interfaces/Game.sol';
import {CommonE2EBase, ButtPlugForTest, console} from './Common.sol';

contract E2EButtPlug is CommonE2EBase {
    function test_E2E() public {
        IButtPlug _buttPlug = IButtPlug(new ButtPlugForTest(address(0)));

        uint256 DEPTH = 5;
        uint256 STEPS = 59;

        (int8 _score, uint8 _isCheckmate, uint256 _gasUsed) = buttPlugWars.simulateButtPlug(_buttPlug, DEPTH, STEPS);

        buttPlugWars.logScore(_score, _isCheckmate, _gasUsed);
    }
}

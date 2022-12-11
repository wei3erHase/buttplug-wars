// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {IChess, IButtPlug} from 'interfaces/IGame.sol';
import {CommonE2EBase, console} from './Common.sol';
import {ButtPlugForTest} from 'contracts/for-test/ButtPlugForTest.sol';

contract E2EButtPlug is CommonE2EBase {
    function skip_test_E2E() public {
        IButtPlug _buttPlug = IButtPlug(new ButtPlugForTest());

        uint256 DEPTH = 10;
        uint256 STEPS = 59;

        (int8 _score, uint8 _isCheckmate, uint256 _gasUsed) = game.simulateButtPlug(_buttPlug, DEPTH, STEPS);

        game.logSimulation(_score, _isCheckmate, _gasUsed);
    }
}

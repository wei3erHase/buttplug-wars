// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, ButtPlugWars, ButtPlugWarsForTest} from './Common.sol';

contract E2EButtPlugWars is CommonE2EBase {
    function test_E2E() public {
        fiveOutOfNine.setApprovalForAll(address(buttPlugWars), true);

        buttPlugWars.buyTicket{value: 0.5 ether}(190, ButtPlugWars.TEAM(0));
        buttPlugWars.pushLiquidity();

        vm.warp(block.timestamp + 1 days);
        ButtPlugWarsForTest(address(buttPlugWars)).workForTest();

        buttPlugWars.buyTicket{value: 0.2 ether}(191, ButtPlugWars.TEAM(0));
        buttPlugWars.buyTicket{value: 0.2 ether}(192, ButtPlugWars.TEAM(0));
        buttPlugWars.buyTicket{value: 0.1 ether}(193, ButtPlugWars.TEAM(0));
        vm.warp(block.timestamp + 3 days + 1);
        buttPlugWars.pushLiquidity();

        ButtPlugWarsForTest(address(buttPlugWars)).internalUnbondLiquidity();

        vm.warp(block.timestamp + 14 days + 1);

        buttPlugWars.withdrawLiquidity();
    }
}

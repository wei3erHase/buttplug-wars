// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, ButtPlugWars, ButtPlugWarsForTest, ButtPlugForTest, console} from './Common.sol';

contract E2EButtPlugWars is CommonE2EBase {
    function test_E2E() public {
        fiveOutOfNine.setApprovalForAll(address(buttPlugWars), true);

        uint256 badge1 = buttPlugWars.buyBadge{value: 0.9 ether}(190, ButtPlugWars.TEAM(0));
        uint256 badge2 = buttPlugWars.buyBadge{value: 0.9 ether}(191, ButtPlugWars.TEAM(0));

        buttPlugWars.buyBadge{value: 0.9 ether}(192, ButtPlugWars.TEAM(1));
        buttPlugWars.buyBadge{value: 0.9 ether}(193, ButtPlugWars.TEAM(1));

        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.pushLiquidity();

        ButtPlugForTest testButtPlug = new ButtPlugForTest();
        buttPlugWars.voteButtPlug(address(testButtPlug), badge1, 0);
        buttPlugWars.voteButtPlug(address(testButtPlug), badge2, 0);

        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.executeMove();

        // NOTE: brute forces 5/9 contract to reset to checkMate state somewhen
        for (uint256 _i; _i < 256; ++_i) {
            vm.warp(block.timestamp + 10 days + 1);
            if (buttPlugWars.state() == ButtPlugWars.STATE.GAME_ENDED) break;
            buttPlugWars.executeMove();
        }

        buttPlugWars.unbondLiquidity();
        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.claimPrize(badge1);
        buttPlugWars.withdrawLiquidity();

        buttPlugWars.withdrawPrize();
    }
}

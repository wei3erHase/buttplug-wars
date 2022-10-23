// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, ButtPlugWars, ButtPlugWarsForTest, ButtPlugForTest, IERC20, console} from './Common.sol';

contract E2EButtPlugWars is CommonE2EBase {
    function test_E2E() public {
        vm.warp(block.timestamp + 10 days);
        buttPlugWars.startEvent();

        // advances time to change random seed (avoids engine getting stuck)
        vm.warp(block.timestamp + 60 minutes);

        fiveOutOfNine.setApprovalForAll(address(buttPlugWars), true);

        uint256 badge1 = buttPlugWars.buyBadge{value: 0.99 ether}(190, ButtPlugWars.TEAM(0));
        uint256 badge2 = buttPlugWars.buyBadge{value: 0.5 ether}(191, ButtPlugWars.TEAM(1));
        uint256 badge3 = buttPlugWars.buyBadge{value: 0.25 ether}(192, ButtPlugWars.TEAM(1));
        uint256 badge4 = buttPlugWars.buyBadge{value: 0.25 ether}(193, ButtPlugWars.TEAM(1));

        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.pushLiquidity();

        ButtPlugForTest testButtPlug = new ButtPlugForTest();
        buttPlugWars.voteButtPlug(address(testButtPlug), badge1, 0);
        buttPlugWars.voteButtPlug(address(testButtPlug), badge2, 0);

        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.executeMove();

        // NOTE: brute forces 5/9 contract to reset to checkMate state somewhen
        for (uint256 _i; _i < 512; ++_i) {
            vm.warp(block.timestamp + 10 days - 1);
            if (buttPlugWars.state() == ButtPlugWars.STATE.GAME_ENDED) break;
            buttPlugWars.executeMove();
        }

        uint256 liquidityAmount = keep3r.liquidityAmount(address(buttPlugWars), KP3R_LP);

        buttPlugWars.unbondLiquidity();
        vm.warp(block.timestamp + 14 days + 1);
        address badgeOwner = buttPlugWars.ownerOf(badge1);
        buttPlugWars.claimPrize(badge1);
        buttPlugWars.withdrawLiquidity();

        buttPlugWars.withdrawPrize();
        uint256 liquidityWithdrawn = IERC20(KP3R_LP).balanceOf(badgeOwner);

        assertEq(liquidityAmount, liquidityWithdrawn);
    }
}

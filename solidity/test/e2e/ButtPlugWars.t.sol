// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, ButtPlugWars, ButtPlugWarsForTest, ButtPlugForTest, IERC20, console} from './Common.sol';
import {ILSSVMRouter} from 'interfaces/Sudoswap.sol';

contract E2EButtPlugWars is CommonE2EBase {
    function test_E2E() public {
        vm.warp(block.timestamp + 10 days);
        buttPlugWars.startEvent();

        fiveOutOfNine.setApprovalForAll(address(buttPlugWars), true);

        uint256 badge1 = buttPlugWars.buyBadge{value: 0.99 ether}(183, ButtPlugWars.TEAM(0));
        uint256 badge2 = buttPlugWars.buyBadge{value: 0.5 ether}(184, ButtPlugWars.TEAM(0));
        uint256 badge3 = buttPlugWars.buyBadge{value: 0.25 ether}(185, ButtPlugWars.TEAM(1));
        uint256 badge4 = buttPlugWars.buyBadge{value: 0.25 ether}(186, ButtPlugWars.TEAM(1));
        uint256 badge5 = buttPlugWars.buyBadge{value: 0.25 ether}(187, ButtPlugWars.TEAM(1));
        {
            (bool _success, bytes memory _return) = payable(address(buttPlugWars)).call{value: 10 ether}('');
        }

        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.pushLiquidity();

        ButtPlugForTest testButtPlug = new ButtPlugForTest(address(buttPlugWars));
        uint256 _buttPlugBadgeId_A = uint256(uint160(address(testButtPlug))) << 69 + 0 << 59;
        uint256 _buttPlugBadgeId_B = uint256(uint160(address(testButtPlug))) << 69 + 1 << 59;

        buttPlugWars.voteButtPlug(address(testButtPlug), badge1, 0);
        buttPlugWars.voteButtPlug(address(testButtPlug), badge2, 0);
        buttPlugWars.voteButtPlug(address(testButtPlug), badge3, 0);

        // votes EOA as nftDescriptorPlug
        buttPlugWars.voteNftDescriptorPlug(FIVEOUTOFNINE_WHALE, badge1);

        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.executeMove();

        // NOTE: brute forces 5/9 contract to reset to checkMate state somewhen
        for (uint256 _i; _i < 256; ++_i) {
            vm.warp(block.timestamp + 9 days);
            if (buttPlugWars.getState() == ButtPlugWars.STATE.GAME_OVER) break;
            buttPlugWars.executeMove();
        }

        uint256 badge6;
        {
            badge6 = buttPlugWars.buyBadge{value: 0.25 ether}(188, ButtPlugWars.TEAM(1));

            ILSSVMRouter.PairSwapAny[] memory _swapList = new ILSSVMRouter.PairSwapAny[](1);
            _swapList[0] = ILSSVMRouter.PairSwapAny(sudoPool, 5);

            ILSSVMRouter(0x844d04f79D2c58dCeBf8Fff1e389Fccb1401aa49).swapETHForAnyNFTs{value: 10 ether}(
                _swapList, payable(FIVEOUTOFNINE_WHALE), FIVEOUTOFNINE_WHALE, block.timestamp
            );
        }

        buttPlugWars.pushLiquidity();

        buttPlugWars.voteButtPlug(address(69), badge3, 0);
        for (uint256 _i; _i < 256; ++_i) {
            vm.warp(block.timestamp + 9 days);
            if (buttPlugWars.getState() == ButtPlugWars.STATE.GAME_OVER) break;
            buttPlugWars.executeMove();
        }

        uint256 liquidityAmount = keep3r.liquidityAmount(address(buttPlugWars), KP3R_LP);

        buttPlugWars.unbondLiquidity();
        vm.warp(block.timestamp + 14 days + 1);
        address badgeOwner = buttPlugWars.ownerOf(badge1);

        // Prize claim
        buttPlugWars.claimPrize(badge1);
        buttPlugWars.claimPrize(badge2);
        // Honor claim

        buttPlugWars.claimHonor(badge3);
        buttPlugWars.claimHonor(badge4);
        buttPlugWars.claimHonor(badge5);
        // buttPlugWars.claimHonor(badge6);

        testButtPlug.claimHonor(_buttPlugBadgeId_A);
        // testButtPlug.claimHonor(_buttPlugBadgeId_B);

        /**
         * NOTE: reverts if keeper badge for msg.sender is already claimed
         *     buttPlugWars.claimHonor(STAFF_BADGE);
         *     vm.stopPrank();
         */
        buttPlugWars.withdrawLiquidity();
        // vm.startPrank(FIVEOUTOFNINE_WHALE);

        // Prize distribution

        buttPlugWars.withdrawPrize();

        uint256 liquidityWithdrawn = IERC20(KP3R_LP).balanceOf(badgeOwner);

        assertLt(liquidityAmount - liquidityWithdrawn, 100, 'all liquidity was distributed');

        // Honor distribution
        buttPlugWars.withdrawHonor();
        testButtPlug.withdrawHonor();

        uint256 _remaining = address(buttPlugWars).balance;
        assertLt(_remaining, 100, 'all sales were distributed');

        buttPlugWars.updateSpotPrice();
        {
            ILSSVMRouter.PairSwapAny[] memory _swapList = new ILSSVMRouter.PairSwapAny[](1);
            _swapList[0] = ILSSVMRouter.PairSwapAny(sudoPool, 5);

            ILSSVMRouter(0x844d04f79D2c58dCeBf8Fff1e389Fccb1401aa49).swapETHForAnyNFTs{value: 10 ether}(
                _swapList, payable(FIVEOUTOFNINE_WHALE), FIVEOUTOFNINE_WHALE, block.timestamp
            );
        }

        _remaining = address(buttPlugWars).balance;
        assertGt(_remaining, 100, 'more sales to be distributed');
        buttPlugWars.withdrawHonor();
        testButtPlug.withdrawHonor();
        _remaining = address(buttPlugWars).balance;
        assertLt(_remaining, 100, 'all sales were distributed');
    }
}

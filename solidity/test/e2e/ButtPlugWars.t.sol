// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, ButtPlugWars, ButtPlugWarsForTest, ButtPlugForTest, IERC20, console} from './Common.sol';
import {ILSSVMRouter} from 'interfaces/Sudoswap.sol';

contract E2EButtPlugWars is CommonE2EBase {
    function test_E2E() public {
        vm.warp(block.timestamp + 10 days);

        uint256 genesis = IERC20(address(chess)).totalSupply();
        buttPlugWars.startEvent();

        // some NFTs are minted post game start
        // performs a checkmate to restart the board
        chess.mintMove((10 << 6) | 25, 3); // g
        chess.mintMove((13 << 6) | 30, 3); // g + 1
        chess.mintMove((20 << 6) | 28, 3); // g + 2
        chess.mintMove((12 << 6) | 28, 3); // g + 3
        chess.mintMove((28 << 6) | 42, 3); // g + 4

        {
            assertEq(chess.board(), 0x3256230011111100000000000000000099999900BCDECB000000001);
        }

        fiveOutOfNine.setApprovalForAll(address(buttPlugWars), true);

        // uses pre-genesis 5/9s to mint badges
        uint256 badge1 = buttPlugWars.mintPlayerBadge{value: 1 ether}(183, ButtPlugWars.TEAM(0));
        uint256 badge2 = buttPlugWars.mintPlayerBadge{value: 0.25 ether}(184, ButtPlugWars.TEAM(0));
        uint256 badge3 = buttPlugWars.mintPlayerBadge{value: 0.25 ether}(185, ButtPlugWars.TEAM(0));
        uint256 badge4 = buttPlugWars.mintPlayerBadge{value: 0.25 ether}(186, ButtPlugWars.TEAM(0));
        vm.expectRevert(ButtPlugWars.WrongNFT.selector);
        buttPlugWars.mintPlayerBadge{value: 0.25 ether}(genesis, ButtPlugWars.TEAM(0));

        // checks value limits
        vm.expectRevert(ButtPlugWars.WrongValue.selector);
        buttPlugWars.mintPlayerBadge{value: 0.05 ether - 1}(187, ButtPlugWars.TEAM(1));
        vm.expectRevert(ButtPlugWars.WrongValue.selector);
        buttPlugWars.mintPlayerBadge{value: 1 ether + 1}(187, ButtPlugWars.TEAM(1));
        uint256 badge5 = buttPlugWars.mintPlayerBadge{value: 0.5 ether + 1}(187, ButtPlugWars.TEAM(0));

        {
            // ETH is artificially added to increase liquidity
            (bool _success, bytes memory _return) = payable(address(buttPlugWars)).call{value: 10 ether}('');
        }

        vm.warp(block.timestamp + 14 days + 1);
        buttPlugWars.pushLiquidity();

        ButtPlugForTest testButtPlug = new ButtPlugForTest(address(buttPlugWars));
        uint256 _buttPlugBadgeId_ZERO = buttPlugWars.mintButtPlugScoreBadge(address(testButtPlug), ButtPlugWars.TEAM(0));
        uint256 _buttPlugBadgeId_ONE = buttPlugWars.mintButtPlugScoreBadge(address(testButtPlug), ButtPlugWars.TEAM(1));

        /**
         * Quadratic voting mechanism
         * each badge has a weight of sqrt(value)
         * (a) sqrt(1 eth) = sqrt(0.25) + sqrt(0.25)
         *     1 gwei = 0.5 + 0.5
         * (b) sqrt(1 eth) > sqrt(0.25) * 2
         *     1 gwei > 0.5 * 2
         * (c) sqrt(1 eth) + sqrt(0.25) > 2 * sqrt(0.25) + sqrt(0.5)
         *     1.5 gwei < 1.7 gwei
         */

        // (a)
        buttPlugWars.voteButtPlug(address(testButtPlug), badge1); // 1 eth
        buttPlugWars.voteButtPlug(address(69), badge2); // 0.25 eth
        buttPlugWars.voteButtPlug(address(69), badge3); // 0.25 eth
        assertEq(ButtPlugWarsForTest(buttPlugWars).getTeamButtPlug(0), address(testButtPlug), '(a)');

        // (b)
        buttPlugWars.voteButtPlug(address(69), badge4); // 0.25 eth
        assertEq(ButtPlugWarsForTest(buttPlugWars).getTeamButtPlug(0), address(69), '(b)');

        // (c)
        buttPlugWars.voteButtPlug(address(testButtPlug), badge5); // 0.25 eth
        assertEq(ButtPlugWarsForTest(buttPlugWars).getTeamButtPlug(0), address(testButtPlug), '(c)');

        vm.expectRevert(bytes('Bonding curve error'));
        _purchaseAtSudoswap(1);

        vm.warp(block.timestamp + 10 days + 1);
        uint256 postGenesis = IERC20(address(chess)).totalSupply();
        buttPlugWars.executeMove(); // g + 4

        // purchases 5/9 from official pool
        _purchaseAtSudoswap(1);

        // // move-minted before genesis can mint badge
        uint256 preGenToken = buttPlugWars.mintPlayerBadge{value: 0.25 ether}(genesis - 1, ButtPlugWars.TEAM(1));
        buttPlugWars.voteButtPlug(address(testButtPlug), preGenToken);

        // move minted after genesis cannot mint badge
        vm.expectRevert(ButtPlugWars.WrongNFT.selector);
        buttPlugWars.mintPlayerBadge{value: 0.25 ether}(genesis, ButtPlugWars.TEAM(0));
        // move minted during game can mint badge
        buttPlugWars.mintPlayerBadge{value: 0.25 ether}(postGenesis, ButtPlugWars.TEAM(0));
        // eth collected in sales is pushed as liquidity
        uint256 _previousLiquidity = keep3r.liquidityAmount(address(buttPlugWars), KP3R_LP);
        buttPlugWars.pushLiquidity();
        assertGt(keep3r.liquidityAmount(address(buttPlugWars), KP3R_LP), _previousLiquidity);

        // until move ~16 the buttPlug has a positive score
        _forceBruteChess(16);
        _purchaseAtSudoswap(16);
        buttPlugWars.voteButtPlug(address(420), preGenToken);
        assertEq(ButtPlugWarsForTest(buttPlugWars).getTeamButtPlug(1), address(420), '420');

        _forceBruteChess(2056);

        uint256 liquidityAmount = keep3r.liquidityAmount(address(buttPlugWars), KP3R_LP);

        buttPlugWars.unbondLiquidity();
        vm.warp(block.timestamp + 14 days + 1);
        address badgeOwner = buttPlugWars.ownerOf(badge1);

        // Prize claim
        buttPlugWars.claimPrize(badge1);
        // Honor claim
        buttPlugWars.claimHonor(preGenToken);
        buttPlugWars.claimHonor(_buttPlugBadgeId_ZERO);
        buttPlugWars.claimHonor(_buttPlugBadgeId_ONE);
        buttPlugWars.withdrawLiquidity();

        // Prize distribution

        buttPlugWars.withdrawPrize();

        uint256 liquidityWithdrawn = IERC20(KP3R_LP).balanceOf(badgeOwner);

        assertLt(liquidityAmount - liquidityWithdrawn, 100, 'all liquidity was distributed');

        // Honor distribution
        buttPlugWars.withdrawHonor();
        buttPlugWars.withdrawHonor();
        uint256 _remaining = address(buttPlugWars).balance;
        assertLt(_remaining, 100, 'all sales were distributed');

        // Can update spotPrice
        buttPlugWars.updateSpotPrice();
        vm.expectRevert(ButtPlugWars.WrongTiming.selector);
        buttPlugWars.updateSpotPrice();
        vm.warp(block.timestamp + 59 days);
        buttPlugWars.updateSpotPrice();

        // Honor re-distribution
        _purchaseAtSudoswap(1);
        _remaining = address(buttPlugWars).balance;
        assertGt(_remaining, 100, 'more sales to be distributed');
        buttPlugWars.withdrawHonor();
        buttPlugWars.withdrawHonor();
        _remaining = address(buttPlugWars).balance;
        assertLt(_remaining, 100, 'all sales were distributed');
    }

    function _purchaseAtSudoswap(uint256 _amount) internal {
        ILSSVMRouter.PairSwapAny[] memory _swapList = new ILSSVMRouter.PairSwapAny[](1);
        _swapList[0] = ILSSVMRouter.PairSwapAny(sudoPool, _amount);

        ILSSVMRouter(0x844d04f79D2c58dCeBf8Fff1e389Fccb1401aa49).swapETHForAnyNFTs{value: 10 ether}(
            _swapList, payable(FIVEOUTOFNINE_WHALE), FIVEOUTOFNINE_WHALE, block.timestamp
        );
    }

    function _forceBruteChess(uint256 _times) internal {
        for (uint256 _i; _i < _times; ++_i) {
            // loads credits to execute
            vm.warp(block.timestamp + 5 days);

            // buttPlugWars.logMatchScore();
            if (buttPlugWars.getState() == ButtPlugWars.STATE.GAME_OVER) break;

            if (chess.board() == 0x3256230011111100000000000000000099999900BCDECB000000001) buttPlugWars.logGameScore();

            buttPlugWars.executeMove();
        }
    }
}

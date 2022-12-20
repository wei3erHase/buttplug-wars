// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, ButtPlugWars, ButtPlugWarsForTest, IERC20, ERC721, console} from './Common.sol';

import {ChessForTest} from 'contracts/for-test/ChessForTest.sol';
import {ButtPlugForTest} from 'contracts/for-test/ButtPlugForTest.sol';

contract E2EButtPlugWars is CommonE2EBase {
    function test_E2E() public {
        {
            chess = new ChessForTest();

            game = new ButtPlugWarsForTest(ButtPlugWars.Registry({
              masterOfCeremony: FIVEOUTOFNINE_WHALE,
              fiveOutOfNine: address(chess),
              weth: WETH_9,
              kp3rV1: KP3R_V1,
              keep3rLP: KP3R_LP,
              keep3r: address(keep3r),
              uniswapRouter: UNISWAP_ROUTER,
              sudoswapFactory: SUDOSWAP_FACTORY,
              sudoswapCurve:SUDOSWAP_XYK_CURVE
            }), 5 days, 0);

            ERC721(address(chess)).setApprovalForAll(address(game), true);
        }

        vm.warp(block.timestamp + 10 days);

        game.startEvent();

        uint256 alice = game.mintPlayerBadge{value: 1 ether}(0);
        uint256 bob = game.mintPlayerBadge{value: 0.64 ether}(1);
        uint256 carl = game.mintPlayerBadge{value: 0.16 ether}(2);

        {
            assertEq(game.getWeight(alice), 1000e6);
            assertEq(game.getWeight(bob), 800e6);
            assertEq(game.getWeight(carl), 400e6);
        }

        {
            // ETH is artificially added to increase liquidity
            (bool _success, bytes memory _return) = payable(address(game)).call{value: 10 ether}('');
            vm.warp(block.timestamp + 14 days + 1);
            game.pushLiquidity();
        }

        ButtPlugForTest buttPlugA = new ButtPlugForTest();
        uint256 _buttPlugABadge = game.mintButtPlugBadge(address(buttPlugA));

        /*
        * Alice, Bob and Carl mint 3 badges with different weights and vote on buttPlugA
        * The weight of each badge is determined by the sqrt(msg.value)
        * Alice: 1eth => 1000 mWeis
        * Bob: 0.64eth => 800 mWeis
        * Carl: 0.16 eth => 400 mWeis
        * The participation is determined by the percentage of the voting weight at the time of voting
        * When Alice votes, there is no previous voting weight, so she gets 100% participation
        * When Bob votes, his participation is calculated by wBob / wButtplug (Bob + Alice)
        */

        // Alice participation = 1000 / 1000 = 100%
        game.voteButtPlug(address(buttPlugA), alice);
        // Bob participation = 800 / 1800 = 44.44%
        game.voteButtPlug(address(buttPlugA), bob);
        // Carl participation = 400 / 2200 = 18.18%
        game.voteButtPlug(address(buttPlugA), carl);

        // Badges can only be minted from the not-playing team
        vm.warp(block.timestamp + 5 days);
        // Only 1 match will be played
        game.saySo();

        game.executeMove(); // Move 1 (+2)

        int256 buttPlugScore = game.getScore(_buttPlugABadge);
        int256 aliceScore = game.getScore(alice);
        int256 bobScore = game.getScore(bob);
        int256 carlScore = game.getScore(carl);

        assertEq(buttPlugScore, int256(2200e6) * 2); // First move is +2
        assertEq(buttPlugScore, aliceScore); // Alice has 100% participation
        assertEq(buttPlugScore, bobScore * 10_000 / 4444); // Bob has 44.44%
        assertEq(buttPlugScore, carlScore * 10_000 / 1818); // Carl has 18.18%

        // Deploy new buttplug
        ButtPlugForTest buttPlugB = new ButtPlugForTest();
        uint256 _buttPlugBBadge = game.mintButtPlugBadge(address(buttPlugB));

        game.voteButtPlug(address(buttPlugB), carl); // Carl has 100% participation

        vm.warp(block.timestamp + 10 days);
        game.executeMove(); // Move 2 (-1)

        buttPlugScore = game.getScore(_buttPlugABadge);
        assertEq(buttPlugScore, (int256(2200e6) * 2) + int256(1800e6) * (-1)); // Second move is -1
        aliceScore = game.getScore(alice);
        assertEq(buttPlugScore, aliceScore);

        assertEq(game.getScore(_buttPlugBBadge), 0); // Buttplug B didn't score any points
        assertEq(carlScore, game.getScore(carl)); // Carl didn't score any points

        game.voteButtPlug(address(buttPlugB), bob); // Bob has 66.66% participation

        bobScore = game.getScore(bob);
        vm.warp(block.timestamp + 10 days);
        game.executeMove(); // Move 3 (+3)

        buttPlugScore = game.getScore(_buttPlugBBadge);
        assertEq(aliceScore, game.getScore(alice)); // Alice didn't score any points
        assertEq(buttPlugScore, (game.getScore(bob) - bobScore) * 10_000 / 6666);

        /* SCORING CHECKS */
        {
            /**
             * Alice score
             * Move 1: Alice had 100% of buttPlug A with (a+b+c) = 2200 * 2
             * Move 2: 100% of buttPlug A w/ (a+b) = 1800 - 1
             * Move 3: 0
             * Total: 2600
             */
            aliceScore = game.getScore(alice);
            assertEq(aliceScore, 2600e6);

            /**
             * Bob score
             * Move 1: Bob had 44.44% of buttPlug A = 2200 * 2 * 44.44% = 1955
             * Move 2: Bob had 44.44% of buttPlug A = 1800 * -1 * 44.44% = 799
             * Move 3: Bob had 66.66% of buttPlug B (b+c) = 1200 * 3 * 66.66% = 2399
             * Total: 3555
             */
            bobScore = game.getScore(bob);
            assertLt(bobScore, 3556e6);
            assertGt(bobScore, 3555e6);

            /**
             * Carl score
             * Move 1: Carl had 18.18% of buttPlug A = 2200 * 2 * 18.18% = 799
             * Move 2: 0
             * Move 3: Carl had 100% of buttPlug B (b+c) = 1200 * 3 = 3600
             * Total: 4399
             */
            carlScore = game.getScore(carl);
            assertLt(carlScore, 4400e6);
            assertGt(carlScore, 4399e6);
        }

        game.unbondLiquidity(); // starts medal minting
        uint256 medal;

        {
            uint256[] memory _badgeIds = new uint256[](3);
            _badgeIds[0] = alice;
            _badgeIds[1] = bob;
            _badgeIds[2] = carl;

            medal = game.mintMedal(_badgeIds);
        }

        assertEq(game.getScore(medal), aliceScore + bobScore + carlScore);
        {
            uint256 medalWeight;
            medalWeight += game.getWeight(alice);
            medalWeight += game.getWeight(bob);
            medalWeight += game.getWeight(carl);
            assertEq(game.getWeight(medal), medalWeight);
        }
    }
}

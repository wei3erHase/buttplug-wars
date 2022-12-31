// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, ButtPlugWars, ButtPlugWarsForTest, ERC721, console} from './Common.sol';
import {ERC20} from 'solmate/tokens/ERC20.sol';

import {GameSchema} from 'contracts/GameSchema.sol';
import {ButtPlugForTest} from 'contracts/for-test/ButtPlugForTest.sol';
import {ILSSVMRouter} from 'interfaces/ISudoswap.sol';

contract E2EButtPlugWars is CommonE2EBase {
    function testRoadmap_E2E() public {
        vm.warp(block.timestamp + 15 days); // offsets time to select the test team

        uint256 genesis = ERC20(address(chess)).totalSupply();
        game.startEvent();

        // some NFTs are minted post game start
        // performs a checkmate to restart the board
        chess.mintMove((10 << 6) | 25, 3); // g
        chess.mintMove((13 << 6) | 30, 3); // g + 1
        chess.mintMove((20 << 6) | 28, 3); // g + 2
        chess.mintMove((12 << 6) | 28, 3); // g + 3
        chess.mintMove((28 << 6) | 42, 3); // g + 4

        fiveOutOfNine.setApprovalForAll(address(game), true);

        // uses pre-genesis 5/9s to mint badges
        uint256 badge1 = game.mintPlayerBadge{value: 1 ether}(183);
        uint256 badge2 = game.mintPlayerBadge{value: 0.25 ether}(184);
        uint256 badge3 = game.mintPlayerBadge{value: 0.25 ether}(185);
        uint256 badge4 = game.mintPlayerBadge{value: 0.25 ether}(186);

        // postGenesis tokens are not whitelisted
        vm.expectRevert(GameSchema.WrongNFT.selector);
        game.mintPlayerBadge{value: 0.25 ether}(genesis);

        uint256[] memory _badgesBatch = new uint256[](2);
        _badgesBatch[0] = badge2;
        _badgesBatch[1] = badge3;

        // checks value limits
        vm.expectRevert(GameSchema.WrongValue.selector);
        game.mintPlayerBadge{value: 0.05 ether - 1}(187);
        vm.expectRevert(GameSchema.WrongValue.selector);
        game.mintPlayerBadge{value: 1 ether + 1}(187);
        uint256 badge5 = game.mintPlayerBadge{value: 0.5 ether}(187);

        {
            // ETH is artificially added to increase liquidity
            payable(address(game)).call{value: 10 ether}('');
            vm.warp(block.timestamp + 14 days + 1);
            game.pushLiquidity();
        }

        ButtPlugForTest testButtPlug = new ButtPlugForTest();
        uint256 _buttPlugBadgeId = game.mintButtPlugBadge(address(testButtPlug));

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
        game.voteButtPlug(address(testButtPlug), badge1); // 1 eth
        game.voteButtPlug(address(69), badge2); // 0.25 eth
        game.voteButtPlug(address(69), badge3); // 0.25 eth
        game.voteButtPlug(address(69), _badgesBatch);
        assertEq(ButtPlugWarsForTest(game).getTeamButtPlug(1), address(testButtPlug), '(a)');

        // (b)
        game.voteButtPlug(address(69), badge4); // 0.25 eth
        assertEq(ButtPlugWarsForTest(game).getTeamButtPlug(1), address(69), '(b)');

        // (c)
        game.voteButtPlug(address(testButtPlug), badge5); // 0.25 eth
        assertEq(ButtPlugWarsForTest(game).getTeamButtPlug(1), address(testButtPlug), '(c)');

        // no tokens have been added to the pool yet
        vm.expectRevert(bytes('Bonding curve error'));
        _purchaseAtSudoswap(1);

        vm.warp(block.timestamp + 5 days + 1);
        uint256 postGenesis = ERC20(address(chess)).totalSupply();
        game.executeMove();

        // purchases 5/9 from official pool
        _purchaseAtSudoswap(1);

        // move-minted before genesis can mint badge
        uint256 preGenToken = game.mintPlayerBadge{value: 0.25 ether}(genesis - 1);
        game.voteButtPlug(address(testButtPlug), preGenToken);

        // move minted after genesis cannot mint badge
        vm.expectRevert(GameSchema.WrongNFT.selector);
        game.mintPlayerBadge{value: 0.25 ether}(genesis);

        // move minted during game can mint badge
        vm.warp(block.timestamp + 5 days); // other team badge
        game.mintPlayerBadge{value: 0.25 ether}(postGenesis);

        // eth collected in sales is pushed as liquidity
        uint256 _previousLiquidity = keep3r.liquidityAmount(address(game), KP3R_LP);
        game.pushLiquidity();
        assertGt(keep3r.liquidityAmount(address(game), KP3R_LP), _previousLiquidity);

        /// @dev until move ~16 the buttPlug has a positive score
        _forceBruteChess(16);
        _purchaseAtSudoswap(16);

        /// @dev forces game to finish because of match move limit
        _forceBruteChess(2056);

        {
            uint256 liquidityAmount = keep3r.liquidityAmount(address(game), KP3R_LP);

            game.unbondLiquidity();
            vm.warp(block.timestamp + 14 days + 1);
            address badgeOwner = game.ownerOf(badge1);

            uint256 _medal1;
            uint256 _medal2;

            // Preparations
            uint256[] memory _badgeList = new uint256[](2);
            _badgeList[0] = badge1;
            _badgeList[1] = preGenToken;
            _medal1 = game.mintMedal(_badgeList);

            _badgeList[0] = badge2;
            _badgeList[1] = _buttPlugBadgeId;
            _medal2 = game.mintMedal(_badgeList);

            // Prize ceremony
            game.withdrawLiquidity();

            // Prize distribution
            ERC20(KP3R_LP).balanceOf(address(game));
            game.withdrawRewards(_medal1);
            game.withdrawRewards(_medal2);

            uint256 liquidityWithdrawn = ERC20(KP3R_LP).balanceOf(badgeOwner);
            assertLt(liquidityAmount - liquidityWithdrawn, 100, 'all liquidity was distributed');

            uint256 _remaining = address(game).balance;
            assertLt(_remaining, 100, 'all sales were distributed');

            // Can update spotPrice
            game.updateSpotPrice();
            vm.expectRevert(GameSchema.WrongTiming.selector);
            game.updateSpotPrice();
            vm.warp(block.timestamp + 5 days);
            game.updateSpotPrice();

            // Honor re-distribution
            _purchaseAtSudoswap(1);
            _remaining = address(game).balance;
            assertGt(_remaining, 100, 'more sales to be distributed');
            game.withdrawRewards(_medal1);
            game.withdrawRewards(_medal2);
            _remaining = address(game).balance;
            assertLt(_remaining, 100, 'all sales were distributed');

            game.tokenURI(_medal1);
        }

        assertEq(ERC721(address(chess)).ownerOf(187), address(game));
        game.withdrawStakedNft(badge5);
        assertEq(ERC721(address(chess)).ownerOf(187), FIVEOUTOFNINE_WHALE);

        game.tokenURI(badge1);
        game.tokenURI(_buttPlugBadgeId);
    }

    function _purchaseAtSudoswap(uint256 _amount) internal {
        ILSSVMRouter.PairSwapAny[] memory _swapList = new ILSSVMRouter.PairSwapAny[](1);
        _swapList[0] = ILSSVMRouter.PairSwapAny(sudoPool, _amount);

        ILSSVMRouter(0x844d04f79D2c58dCeBf8Fff1e389Fccb1401aa49).swapETHForAnyNFTs{value: 5 ether}(
            _swapList, payable(FIVEOUTOFNINE_WHALE), FIVEOUTOFNINE_WHALE, block.timestamp
        );
    }

    function _forceBruteChess(uint256 _times) internal {
        for (uint256 _i; _i < _times; ++_i) {
            // loads credits to execute
            vm.warp(block.timestamp + 5 days);
            if (game.state() == GameSchema.STATE.GAME_OVER) break;
            game.executeMove();
        }
    }
}

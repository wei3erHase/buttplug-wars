// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';

import {IChess, IButtPlug} from 'interfaces/Game.sol';
import {ButtPlugBadgeDescriptor} from 'contracts/BadgeNFTSvg.sol';

contract UnitButtPlugDescriptor is DSTestFull, ButtPlugBadgeDescriptor {
    ButtPlugParams _params = ButtPlugParams({badgeId: 1, weight: 2, firstSeen: 3, score: 4});

    function test_Unit() public {
        console.log(_generateSVG(_params));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';

import {LSSVMPair} from 'interfaces/ILSSVMPairFactory.sol';
import {ButtPlugWars, IKeep3r} from 'contracts/ButtPlugWars.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {ERC721} from 'isolmate/tokens/ERC721.sol';

contract CommonE2EBase is DSTestFull {
    uint256 constant FORK_BLOCK = 15730000;

    address user = label('user');
    address owner = label('owner');
    ButtPlugWars buttPlugWars;
    ERC721 fiveOutOfNine = ERC721(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    IKeep3r keep3r = IKeep3r(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
    LSSVMPair sudoPool;
    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
        vm.startPrank(0xC5233C3b46C83ADEE1039D340094173f0f7c1EcF);

        keep3r.bond(KP3R_V1, 0);
        vm.warp(block.timestamp + 3 days + 1);
        keep3r.activate(KP3R_V1);

        buttPlugWars = new ButtPlugWarsForTest();
        sudoPool = LSSVMPair(buttPlugWars.SUDOSWAP_POOL());
    }
}

contract ButtPlugWarsForTest is ButtPlugWars {
    function setState(STATE _state) external {
        state = _state;
    }

    function internalUnbondLiquidity() external {
        _unbondLiquidity();
    }

    function workForTest() external {
        IKeep3r(KEEP3R).isKeeper(0x99D281c0bf62B7062387C88D27e4D00669E748C6);
        IKeep3r(KEEP3R).worked(0x99D281c0bf62B7062387C88D27e4D00669E748C6);
    }
}

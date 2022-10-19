// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';

import {IChess} from 'interfaces/Game.sol';
import {LSSVMPair, ILSSVMPairFactory} from 'interfaces/Sudoswap.sol';
import {ButtPlugWars, IKeep3r} from 'contracts/ButtPlugWars.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {ERC721} from 'isolmate/tokens/ERC721.sol';
import {Engine} from 'fiveoutofnine-chess/Engine.sol';

contract CommonE2EBase is DSTestFull {
    uint256 constant FORK_BLOCK = 15730000;

    address user = label('user');
    address owner = label('owner');
    ButtPlugWars buttPlugWars;
    ERC721 fiveOutOfNine = ERC721(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    IKeep3r keep3r = IKeep3r(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
    LSSVMPair sudoPool;
    IChess chess = IChess(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address ETH_WHALE = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address FIVEOUTOFNINE_WHALE = 0xC5233C3b46C83ADEE1039D340094173f0f7c1EcF;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

        vm.startPrank(ETH_WHALE);
        payable(FIVEOUTOFNINE_WHALE).transfer(100 ether);
        vm.stopPrank();

        vm.startPrank(FIVEOUTOFNINE_WHALE);

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
}

contract ButtPlugForTest {
    uint256 depth = 3;

    function setDepth(uint256 _depth) external {
        depth = _depth;
    }

    function readMove(uint256 _board) external view returns (uint256 _move) {
        (_move,) = Engine.searchMove(_board, depth);
    }
}

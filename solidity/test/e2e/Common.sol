// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';

import {IChess, IButtPlug} from 'interfaces/IGame.sol';
import {LSSVMPair, ILSSVMPairFactory} from 'interfaces/ISudoswap.sol';
import {ButtPlugWars, IKeep3r} from 'contracts/ButtPlugWars.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {ERC721} from 'isolmate/tokens/ERC721.sol';

import {ButtPlugWarsForTest} from 'contracts/for-test/ButtPlugWarsForTest.sol';

contract CommonE2EBase is DSTestFull {
    uint256 constant FORK_BLOCK = 15730000;

    address user = label('user');
    address owner = label('owner');
    ButtPlugWarsForTest game;
    ERC721 fiveOutOfNine = ERC721(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    IKeep3r keep3r = IKeep3r(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
    LSSVMPair sudoPool;
    IChess chess = IChess(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    address constant KP3R_V1 = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;
    address constant ETH_WHALE = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address constant FIVEOUTOFNINE_WHALE = 0xC5233C3b46C83ADEE1039D340094173f0f7c1EcF;
    address constant KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;
    address constant WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant SUDOSWAP_FACTORY = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    address constant SUDOSWAP_XYK_CURVE = 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

        vm.startPrank(ETH_WHALE);
        payable(FIVEOUTOFNINE_WHALE).transfer(100 ether);
        vm.stopPrank();

        vm.startPrank(FIVEOUTOFNINE_WHALE);

        keep3r.bond(KP3R_V1, 0);
        vm.warp(block.timestamp + 3 days + 1);
        keep3r.activate(KP3R_V1);

        game = new ButtPlugWarsForTest(ButtPlugWars.Registry({
          masterOfCeremony: FIVEOUTOFNINE_WHALE,
          fiveOutOfNine: address(fiveOutOfNine),
          weth: WETH_9,
          kp3rV1: KP3R_V1,
          keep3rLP: KP3R_LP,
          keep3r: address(keep3r),
          uniswapRouter: UNISWAP_ROUTER,
          sudoswapFactory: SUDOSWAP_FACTORY,
          sudoswapCurve:SUDOSWAP_XYK_CURVE
        }), 5 days, 0);
        sudoPool = LSSVMPair(game.SUDOSWAP_POOL());
    }
}

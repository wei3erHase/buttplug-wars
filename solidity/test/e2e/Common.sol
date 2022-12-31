// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';

import {IChess, IButtPlug} from 'interfaces/IGame.sol';
import {LSSVMPair, ILSSVMPairFactory} from 'interfaces/ISudoswap.sol';
import {ButtPlugWars, IKeep3r, AddressRegistry} from 'contracts/ButtPlugWars.sol';
import {NFTDescriptor} from 'contracts/NFTDescriptor.sol';
import {ERC721} from 'solmate/tokens/ERC721.sol';

import {ButtPlugWarsForTest} from 'contracts/for-test/ButtPlugWarsForTest.sol';

contract CommonE2EBase is DSTestFull, AddressRegistry {
    uint256 constant FORK_BLOCK = 16200000;

    address user = label('user');
    address owner = label('owner');
    ButtPlugWarsForTest game;
    LSSVMPair sudoPool;

    IKeep3r keep3r = IKeep3r(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
    IChess chess = IChess(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    ERC721 fiveOutOfNine = ERC721(0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0);
    address constant ETH_WHALE = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address constant FIVEOUTOFNINE_WHALE = 0xC5233C3b46C83ADEE1039D340094173f0f7c1EcF;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

        // fund with ETH
        vm.startPrank(ETH_WHALE);
        payable(FIVEOUTOFNINE_WHALE).transfer(30 ether);
        vm.stopPrank();
        vm.startPrank(FIVEOUTOFNINE_WHALE);

        // activate as keeper
        keep3r.bond(KP3R_V1, 0);
        vm.warp(block.timestamp + 3 days + 1);
        keep3r.activate(KP3R_V1);

        // deploy game
        game = new ButtPlugWarsForTest('TEST', FIVEOUTOFNINE_WHALE, address(fiveOutOfNine), 5 days, 0);
        sudoPool = LSSVMPair(game.SUDOSWAP_POOL());

        address nftDescriptor = address(new NFTDescriptor(address(fiveOutOfNine)));
        game.setNftDescriptor(nftDescriptor);
    }
}

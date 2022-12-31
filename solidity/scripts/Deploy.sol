// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {fiveoutofnine} from 'fiveoutofnine/fiveoutofnine.sol';
import {ButtPlugWars} from 'contracts/ButtPlugWars.sol';
import {ChessForTest} from 'contracts/for-test/ChessForTest.sol';
import {NFTDescriptor} from 'contracts/NFTDescriptor.sol';
import {console} from 'forge-std/console.sol';

abstract contract Deploy is Script {
    address deployer;
}

contract DeployMainnet is Deploy {
    function run() external {
        vm.startBroadcast();

        new ButtPlugWars(deployer, 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0, 5 days, 4 hours);

        vm.stopBroadcast();
    }
}

contract DeployGoerli is Deploy {
    constructor() {
        deployer = vm.rememberKey(vm.envUint('GOERLI_DEPLOYER_PK'));
    }

    address constant CHESS_FOR_TEST = payable(0x206022B3B22F521A2054EE07Fcd7cb5DD6cCf7a0);

    function run() external {
        vm.chainId(10);
        vm.startBroadcast();
        // address chessForTest = address(new ChessForTest());

        new ButtPlugWars(deployer, CHESS_FOR_TEST, 60, 1);

        vm.stopBroadcast();
    }
}

contract DeployChessForTest is Deploy {
    constructor() {
        deployer = vm.rememberKey(vm.envUint('GOERLI_DEPLOYER_PK'));
    }

    function run() external {
        vm.startBroadcast();
        new ChessForTest();
        vm.stopBroadcast();
    }
}

contract DeployGoerliDescriptor is Deploy {
    address constant CHESS_FOR_TEST = 0x4524E82DB22812557D9e9E491395692404270bD1;
    address payable constant BUTT_PLUG_WARS = payable(0x0445927532a8105aBF06dEF0933d15E77A85a424);

    function run() external {
        vm.chainId(10);
        vm.startBroadcast();
        console.log(block.chainid);
        address nftDescriptor = address(new NFTDescriptor(CHESS_FOR_TEST));
        ButtPlugWars(BUTT_PLUG_WARS).setNftDescriptor(nftDescriptor);
        console.logString(ButtPlugWars(BUTT_PLUG_WARS).tokenURI(0));
        vm.stopBroadcast();
    }
}

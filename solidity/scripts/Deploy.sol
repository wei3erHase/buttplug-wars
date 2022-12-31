// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {ChessOlympiads} from 'contracts/ChessOlympiads.sol';
import {ChessOlympiadsForTest} from 'contracts/for-test/ChessOlympiadsForTest.sol';
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

        new ChessOlympiads(deployer);

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

contract DeployGoerli is Deploy {
    constructor() {
        deployer = vm.rememberKey(vm.envUint('GOERLI_DEPLOYER_PK'));
    }

    address constant CHESS_FOR_TEST = payable(0x4385F7CeaAcEfEA8A12075D4b65890E390585463);

    function run() external {
        vm.startBroadcast();
        vm.chainId(5);

        new ChessOlympiadsForTest(deployer, CHESS_FOR_TEST);

        vm.stopBroadcast();
    }
}

contract DeployGoerliDescriptor is Deploy {
    address constant CHESS_FOR_TEST = 0x4385F7CeaAcEfEA8A12075D4b65890E390585463;
    address payable constant BUTT_PLUG_WARS = payable(0x2C217D709A9309b1D30323bAcE28438eDe7E4e05);

    function run() external {
        vm.startBroadcast();
        console.log(block.chainid);
        NFTDescriptor nftDescriptor = new NFTDescriptor(CHESS_FOR_TEST);
        ButtPlugWars(BUTT_PLUG_WARS).setNftDescriptor(address(nftDescriptor));
        console.logString(ButtPlugWars(BUTT_PLUG_WARS).tokenURI(0));
        vm.stopBroadcast();
    }
}

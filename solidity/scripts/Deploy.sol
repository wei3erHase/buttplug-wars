// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {ChessOlympiads} from 'contracts/ChessOlympiads.sol';
import {ChessOlympiadsForTest} from 'contracts/for-test/ChessOlympiadsForTest.sol';
import {ButtPlugWars} from 'contracts/ButtPlugWars.sol';
import {NeimannPlug} from 'contracts/NeimannPlug.sol';
import {ChessForTest} from 'contracts/for-test/ChessForTest.sol';
import {NFTDescriptor} from 'contracts/NFTDescriptor.sol';
import {console} from 'forge-std/console.sol';

abstract contract Deploy is Script {
    address deployer;
}

abstract contract GoerliDeploy is Script {
    address deployer;

    constructor() {
        deployer = vm.rememberKey(vm.envUint('GOERLI_DEPLOYER_PK'));
    }
}

contract DeployMainnet is Deploy {
    address constant FIVE_OUT_OF_NINE = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;

    function run() external {
        vm.startBroadcast();
        address _chessOlympiads = address(new ChessOlympiads(FIVE_OUT_OF_NINE));
        vm.stopBroadcast();
    }
}

contract DeployMainnetDescriptor is Deploy {
    address constant FIVE_OUT_OF_NINE = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;

    function run() external {
        vm.startBroadcast();
        NFTDescriptor nftDescriptor = new NFTDescriptor(FIVE_OUT_OF_NINE);
        vm.stopBroadcast();
    }
}

contract DeployChessForTest is GoerliDeploy {
    function run() external {
        vm.startBroadcast();
        new ChessForTest();
        vm.stopBroadcast();
    }
}

contract DeployTestnet is GoerliDeploy {
    address constant CHESS_FOR_TEST = payable(0x4385F7CeaAcEfEA8A12075D4b65890E390585463);

    function run() external {
        vm.startBroadcast();
        new ChessOlympiadsForTest(deployer, CHESS_FOR_TEST);
        vm.stopBroadcast();
    }
}

contract DeployTestnetDescriptor is GoerliDeploy {
    address constant CHESS_FOR_TEST = 0x4385F7CeaAcEfEA8A12075D4b65890E390585463;
    address payable constant BUTT_PLUG_WARS = payable(0xd3068f96DC20204252aC7F3cb70d9c3fb954A735);

    function run() external {
        vm.startBroadcast();
        NFTDescriptor nftDescriptor = new NFTDescriptor(CHESS_FOR_TEST);
        ButtPlugWars(BUTT_PLUG_WARS).setNftDescriptor(address(nftDescriptor));
        console.logString(ButtPlugWars(BUTT_PLUG_WARS).tokenURI(0));
        vm.stopBroadcast();
    }
}

contract DeployButtPlug is Deploy {
    address payable constant BUTT_PLUG_WARS = payable(0x220d6F53444FB9205083E810344a3a3989527a34);

    function run() external {
        vm.startBroadcast();
        NeimannPlug buttplug = new NeimannPlug();
        ButtPlugWars(BUTT_PLUG_WARS).mintButtPlugBadge(address(buttplug));
        vm.stopBroadcast();
    }
}

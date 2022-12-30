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

        new ButtPlugWars(deployer,0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0, 5 days, 4 hours);

        vm.stopBroadcast();
    }
}

contract DeployGoerli is Deploy {
    constructor() {
        deployer = vm.rememberKey(vm.envUint('GOERLI_DEPLOYER_PK'));
    }

    function run() external {
        vm.startBroadcast();
        address chessForTest = address(new ChessForTest());

        new ButtPlugWars(deployer, address(chessForTest), 60, 1);

        vm.stopBroadcast();
    }
}

contract DeployGoerliDescriptor is Deploy {
    address payable constant BUTT_PLUG_WARS = payable(0x676a8e2B53A20D2904Bf03e9F79CeDa537895b20);

    function run() external {
        vm.startBroadcast();
        address nftDescriptor = address(new NFTDescriptor());
        ButtPlugWars(BUTT_PLUG_WARS).setNftDescriptor(nftDescriptor);
        console.logString(ButtPlugWars(BUTT_PLUG_WARS).tokenURI(0));
        vm.stopBroadcast();
    }
}

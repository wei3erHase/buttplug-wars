// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {ButtPlugWars} from 'contracts/ButtPlugWars.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';

abstract contract Deploy is Script {
    function _deploy() internal {
        vm.startBroadcast();
        new ButtPlugWars();
        vm.stopBroadcast();
    }
}

contract DeployMainnet is Deploy {
    function run() external {
        _deploy();
    }
}

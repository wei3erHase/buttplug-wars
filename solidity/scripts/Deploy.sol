// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {fiveoutofnine} from 'fiveoutofnine/fiveoutofnine.sol';
import {ButtPlugWars} from 'contracts/ButtPlugWars.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';

abstract contract Deploy is Script {}

contract DeployMainnet is Deploy {
    address constant FIVE_OUT_OF_NINE = 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0;
    address constant WETH_9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant KEEP3R = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;
    address constant KP3R_LP = 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7;
    address constant SUDOSWAP_FACTORY = 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4;
    address constant SUDOSWAP_XYK_CURVE = 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0;

    function run() external {
        vm.startBroadcast();
        // new ButtPlugWars(FIVE_OUT_OF_NINE, WETH_9, KEEP3R, KP3R_LP, SUDOSWAP_FACTORY, SUDOSWAP_XYK_CURVE);
        vm.stopBroadcast();
    }
}

contract DeployGoerli is Deploy {
    address constant FIVE_OUT_OF_NINE = 0x2ea2736Bfc0146ad20449eaa43245692E77fd2bc;
    address constant WETH_9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address constant KEEP3R = 0x145d364e193204f8Ff0A87b718938406595678Dd;
    address constant KP3R_LP = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address constant SUDOSWAP_FACTORY = 0xF0202E9267930aE942F0667dC6d805057328F6dC;
    address constant SUDOSWAP_XYK_CURVE = 0x02363a2F1B2c2C5815cb6893Aa27861BE0c4F760;

    function run() external {
        vm.startBroadcast();
        // address _fiveOutOfNine = address(new fiveoutofnine());
        new ButtPlugWars(FIVE_OUT_OF_NINE, WETH_9, KEEP3R, KP3R_LP, SUDOSWAP_FACTORY, SUDOSWAP_XYK_CURVE);
        vm.stopBroadcast();
    }
}

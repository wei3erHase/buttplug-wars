// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {fiveoutofnine} from 'fiveoutofnine/fiveoutofnine.sol';
import {ButtPlugWars} from 'contracts/ButtPlugWars.sol';
import {ChessForTest} from 'contracts/for-test/ChessForTest.sol';
import {NFTDescriptor} from 'contracts/NFTDescriptor.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {console} from 'forge-std/console.sol';

abstract contract Deploy is Script {
    address deployer;
}

contract DeployMainnet is Deploy {
    function run() external {
        vm.startBroadcast();

        new ButtPlugWars(ButtPlugWars.Registry({
          masterOfCeremony: deployer, // TODO: change for rabbit
          fiveOutOfNine: 0xB543F9043b387cE5B3d1F0d916E42D8eA2eBA2E0,
          weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
          kp3rV1: 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44,
          keep3rLP: 0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7,
          keep3r: 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC,
          uniswapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
          sudoswapFactory: 0xb16c1342E617A5B6E4b631EB114483FDB289c0A4,
          sudoswapCurve: 0x7942E264e21C5e6CbBA45fe50785a15D3BEb1DA0
        }), 5 days, 4 hours);

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

        new ButtPlugWars(ButtPlugWars.Registry({
          masterOfCeremony: deployer,
          fiveOutOfNine: address(chessForTest),
          weth: 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6,
          kp3rV1: 0x16F63C5036d3F48A239358656a8f123eCE85789C,
          keep3rLP: 0x78958e8e9C54d9aA56eDED102097E73ef9c26411,
          keep3r: 0x145d364e193204f8Ff0A87b718938406595678Dd,
          uniswapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
          sudoswapFactory: 0xF0202E9267930aE942F0667dC6d805057328F6dC,
          sudoswapCurve: 0x02363a2F1B2c2C5815cb6893Aa27861BE0c4F760
        }), 60, 1);

        vm.stopBroadcast();
    }
}

contract DeployGoerliDescriptor is Deploy {
    address constant BUTT_PLUG_WARS = 0x48C8c199cCDB7c1B7d3B41Ee510eA2D4C65DcA2c;

    function run() external {
        vm.startBroadcast();
        address nftDescriptor = address(new NFTDescriptor());
        ButtPlugWars(payable(BUTT_PLUG_WARS)).setNftDescriptor(nftDescriptor);
        console.logString(ButtPlugWars(payable(BUTT_PLUG_WARS)).tokenURI(0));
        vm.stopBroadcast();
    }
}

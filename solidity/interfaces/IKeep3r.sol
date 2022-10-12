// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IKeep3r {
    function addJob(address) external;

    function isKeeper(address) external returns (bool);

    function worked(address) external;

    function bond(address, uint256) external;

    function activate(address) external;

    function liquidityAmount(address, address) external view returns (uint256);

    function addLiquidityToJob(address, address, uint256) external;

    function unbondLiquidityFromJob(address, address, uint256) external;

    function withdrawLiquidityFromJob(address, address, address) external;
}

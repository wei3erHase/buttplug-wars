// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IKeep3r {
    function addJob(address) external;

    function isKeeper(address) external view returns (bool);

    function worked(address) external;

    function liquidityAmounts(address, address) external view returns (uint256);

    function addLiquidityToJob(address, address, uint256) external;

    function unbondLiquidityFromJob(address, address, uint256) external;

    function withdrawLiquidityFromJob(address, address) external;
}

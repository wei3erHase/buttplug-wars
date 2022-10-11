// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IERC721 {}

interface ICurve {}

interface LSSVMPair {
    enum PoolType {SELL}
}

interface LSSVMPairETH is LSSVMPair {}

interface ILSSVMPairFactory {
    function createPairETH(
        IERC721 _nft,
        ICurve _bondingCurve,
        address payable _assetRecipient,
        LSSVMPair.PoolType _poolType,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256[] calldata _initialNFTIDs
    )
        external
        payable
        returns (LSSVMPairETH pair);
}

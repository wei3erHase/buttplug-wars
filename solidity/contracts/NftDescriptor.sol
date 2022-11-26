pragma solidity >=0.8.4 <0.9.0;

import {IDescriptorPlug} from 'interfaces/Game.sol';

contract NftDescriptor is IDescriptorPlug {
    function getScoreboardMetadata(ScoreboardData memory) external view returns (string memory) {}

    function getPlayerBadgeMetadata(GameData memory, BadgeData memory, PlayerData memory)
        external
        view
        returns (string memory)
    {}

    function getButtPlugBadgeMetadata(GameData memory, BadgeData memory, ButtPlugData memory)
        external
        view
        returns (string memory)
    {}

    function getKeeperBadgeMetadata(GameData memory, BadgeData memory) external view returns (string memory) {}
}

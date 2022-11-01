// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IButtPlug {
    function readMove(uint256 _board) external view returns (uint256 _move);
}

interface IChess {
    function mintMove(uint256 _move, uint256 _depth) external;

    function board() external view returns (uint256 _board);
}

interface INftDescriptor {
    function getScoreboardMetadata(ScoreboardData memory) external view returns (string memory);

    function getPlayerBadgeMetadata(GameData memory, BadgeData memory, PlayerData memory)
        external
        view
        returns (string memory);

    function getButtPlugBadgeMetadata(GameData memory, BadgeData memory, ButtPlugData memory)
        external
        view
        returns (string memory);

    function getKeeperBadgeMetadata(GameData memory, BadgeData memory) external view returns (string memory);

    struct ScoreboardData {
        uint8 state;
        uint256 matchNumber;
        uint256 matchTotalMoves;
        uint256 matchesWonA;
        uint256 matchesWonB;
        int256 matchScoreA;
        int256 matchScoreB;
        address buttPlugA;
        address buttPlugB;
    }

    struct GameData {
        uint256 totalPlayers;
        uint256 totalShares;
        uint256 totalPrize;
        uint256 totalPrizeShares;
        uint256 claimableSales;
    }

    struct BadgeData {
        uint8 team;
        uint256 badgeId;
        uint256 badgeShares;
        uint256 claimedSales;
        uint256 firstSeen;
    }

    struct PlayerData {
        int256 score;
        address badgeVote;
        uint256 canVoteNext;
        uint256 bondedToken;
    }

    struct ButtPlugData {
        uint256 board;
        uint256 simulatedMove;
        uint256 simulatedGasSpent;
        uint256 buttPlugVotes;
    }
}

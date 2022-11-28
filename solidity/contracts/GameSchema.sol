// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

abstract contract GameSchema {
    error WrongValue(); // badge minting value should be between 0.05 and 1
    error WrongTeam(); // only winners can claim the prize
    error WrongNFT(); // an unknown NFT was sent to the contract
    error WrongBadge(); // only the badge owner can access
    error WrongKeeper(); // keeper doesn't fulfill the required params
    error WrongTiming(); // method called at wrong roadmap state or cooldown
    error WrongMethod(); // method should not be externally called

    /* Game mechanics */
    enum TEAM {
        ZERO,
        ONE,
        STAFF
    }

    /*///////////////////////////////////////////////////////////////
                            GAME VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 totalPlayers;

    mapping(TEAM => uint256) matchesWon;
    mapping(TEAM => int256) matchScore;
    uint256 matchMoves;
    uint256 matchNumber;

    /* Badge mechanics */
    uint256 totalShares;
    mapping(uint256 => uint256) badgeShares;
    mapping(uint256 => uint256) bondedToken;

    /* Vote mechanics */
    mapping(TEAM => address) buttPlug;
    mapping(TEAM => mapping(address => uint256)) buttPlugVotes;
    mapping(uint256 => int256) score;
    mapping(uint256 => mapping(uint256 => int256)) lastUpdatedScore;
    mapping(uint256 => address) badgeButtPlugVote;

    /* Prize mechanics */
    uint256 totalPrize;
    uint256 totalPrizeShares;
    mapping(address => uint256) playerPrizeShares;

    uint256 claimableSales;
    mapping(address => uint256) claimedSales;
    mapping(address => uint256) playerHonorShares;
    uint256 totalHonorShares;

    function _calculateButtPlugBadge(address _buttPlug, TEAM _team) internal pure returns (uint256 _badgeId) {
        return uint256(uint256(uint160(_buttPlug)) << 64) + (uint256(_team) << 32);
    }

    function _calculateButtPlugAddress(uint256 _badgeId) internal pure returns (address _buttPlug) {
        return address(uint160((_badgeId - (uint256(TEAM.STAFF) << 32)) >> 64));
    }

    function _getScore(uint256 _badgeId) internal view returns (int256 _score) {
        TEAM _team = _getTeam(_badgeId);
        if (_team < TEAM.STAFF) {
            uint256 _currentButtPlugBadge = _calculateButtPlugBadge(badgeButtPlugVote[_badgeId], _team);
            return score[_badgeId] + score[_currentButtPlugBadge] - lastUpdatedScore[_badgeId][_currentButtPlugBadge];
        } else {
            address _buttPlug = _calculateButtPlugAddress(_badgeId);
            uint256 _buttPlugZERO = _calculateButtPlugBadge(_buttPlug, TEAM.ZERO);
            uint256 _buttPlugONE = _calculateButtPlugBadge(_buttPlug, TEAM.ONE);
            return score[_buttPlugZERO] + score[_buttPlugONE];
        }
    }

    function _getTeam(uint256 _badgeId) internal pure returns (TEAM _team) {
        return TEAM(uint8(_badgeId >> 32));
    }
}

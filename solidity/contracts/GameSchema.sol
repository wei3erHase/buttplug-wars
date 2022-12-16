// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

abstract contract GameSchema {
    error WrongMethod(); // method should not be externally called
    error WrongTiming(); // method called at wrong roadmap state or cooldown
    error WrongKeeper(); // keeper doesn't fulfill the required params
    error WrongValue(); // badge minting value should be between 0.05 and 1
    error WrongBadge(); // only the badge owner or allowed can access
    error WrongTeam(); // only specific badges can access
    error WrongNFT(); // an unknown NFT was sent to the contract

    uint256 constant BASE = 10_000;
    uint256 constant MAX_UINT = type(uint256).max;
    uint256 constant CHECKMATE = 0x3256230011111100000000000000000099999900BCDECB000000001;
    uint256 constant MAGIC_NUMBER = 0xDB5D33CB1BADB2BAA99A59238A179D71B69959551349138D30B289;
    // TODO: reduce gasLimit (with rounds)
    uint256 constant BUTT_PLUG_GAS_LIMIT = 20_000_000;

    enum STATE {
        ANNOUNCEMENT, // rabbit can cancel event
        TICKET_SALE, // can mint badges
        GAME_RUNNING, // game runs, can mint badges
        GAME_OVER, // game stops, can unbondLiquidity
        PREPARATIONS, // can claim prize, waits until kLPs are unbonded
        PRIZE_CEREMONY, // can withdraw prize or honors
        CANCELLED // a critical bug was found
    }

    STATE public state = STATE.ANNOUNCEMENT;

    uint256 canStartSales;
    uint256 canPlayNext;
    uint256 canPushLiquidity;
    uint256 canUpdateSpotPriceNext;

    enum TEAM {
        ZERO,
        ONE,
        STAFF,
        MEDAL
    }

    /*///////////////////////////////////////////////////////////////
                            GAME VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(TEAM => uint256) matchesWon;
    mapping(TEAM => int256) matchScore;
    uint256 matchNumber;
    uint256 matchMoves;

    /* Badge mechanics */
    uint256 totalPlayers;
    mapping(uint256 => uint256) badgeWeight;

    /* Vote mechanics */
    mapping(uint256 => address) vote;
    mapping(TEAM => address) buttPlug;
    mapping(TEAM => mapping(address => uint256)) votes;
    mapping(uint256 => mapping(address => uint256)) voteParticipation;

    /* Prize mechanics */
    uint256 totalPrize;
    uint256 totalSales;

    mapping(uint256 => int256) score;
    mapping(uint256 => uint256) claimedSales;
    mapping(uint256 => mapping(uint256 => int256)) lastUpdatedScore;

    function _calculateButtPlugBadge(address _buttPlug, TEAM _team) internal pure returns (uint256 _badgeId) {
        return uint256(uint256(uint160(_buttPlug)) << 64) + (uint256(_team) << 32);
    }

    function _calculateButtPlugAddress(uint256 _badgeId) internal pure returns (address _buttPlug) {
        return address(uint160((_badgeId - (uint256(TEAM.STAFF) << 32)) >> 64));
    }

    function _getTeam(uint256 _badgeId) internal pure returns (TEAM _team) {
        return TEAM(uint8(_badgeId >> 32));
    }

    function _getScore(uint256 _badgeId) internal view returns (int256 _score) {
        TEAM _team = _getTeam(_badgeId);
        if (_team < TEAM.STAFF) {
            address _currentButtPlug = vote[_badgeId];
            uint256 _currentButtPlugBadge = _calculateButtPlugBadge(_currentButtPlug, _team);
            int256 _currentParticipation = int256(voteParticipation[_badgeId][_currentButtPlug]);
            return score[_badgeId]
                + _currentParticipation * (score[_currentButtPlugBadge] - lastUpdatedScore[_badgeId][_currentButtPlugBadge])
                    / int256(BASE);
        } else {
            address _buttPlug = _calculateButtPlugAddress(_badgeId);
            uint256 _buttPlugZERO = _calculateButtPlugBadge(_buttPlug, TEAM.ZERO);
            uint256 _buttPlugONE = _calculateButtPlugBadge(_buttPlug, TEAM.ONE);
            return score[_buttPlugZERO] + score[_buttPlugONE];
        }
    }
}

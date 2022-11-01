pragma solidity >=0.8.4 <0.9.0;

import {INftDescriptor} from 'interfaces/Game.sol';
import {Base64} from './Base64.sol';

contract DumbDescriptor is INftDescriptor {
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

    function _getMetadata(uint256 _badgeId) internal view returns (string memory) {
        //   string memory _json = Base64.encode(
        //       bytes(
        //           string(
        //               abi.encodePacked(
        //                   '{"name": "ButtPlugBadge",',
        //                 //   '"image_data": "',
        //                 //   _getSvg(_badgeId),
        //                 //   '",',
        //                   '"attributes": [{"trait_type": "Weigth", "value": ',
        //                   _uint2str(badgeShares[_badgeId]),
        //                   '}]}'
        //               )
        //           )
        //       )
        //   );
        //   return string(abi.encodePacked('data:application/json;base64,', _json));
    }

    // function _getSvg(uint256 _badgeId) internal view returns (string memory) {
    //     TEAM _team = TEAM(_badgeId >> 59);
    //     string memory _svg =
    //         "<svg width='300px' height='300px' viewBox='0 0 300 300' fill='none' xmlns='http://www.w3.org/2000/svg'><path width='48' height='48' fill='white' d='M0 0H300V300H0V0z'/><path d='M275 25H193L168 89C196 95 220 113 232 137L275 25Z' fill='#2F88FF' stroke='black' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/><path d='M106 25H25L67 137C79 113 103 95 131 89L106 25Z' fill='#2F88FF' stroke='black' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/><path d='M243 181C243 233 201 275 150 275C98 275 56 233 56 181 C56 165 60 150 67 137 C79 113 103 95 131 89 C137 88 143 87 150 87 C156 87 162 88 168 89 C196 95 220 113 232 137C239 150.561 243.75 165.449 243 181Z' fill='";

    //     if (matchesWon[_team] >= 5) {
    //         _svg = string(abi.encodePacked(_svg, '#FEA914'));
    //     } else {
    //         if (_team == TEAM.A) _svg = string(abi.encodePacked(_svg, '#2F88FF'));
    //         else _svg = string(abi.encodePacked(_svg, '#C1292E'));
    //     }

    //     _svg = string(
    //         abi.encodePacked(
    //             _svg,
    //             "' stroke='black' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/><svg viewBox='-115 -25 300 100'><path "
    //         )
    //     );

    //     if (_team == TEAM.A) _svg = string(abi.encodePacked(_svg, "d='M5,90 l30,-80 30,80 M20,50 l30,0' "));
    //     else _svg = string(abi.encodePacked(_svg, "d='M5,5 c80,0 80,45 0,45 c80,0 80,45 0,45z' "));

    //     _svg = string(
    //         abi.encodePacked(
    //             _svg,
    //             "stroke='white' stroke-width='25' stroke-linecap='round' stroke-linejoin='round'/></svg><text x='50%' y='80%' stroke='black' dominant-baseline='middle' text-anchor='middle'>",
    //             _uint2str(_badgeId % (1 << 59)),
    //             '</text></svg>'
    //         )
    //     );

    //     return _svg;
    // }

    // function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
    //     if (_i == 0) return '0';
    //     uint256 j = _i;
    //     uint256 len;
    //     while (j != 0) {
    //         len++;
    //         j /= 10;
    //     }
    //     bytes memory bstr = new bytes(len);
    //     uint256 k = len;
    //     while (_i != 0) {
    //         k = k - 1;
    //         uint8 temp = (48 + uint8(_i - _i / 10 * 10));
    //         bytes1 b1 = bytes1(temp);
    //         bstr[k] = b1;
    //         _i /= 10;
    //     }
    //     return string(bstr);
    // }
}

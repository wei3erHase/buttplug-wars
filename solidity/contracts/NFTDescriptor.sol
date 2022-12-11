// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {GameSchema} from './GameSchema.sol';
import {IButtPlug, IChess, IDescriptorPlug} from 'interfaces/IGame.sol';
import {Jeison, Strings, IntStrings} from './libs/Jeison.sol';
import {FiveOutOfNineUtils, Chess} from './libs/FiveOutOfNineUtils.sol';

contract NFTDescriptor is GameSchema {
    using Chess for uint256;

    using Jeison for Jeison.JsonObject;
    using Strings for address;
    using Strings for uint256;
    using Strings for uint160;
    using IntStrings for int256;

    // TODO: return to mainnet
    address constant FIVE_OUT_OF_NINE = 0x2ea2736Bfc0146ad20449eaa43245692E77fd2bc;

    function _tokenURI(uint256 _badgeId) public view virtual returns (string memory _tokenURI) {
        /* Scoreboard */
        if (_badgeId == 0) {
            Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](2);
            Jeison.DataPoint[] memory _datapoints = new Jeison.DataPoint[](2);

            // creates metadata array[{traits}]
            string memory scoreboard;
            scoreboard = string(
                abi.encodePacked(
                    matchesWon[TEAM.ZERO].toString(),
                    '(',
                    matchScore[TEAM.ZERO].toString(),
                    ') - ',
                    matchesWon[TEAM.ONE].toString(),
                    '(',
                    matchScore[TEAM.ONE].toString(),
                    ')'
                )
            );
            _datapoints[0] = Jeison.dataPoint('trait_type', 'game-score');
            _datapoints[1] = Jeison.dataPoint('value', scoreboard);
            _metadata[0] = Jeison.create(_datapoints);
            _datapoints[0] = Jeison.dataPoint('trait_type', 'weight');
            _datapoints[1] = Jeison.dataPoint('value', totalShares / 1e6);
            _metadata[1] = Jeison.create(_datapoints);
            // if(state == STATE.ANNOUNCEMENT){
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'status');
            //   _datapoints[1] = Jeison.dataPoint('value', 'ANNOUNCEMENT');
            //   _metadata[2] = Jeison.create(_datapoints);
            //   Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](2);
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'sales-start');
            //   _datapoints[1] = Jeison.dataPoint('value', canStartSales);
            //   _datapoints[2] = Jeison.dataPoint('display_type', 'date');
            //   _metadata[3] = Jeison.create(_datapoints);
            // }
            // else if(state == STATE.TICKET_SALE){
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'status');
            //   _datapoints[1] = Jeison.dataPoint('value', 'TICKET_SALE');
            //   _metadata[2] = Jeison.create(_datapoints);
            //   Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](2);
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'game-start');
            //   _datapoints[1] = Jeison.dataPoint('value', canPushLiquidity);
            //   _datapoints[2] = Jeison.dataPoint('display_type', 'date');
            //   _metadata[3] = Jeison.create(_datapoints);
            // }
            // else if(state == STATE.GAME_RUNNING){
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'status');
            //   _datapoints[1] = Jeison.dataPoint('value', 'GAME_RUNNING');
            //   _metadata[2] = Jeison.create(_datapoints);
            //   Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](2);
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'can-play-next');
            //   _datapoints[1] = Jeison.dataPoint('value', canPlayNext);
            //   _datapoints[2] = Jeison.dataPoint('display_type', 'date');
            //   _metadata[3] = Jeison.create(_datapoints);
            // }
            // else if(state >= STATE.GAME_OVER){
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'status');
            //   _datapoints[1] = Jeison.dataPoint('value', 'GAME_OVER');
            //   _metadata[2] = Jeison.create(_datapoints);
            //   Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](2);
            //   _datapoints[0] = Jeison.dataPoint('trait_type', 'can-play-next');
            //   _datapoints[1] = Jeison.dataPoint('value', canPlayNext);
            //   _datapoints[2] = Jeison.dataPoint('display_type', 'date');
            //   _metadata[3] = Jeison.create(_datapoints);
            // }

            // creates json
            _datapoints = new Jeison.DataPoint[](4);
            _datapoints[0] = Jeison.dataPoint('name', 'ButtPlugWars Scoreboard');
            _datapoints[1] = Jeison.dataPoint('description', 'Scoreboard NFT with information about the game state');
            _datapoints[2] = Jeison.dataPoint('image_data', _drawSVG());
            _datapoints[3] = Jeison.arraify('attributes', _metadata);

            return Jeison.create(_datapoints).getBase64();
        }

        TEAM _team = _getTeam(_badgeId);

        /* Player metadata */
        if (_team < TEAM.STAFF) {
            // if buttplug remove weight (or add inflation)
            Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](5);
            Jeison.DataPoint[] memory _datapoints = new Jeison.DataPoint[](2);

            {
                string memory teamString = _team == TEAM.ZERO ? 'ZERO' : 'ONE';
                _datapoints[0] = Jeison.dataPoint('trait_type', 'team');
                _datapoints[1] = Jeison.dataPoint('value', teamString);
                _metadata[0] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'weight');
                _datapoints[1] = Jeison.dataPoint('value', badgeShares[_badgeId] / 1e6);
                _metadata[1] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'score');
                _datapoints[1] = Jeison.dataPoint('value', _getScore(_badgeId) / 1e6);
                _metadata[2] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'vote');
                _datapoints[1] = Jeison.dataPoint('value', (uint160(badgeButtPlugVote[_badgeId]) >> 128).toHexString());
                _metadata[3] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'bonded_token');
                _datapoints[1] = Jeison.dataPoint('value', bondedToken[_badgeId].toString());
                _metadata[4] = Jeison.create(_datapoints);
            }
            // creates json
            _datapoints = new Jeison.DataPoint[](4);
            _datapoints[0] = Jeison.dataPoint('name', 'Player');
            string memory _descriptionStr =
                string(abi.encodePacked('Player Badge with FiveOutOfNine#', bondedToken[_badgeId].toString()));
            _datapoints[1] = Jeison.dataPoint('description', _descriptionStr);
            _datapoints[2] = Jeison.dataPoint('image_data', _drawSVG());
            _datapoints[3] = Jeison.arraify('attributes', _metadata);

            return Jeison.create(_datapoints).getBase64();
        }

        /* ButtPlug metadata */
        if (_team == TEAM.STAFF) {
            Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](4);
            Jeison.DataPoint[] memory _datapoints = new Jeison.DataPoint[](2);

            {
                address _buttPlug = _calculateButtPlugAddress(_badgeId);

                uint256 _board = IChess(FIVE_OUT_OF_NINE).board();
                (bool _isLegal, uint256 _simMove, uint256 _simGasUsed, string memory _description) =
                    _simulateButtPlug(_buttPlug, _board);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'score');
                _datapoints[1] = Jeison.dataPoint('value', _getScore(_badgeId) / 1e6);
                _metadata[0] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'simulated_move');
                _datapoints[1] = Jeison.dataPoint('value', _description);
                _metadata[1] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'simulated_gas');
                _datapoints[1] = Jeison.dataPoint('value', _simGasUsed);
                _metadata[2] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'is_legal_move');
                _datapoints[1] = Jeison.dataPoint('value', _isLegal);
                _metadata[3] = Jeison.create(_datapoints);
            }
            // creates json
            _datapoints = new Jeison.DataPoint[](4);
            _datapoints[0] = Jeison.dataPoint('name', 'ButtPlug');
            string memory _descriptionStr = string(
                abi.encodePacked('ButtPlug Badge for contract at ', _calculateButtPlugAddress(_badgeId).toHexString())
            );
            _datapoints[1] = Jeison.dataPoint('description', _descriptionStr);
            _datapoints[2] = Jeison.dataPoint('image_data', _drawSVG());
            _datapoints[3] = Jeison.arraify('attributes', _metadata);

            return Jeison.create(_datapoints).getBase64();
        }

        revert WrongNFT();
    }

    function _drawSVG() internal view returns (string memory) {}

    function _simulateButtPlug(address _buttPlug, uint256 _board)
        internal
        view
        returns (bool _isLegal, uint256 _simMove, uint256 _simGasUsed, string memory _description)
    {
        uint256 _gasLeft = gasleft();
        try IButtPlug(_buttPlug).readMove(_board) returns (uint256 _move) {
            _simMove = _move;
            _simGasUsed = _gasLeft - gasleft();
        } catch {
            _simMove = 0;
            _simGasUsed = _gasLeft - gasleft();
        }
        _isLegal = _board.isLegalMove(_simMove);
        _description = FiveOutOfNineUtils.describeMove(_board, _simMove);
    }
}

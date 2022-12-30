// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {GameSchema} from './GameSchema.sol';
import {IKeep3r} from 'interfaces/IKeep3r.sol';
import {IButtPlug, IChess} from 'interfaces/IGame.sol';
import {Jeison, Strings, IntStrings} from './libs/Jeison.sol';
import {FiveOutOfNineUtils, Chess} from './libs/FiveOutOfNineUtils.sol';

contract NFTDescriptor is GameSchema {
    using Chess for uint256;
    using Jeison for Jeison.JsonObject;
    using Jeison for string;
    using Strings for address;
    using Strings for uint256;
    using Strings for uint160;
    using Strings for uint32;
    using Strings for uint16;
    using IntStrings for int256;

    // TODO: return to mainnet
    address constant FIVE_OUT_OF_NINE = 0x226a166e5E44c654b3a76ef406be7E00755b9f45;
    address constant KEEP3R = 0x229d018065019c3164B899F4B9c2d4ffEae9B92b;
    address constant KP3R_LP = 0xb4A7137B024d4C0531b0164fCb6E8fc20e6777Ae;

    function _tokenURI(uint256 _badgeId) public view virtual returns (string memory _uri) {
        /* Scoreboard */
        if (_badgeId == 0) {
            Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](6);
            Jeison.DataPoint[] memory _datapoints = new Jeison.DataPoint[](2);
            Jeison.DataPoint[] memory _longDatapoints = new Jeison.DataPoint[](3);

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

            _datapoints[0] = Jeison.dataPoint('trait_type', 'players');
            _datapoints[1] = Jeison.dataPoint('value', totalPlayers.toString());
            _metadata[1] = Jeison.create(_datapoints);

            _datapoints[0] = Jeison.dataPoint('trait_type', 'prize');
            _datapoints[1] = Jeison.dataPoint('value', (totalPrize / 1e15).toString());
            _metadata[2] = Jeison.create(_datapoints);

            _datapoints[0] = Jeison.dataPoint('trait_type', 'sales');
            _datapoints[1] = Jeison.dataPoint('value', (totalSales / 1e15).toString());
            _metadata[3] = Jeison.create(_datapoints);

            _datapoints[0] = Jeison.dataPoint('trait_type', 'period-credits');
            _datapoints[1] =
                Jeison.dataPoint('value', (IKeep3r(KEEP3R).jobPeriodCredits(address(this)) / 1e15).toString());
            _metadata[4] = Jeison.create(_datapoints);

            if (state == STATE.ANNOUNCEMENT) {
                _longDatapoints[0] = Jeison.dataPoint('trait_type', 'sales-start');
                _longDatapoints[1] = Jeison.dataPoint('value', canStartSales);
                _longDatapoints[2] = Jeison.dataPoint('display_type', 'date');
                _metadata[5] = Jeison.create(_longDatapoints);
            } else if (state == STATE.TICKET_SALE) {
                _longDatapoints[0] = Jeison.dataPoint('trait_type', 'game-start');
                _longDatapoints[1] = Jeison.dataPoint('value', canPushLiquidity);
                _longDatapoints[2] = Jeison.dataPoint('display_type', 'date');
                _metadata[5] = Jeison.create(_longDatapoints);
            } else if (state == STATE.GAME_RUNNING) {
                _longDatapoints[0] = Jeison.dataPoint('trait_type', 'can-play-next');
                _longDatapoints[1] = Jeison.dataPoint('value', canPlayNext);
                _longDatapoints[2] = Jeison.dataPoint('display_type', 'date');
                _metadata[5] = Jeison.create(_longDatapoints);
            } else if (state == STATE.GAME_OVER) {
                _datapoints[0] = Jeison.dataPoint('trait_type', 'can-unbond-liquidity');
                _datapoints[1] = Jeison.dataPoint('value', true);
                _metadata[5] = Jeison.create(_datapoints);
            } else if (state == STATE.PREPARATIONS) {
                _longDatapoints[0] = Jeison.dataPoint('trait_type', 'rewards-start');
                _longDatapoints[1] = Jeison.dataPoint('value', IKeep3r(KEEP3R).canWithdrawAfter(address(this), KP3R_LP));
                _longDatapoints[2] = Jeison.dataPoint('display_type', 'date');
                _metadata[5] = Jeison.create(_longDatapoints);
            } else if (state == STATE.PRIZE_CEREMONY) {
                _longDatapoints[0] = Jeison.dataPoint('trait_type', 'can-update-next');
                _longDatapoints[1] = Jeison.dataPoint('value', canUpdateSpotPriceNext);
                _longDatapoints[2] = Jeison.dataPoint('display_type', 'date');
                _metadata[5] = Jeison.create(_longDatapoints);
            }

            // creates json
            _datapoints = new Jeison.DataPoint[](4);
            _datapoints[0] = Jeison.dataPoint('name', 'ChessOlympiads Scoreboard');
            _datapoints[1] = Jeison.dataPoint('description', 'Scoreboard NFT with information about the game state');
            _datapoints[2] = Jeison.dataPoint('image_data', _drawSVG());
            _datapoints[3] = Jeison.arraify('attributes', _metadata);

            return Jeison.create(_datapoints).getBase64();
        }

        TEAM _team = _getBadgeType(_badgeId);

        /* Player metadata */
        if (_team < TEAM.BUTTPLUG) {
            Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](5);
            Jeison.DataPoint[] memory _datapoints = new Jeison.DataPoint[](2);

            {
                uint256 _voteData = voteData[_badgeId];

                string memory teamString = _team == TEAM.ZERO ? 'ZERO' : 'ONE';
                _datapoints[0] = Jeison.dataPoint('trait_type', 'team');
                _datapoints[1] = Jeison.dataPoint('value', teamString);
                _metadata[0] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'weight');
                _datapoints[1] = Jeison.dataPoint('value', _getBadgeWeight(_badgeId) / 1e6);
                _metadata[1] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'score');
                _datapoints[1] = Jeison.dataPoint('value', _calcScore(_badgeId) / 1e6);
                _metadata[2] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'vote');
                _datapoints[1] =
                    Jeison.dataPoint('value', (uint160(_getVoteAddress(voteData[_badgeId])) >> 128).toHexString());
                _metadata[3] = Jeison.create(_datapoints);
                _datapoints = new Jeison.DataPoint[](3);
                _datapoints[0] = Jeison.dataPoint('display_type', 'boost_percentage');
                _datapoints[1] = Jeison.dataPoint('trait_type', 'vote_participation');
                _datapoints[2] = Jeison.dataPoint('value', _getVoteParticipation(voteData[_badgeId]) / 100);
                _metadata[4] = Jeison.create(_datapoints);
            }
            // creates json
            _datapoints = new Jeison.DataPoint[](4);
            string memory _descriptionStr = string(abi.encodePacked('Player #', _getPlayerNumber(_badgeId).toString()));
            _datapoints[0] = Jeison.dataPoint('name', _descriptionStr);
            _descriptionStr = string(
                abi.encodePacked('Player Badge with bonded FiveOutOfNine#', (_getStakedToken(_badgeId)).toString())
            );
            _datapoints[1] = Jeison.dataPoint('description', _descriptionStr);
            _datapoints[2] = Jeison.dataPoint('image_data', _drawSVG());
            _datapoints[3] = Jeison.arraify('attributes', _metadata);

            return Jeison.create(_datapoints).getBase64();
        }

        /* ButtPlug metadata */
        if (_team == TEAM.BUTTPLUG) {
            Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](4);
            Jeison.DataPoint[] memory _datapoints = new Jeison.DataPoint[](2);
            address _buttPlug = _getButtPlugAddress(_badgeId);

            {
                uint256 _board = IChess(FIVE_OUT_OF_NINE).board();
                (bool _isLegal,, uint256 _simGasUsed, string memory _description) = _simulateButtPlug(_buttPlug, _board);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'score');
                _datapoints[1] = Jeison.dataPoint('value', _calcScore(_badgeId) / 1e6);
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
            string memory _descriptionStr =
                string(abi.encodePacked('ButtPlug ', (uint160(_buttPlug) >> 128).toHexString()));
            _datapoints[0] = Jeison.dataPoint('name', _descriptionStr);
            _descriptionStr = string(abi.encodePacked('ButtPlug Badge for contract at ', _buttPlug.toHexString()));

            _datapoints[1] = Jeison.dataPoint('description', _descriptionStr);
            _datapoints[2] = Jeison.dataPoint('image_data', _drawSVG());
            _datapoints[3] = Jeison.arraify('attributes', _metadata);

            return Jeison.create(_datapoints).getBase64();
        }

        /* Medal metadata */
        if (_team == TEAM.MEDAL) {
            Jeison.JsonObject[] memory _metadata = new Jeison.JsonObject[](3);
            Jeison.DataPoint[] memory _datapoints = new Jeison.DataPoint[](2);

            {
                _datapoints[0] = Jeison.dataPoint('trait_type', 'score');
                _datapoints[1] = Jeison.dataPoint('value', _getMedalScore(_badgeId) / 1e6);
                _metadata[0] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'weight');
                _datapoints[1] = Jeison.dataPoint('value', _getBadgeWeight(_badgeId) / 1e6);
                _metadata[1] = Jeison.create(_datapoints);
                _datapoints[0] = Jeison.dataPoint('trait_type', 'salt');
                _datapoints[1] = Jeison.dataPoint('value', _getMedalSalt(_badgeId).toHexString());
                _metadata[2] = Jeison.create(_datapoints);
            }

            // creates json
            _datapoints = new Jeison.DataPoint[](4);
            string memory _descriptionStr = string(abi.encodePacked('Medal ', _getMedalSalt(_badgeId).toHexString()));
            _datapoints[0] = Jeison.dataPoint('name', _descriptionStr);
            _descriptionStr = string(abi.encodePacked('Medal with score ', _getMedalScore(_badgeId).toHexString()));

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

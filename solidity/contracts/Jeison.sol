// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Strings} from './Strings.sol';

library IntStrings {
    function toString(int256 value) internal pure returns (string memory) {
        if (value >= 0) return Strings.toString(uint256(value));
        return string(abi.encodePacked('-', Strings.toString(uint256(-value))));
    }
}

library Jeison {
    using Strings for uint256;
    using Strings for address;
    using IntStrings for int256;

    struct JsonObject {
        string[] varNames;
        string[] varValues;
        bool[] isNumeric;
        uint256 i;
    }

    function load(JsonObject memory self, string memory varName, string memory varValue)
        internal
        view
        returns (JsonObject memory)
    {
        return _load(self, varName, varValue, false);
    }

    function nest(JsonObject memory self, string memory varName, string memory nestedJson)
        internal
        view
        returns (JsonObject memory)
    {
        return _load(self, varName, nestedJson, true);
    }

    function load(JsonObject memory self, string memory varName, address varValue)
        internal
        view
        returns (JsonObject memory)
    {
        return _load(self, varName, varValue.toHexString(), false);
    }

    function load(JsonObject memory self, string memory varName, uint256 varValue)
        internal
        view
        returns (JsonObject memory)
    {
        return _load(self, varName, varValue.toString(), true);
    }

    function load(JsonObject memory self, string memory varName, int256 varValue)
        internal
        view
        returns (JsonObject memory)
    {
        return _load(self, varName, varValue.toString(), true);
    }

    function _load(JsonObject memory self, string memory varName, string memory varValue, bool varType)
        internal
        view
        returns (JsonObject memory)
    {
        uint256 _index = self.i++;
        self.varNames[_index] = varName;
        self.varValues[_index] = varValue;
        self.isNumeric[_index] = varType;
        return self;
    }

    function load(JsonObject memory self, string memory varName, uint256[] memory uintValues)
        internal
        view
        returns (JsonObject memory)
    {
        string memory batchStr = '[';
        for (uint256 _i; _i < uintValues.length; _i++) {
            string memory varStr;
            varStr = uintValues[_i].toString();
            if (_i != 0) varStr = string(abi.encodePacked(', ', varStr));
            batchStr = string(abi.encodePacked(batchStr, varStr));
        }

        batchStr = string(abi.encodePacked(batchStr, ']'));

        return _load(self, varName, batchStr, true);
    }

    function load(JsonObject memory self, string memory varName, int256[] memory intValues)
        internal
        view
        returns (JsonObject memory)
    {
        string memory batchStr = '[';
        for (uint256 _i; _i < intValues.length; _i++) {
            string memory varStr;
            varStr = intValues[_i].toString();
            if (_i != 0) varStr = string(abi.encodePacked(', ', varStr));
            batchStr = string(abi.encodePacked(batchStr, varStr));
        }

        batchStr = string(abi.encodePacked(batchStr, ']'));

        return _load(self, varName, batchStr, true);
    }

    function separator(bool _isNumeric) internal pure returns (string memory _separator) {
        if (!_isNumeric) return '"';
    }

    function get(JsonObject memory self) internal view returns (string memory batchStr) {
        batchStr = '{';
        for (uint256 _i; _i < self.i; _i++) {
            string memory varStr;
            varStr = string(
                abi.encodePacked(
                    '"',
                    self.varNames[_i],
                    '" : ',
                    separator(self.isNumeric[_i]),
                    self.varValues[_i], // "value" / value
                    separator(self.isNumeric[_i])
                )
            );
            if (_i != 0) {
                // , "var" : "value"
                varStr = string(abi.encodePacked(', ', varStr));
            }
            batchStr = string(abi.encodePacked(batchStr, varStr));
        }

        batchStr = string(abi.encodePacked(batchStr, '}'));
    }

    function initialize() internal view returns (JsonObject memory json) {
        json.varNames = new string[](64);
        json.varValues = new string[](64);
        json.isNumeric = new bool[](64);
        json.i = 0;
    }

    struct DataPoint {
        string name;
        string value;
        bool isNumeric;
    }

    function create(DataPoint[] memory _datapoints) internal view returns (JsonObject memory json) {
        json = initialize();
        for (uint256 _i; _i < _datapoints.length; _i++) {
            json = _load(json, _datapoints[_i].name, _datapoints[_i].value, _datapoints[_i].isNumeric);
        }
        return json;
    }

    /*

    "arrayName" : [
      {json1},
      {json2}
    ]

    */

    function array(string memory varName, JsonObject[] memory jsons) internal returns (DataPoint memory datapoint) {
        datapoint.name = varName;
        datapoint.isNumeric = true;

        string memory batchStr = '[';
        for (uint256 _i; _i < jsons.length; _i++) {
            string memory varStr;
            varStr = get(jsons[_i]);
            if (_i != 0) {
                // , "var" : "value"
                varStr = string(abi.encodePacked(', ', varStr));
            }
            batchStr = string(abi.encodePacked(batchStr, varStr));
        }

        datapoint.value = string(abi.encodePacked(batchStr, ']'));
    }

    function playground() internal returns (JsonObject memory json) {
        DataPoint[] memory _datapoints = new DataPoint[](3);
        _datapoints[0] = DataPoint('1', '2', false);
        _datapoints[1] = DataPoint('1', '2', false);
        _datapoints[2] = DataPoint('1', '2', false);

        return create(_datapoints);
    }
}

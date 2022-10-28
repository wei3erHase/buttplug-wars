// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.7 <0.9.0;

import './Base64.sol';
import './DescriptorUtils.sol';

/// @title Describes NFT token positions
/// @notice Produces a string containing the data URI for a JSON metadata string
contract ButtPlugBadgeDescriptor {
    using Strings for uint256;
    using Strings for uint32;

    struct ButtPlugParams {
        uint256 badgeId;
        uint256 weight;
        uint256 firstSeen;
        int256 score;
    }

    function tokenURI(address _hub, uint256 _tokenId) external view returns (string memory) {
        // IDCAPositionGetter.UserPosition memory _userPosition = IDCAPositionGetter(_hub).userPosition(_tokenId);

        // return _constructTokenURI(
        //     ButtPlugParams({
        //         tokenId: _tokenId.toString(),
        //         fromToken: DescriptorUtils.addressToString(address(_userPosition.from)),
        //         toToken: DescriptorUtils.addressToString(address(_userPosition.to)),
        //         fromDecimals: _userPosition.from.decimals(),
        //         toDecimals: _userPosition.to.decimals(),
        //         fromSymbol: _userPosition.from.symbol(),
        //         toSymbol: _userPosition.to.symbol(),
        //         swapInterval: '',
        //         swapsExecuted: _userPosition.swapsExecuted,
        //         toWithdraw: _userPosition.swapped,
        //         swapsLeft: _userPosition.swapsLeft,
        //         remaining: _userPosition.remaining,
        //         rate: _userPosition.rate
        //     })
        // );
    }

    function _constructTokenURI(ButtPlugParams memory _params) internal view returns (string memory) {
        string memory _name = _generateName(_params);
        string memory _description = _generateDescription(_params);
        string memory _image = Base64.encode(bytes(_generateSVG(_params)));
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            _name,
                            '", "description":"',
                            _description,
                            '", "image": "data:image/svg+xml;base64,',
                            _image,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function _generateDescription(ButtPlugParams memory _params) internal pure returns (string memory) {
        string memory _part1 = string(abi.encodePacked('DESCRIPTION'));
        return _part1; //string(abi.encodePacked(_part1, _part2));
    }

    function _generateName(ButtPlugParams memory _params) internal pure returns (string memory) {
        return string(abi.encodePacked('ButtPlug Badge - ', _params.badgeId));
    }

    function _generateSVG(ButtPlugParams memory _params) internal view returns (string memory) {
        uint32 _percentage = 100; //(_params.swapsExecuted + _params.swapsLeft) > 0
            // ? (_params.swapsExecuted * 100) / (_params.swapsExecuted + _params.swapsLeft)
            // : 100;
        return string(
            abi.encodePacked(
                '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 580.71 1118.71" >',
                _generateStyleDefs(_percentage),
                _generateSVGDefs(),
                _generateSVGBackground(),
                _generateSVGCardMantle(_params),
                _generateSVGPositionData(_params),
                _generateSVGBorderText(_params),
                _generateSVGLinesAndMainLogo(_percentage),
                // _generageSVGProgressArea(_params),
                '</svg>'
            )
        );
    }

    function _generateStyleDefs(uint32 _percentage) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<style type="text/css">.st0{fill:url(#SVGID_1)}.st1{fill:none;stroke:#fff;stroke-miterlimit:10}.st2{opacity:.5}.st3{fill:none;stroke:#b5baba;stroke-miterlimit:10}.st36{fill:#fff}.st37{fill:#48a7de}.st38{font-family:"Verdana"}.st39{font-size:60px}.st40{letter-spacing:-4}.st44{font-size:25px}.st46{fill:#c6c6c6}.st47{font-size:18px}.st48{font-size:19.7266px}.st49{font-family:"Verdana";font-weight:bold}.st50{font-size:38px}.st52{stroke:#848484;mix-blend-mode:multiply}.st55{opacity:.2;fill:#fff}.st57{fill:#48a7de;stroke:#fff;stroke-width:2.8347;stroke-miterlimit:10}.st58{font-size:18px}.cls-79{stroke:#d1dbe0;transform:rotate(-90deg);transform-origin:290.35px 488.04px;animation:dash 2s linear alternate forwards}@keyframes dash{from{stroke-dashoffset:750.84}to{stroke-dashoffset:',
                (((100 - _percentage) * 75084) / 10000).toString(),
                ';}}</style>'
            )
        );
    }

    function _generateSVGDefs() internal pure returns (string memory) {
        return
        '<defs><path id="SVGID_0" class="st2" d="M580.71 1042.17c0 42.09-34.44 76.54-76.54 76.54H76.54c-42.09 0-76.54-34.44-76.54-76.54V76.54C0 34.44 34.44 0 76.54 0h427.64c42.09 0 76.54 34.44 76.54 76.54v965.63z"/><path id="text-path-a" d="M81.54 1095.995a57.405 57.405 0 0 1-57.405-57.405V81.54A57.405 57.405 0 0 1 81.54 24.135h417.64a57.405 57.405 0 0 1 57.405 57.405v955.64a57.405 57.405 0 0 1-57.405 57.405z"/><path id="text-path-executed" d="M290.35 348.77a139.5 139.5 0 1 1 0 279 139.5 139.5 0 1 1 0-279"/><path id="text-path-left" d="M290.35 348.77a-139.5-139.5 0 1 0 0 279 139.5 139.5 0 1 0 0-279"/><radialGradient id="SVGID_3" cx="334.831" cy="592.878" r="428.274" fx="535.494" fy="782.485" gradientUnits="userSpaceOnUse"><stop offset="0"/><stop offset=".11" stop-color="#0d1f29"/><stop offset=".28" stop-color="#1f4860"/><stop offset=".45" stop-color="#2e6a8d"/><stop offset=".61" stop-color="#3985b0"/><stop offset=".76" stop-color="#4198c9"/><stop offset=".89" stop-color="#46a3d9"/><stop offset="1" stop-color="#48a7de"/>&gt;</radialGradient><linearGradient id="SVGID_1" gradientUnits="userSpaceOnUse" x1="290.353" y1="0" x2="290.353" y2="1118.706"><stop offset="0" stop-color="#48a7de"/><stop offset=".5" stop-color="#121612"/><stop offset=".91" stop-color="#010100"/><stop offset="1"/></linearGradient><clipPath id="SVGID_2"><use xlink:href="#SVGID_0" overflow="visible"/></clipPath></defs>';
    }

    function _generateSVGBackground() internal pure returns (string memory) {
        return
        '<path d="M580.71 1042.17c0 42.09-34.44 76.54-76.54 76.54H76.54c-42.09 0-76.54-34.44-76.54-76.54V76.54C0 34.44 34.44 0 76.54 0h427.64c42.09 0 76.54 34.44 76.54 76.54v965.63z" fill="url(#SVGID_1)"/><path d="M76.54 1081.86c-21.88 0-39.68-17.8-39.68-39.68V76.54c0-21.88 17.8-39.69 39.68-39.69h427.64c21.88 0 39.68 17.8 39.68 39.69v965.64c0 21.88-17.8 39.68-39.68 39.68H76.54z" fill="none" stroke="#fff" stroke-miterlimit="10"/>';
    }

    function _generateSVGBorderText(ButtPlugParams memory _params) internal view returns (string memory) {
        string memory _text =
            string(abi.encodePacked('ButtPlug Wars - ', DescriptorUtils.addressToString(address(this))));

        return string(
            abi.encodePacked(
                _generateTextWithPath('-100', _text),
                _generateTextWithPath('0', _text),
                _generateTextWithPath('50', _text),
                _generateTextWithPath('-50', _text)
            )
        );
    }

    function _generateTextWithPath(string memory _offset, string memory _text) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<text text-rendering="optimizeSpeed"><textPath startOffset="',
                _offset,
                '%" xlink:href="#text-path-a" class="st46 st38 st47">',
                _text,
                '<animate additive="sum" attributeName="startOffset" from="0%" to="100%" dur="60s" repeatCount="indefinite" /></textPath></text>'
            )
        );
    }

    function _generateSVGCardMantle(ButtPlugParams memory _params) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<text><tspan x="68.3549" y="146.2414" class="st36 st38 st39 st40">',
                'Player Badge',
                '</tspan></tspan></text><text x="68.3549" y="225.9683" class="st36 st49 st50">',
                'Team A',
                '</text>'
            )
        );
    }

    function _generageSVGProgressArea(ButtPlugParams memory _params) internal pure returns (string memory) {
        // return string(
        //     abi.encodePacked(
        //         '<text text-rendering="optimizeSpeed"><textPath xlink:href="#text-path-executed"><tspan class="st38 st58" fill="#d1dbe0" style="text-shadow:#214c64 0px 0px 5px">Executed*: ',
        //         _params.swapsExecuted.toString(),
        //         _params.swapsExecuted != 1 ? ' swaps' : ' swap',
        //         '</tspan></textPath></text><text text-rendering="optimizeSpeed"><textPath xlink:href="#text-path-left" startOffset="30%" ><tspan class="st38 st58" alignment-baseline="hanging" fill="#153041" stroke="#000" stroke-width="0.5">Left: ',
        //         _params.swapsLeft.toString(),
        //         _params.swapsLeft != 1 ? ' swaps' : ' swap',
        //         '</tspan></textPath></text>'
        //     )
        // );
    }

    function _generateSVGPositionData(ButtPlugParams memory _params) internal pure returns (string memory) {
        string memory _toWithdraw = '_toWithdraw'; // _amountToReadable(1, 2, '3');
        string memory _swapped = '_swapped';
        // _amountToReadable(_params.rate * _params.swapsExecuted, _params.fromDecimals, _params.fromSymbol);
        string memory _remaining = '_remaining'; //_amountToReadable(_params.remaining, _params.fromDecimals, _params.fromSymbol);
        string memory _rate = '_rate'; //_amountToReadable(_params.rate, _params.fromDecimals, _params.fromSymbol);
        return string(
            abi.encodePacked(
                '<text transform="matrix(1 0 0 1 68.3549 775.8853)"><tspan x="0" y="0" class="st36 st38 st44">Id: ',
                '_params.tokenId',
                '</tspan><tspan x="0" y="52.37" class="st36 st38 st44">To Withdraw: ',
                _toWithdraw,
                '</tspan><tspan x="0" y="104.73" class="st36 st38 st44">Swapped*: ',
                _swapped,
                '</tspan><tspan x="0" y="157.1" class="st36 st38 st44">Remaining: ',
                _remaining,
                '</tspan><tspan x="0" y="209.47" class="st36 st38 st44">Rate: ',
                _rate,
                '</tspan></text>'
            )
        );
    }

    function _generateSVGLinesAndMainLogo(uint32 _percentage) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<path class="st1" d="M68.35 175.29h440.12M68.35 249.38h440.12M68.35 737.58h440.12M68.35 792.11h440.12M68.35 844.47h440.12M68.35 896.82h440.12M68.35 949.17h440.12M68.35 1001.53h440.12"/>'
            )
        );
    }

    function _amountToReadable(uint256 _amount, uint8 _decimals, string memory _symbol)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(DescriptorUtils.fixedPointToDecimalString(_amount, _decimals), ' ', _symbol));
    }
}

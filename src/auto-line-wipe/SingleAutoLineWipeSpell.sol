// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.8.16;

import {DssEmergencySpell} from "../DssEmergencySpell.sol";

interface LineMomLike {
    function wipe(bytes32 ilk) external returns (uint256);
    function autoLine() external view returns (address);
}

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
}

contract SingleAutoLineWipeSpell is DssEmergencySpell {
    LineMomLike public immutable lineMom = LineMomLike(_log.getAddress("LINE_MOM"));
    bytes32 public immutable ilk;

    event Wipe();

    constructor(bytes32 _ilk) {
        ilk = _ilk;
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | Auto-Line Wipe: ", ilk));
    }

    function _emergencyActions() internal override {
        lineMom.wipe(ilk);
        emit Wipe();
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the ilk has been wiped from auto-line.
     */
    function done() external view returns (bool) {
        (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) =
            AutoLineLike(lineMom.autoLine()).ilks(ilk);

        return maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0;
    }
}

contract SingleAutoLineWipeFactory {
    event Deploy(bytes32 indexed ilk, address spell);

    function deploy(bytes32 ilk) external returns (address spell) {
        spell = address(new SingleAutoLineWipeSpell(ilk));
        emit Deploy(ilk, spell);
    }
}

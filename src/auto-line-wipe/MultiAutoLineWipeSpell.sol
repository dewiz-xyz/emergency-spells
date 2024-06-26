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

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
}

interface LineMomLike {
    function autoLine() external view returns (address);
    function ilks(bytes32 ilk) external view returns (uint256);
    function wipe(bytes32 ilk) external;
}

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
}

contract MultiAutoLineWipeSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | Multi AutoLine Wipe";

    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));
    LineMomLike public immutable lineMom = LineMomLike(_log.getAddress("LINE_MOM"));

    event Wipe(bytes32 indexed ilk);

    /**
     * @notice Wipes, when possible, all ilks from auto-line;
     */
    function _emergencyActions() internal override {
        bytes32[] memory ilks = ilkReg.list();
        _doWipe(ilks);
    }

    /**
     * @notice Wipe all ilks in the batch from auto-line.
     * @dev This is an escape hatch to prevent this spell from being blocked in case it would hit the block gas limit.
     *      In case `end` is greater than the ilk registry length, the iteration will be automatically capped.
     * @param start The index to start the iteration (inclusive).
     * @param end The index to stop the iteration (inclusive).
     */
    function stopBatch(uint256 start, uint256 end) external {
        uint256 maxEnd = ilkReg.count() - 1;
        bytes32[] memory ilks = ilkReg.list(start, end < maxEnd ? end : maxEnd);
        _doWipe(ilks);
    }

    /**
     * @notice Stops, when possible, all OSMs that can be found from the `ilks` list.
     * @param ilks The list of ilks to consider.
     */
    function _doWipe(bytes32[] memory ilks) internal {
        for (uint256 i = 0; i < ilks.length; i++) {
            if (lineMom.ilks(ilks[i]) == 0) continue;

            LineMomLike(lineMom).wipe(ilks[i]);
            emit Wipe(ilks[i]);
        }
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if all possible ilks from the ilk registry are wiped from auto-line.
     */
    function done() external view returns (bool) {
        AutoLineLike autoLine = AutoLineLike(lineMom.autoLine());
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            if (lineMom.ilks(ilks[i]) == 0) continue;

            (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(ilks[i]);
            // If any of the entries in auto-line has non zero values, then the spell can be cast again.
            if (!(maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0)) {
                return false;
            }
        }
        return true;
    }
}

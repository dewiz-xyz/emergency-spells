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

interface OsmMomLike {
    function osms(bytes32 ilk) external view returns (address);
    function stop(bytes32 ilk) external;
}

interface OsmLike {
    function stopped() external view returns (uint256);
}

contract SingleOsmStopSpell is DssEmergencySpell {
    OsmMomLike public immutable osmMom = OsmMomLike(_log.getAddress("OSM_MOM"));
    bytes32 public immutable ilk;

    event Stop(address indexed osm);

    constructor(bytes32 _ilk) {
        ilk = _ilk;
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | OSM Stop: ", ilk));
    }

    function _emergencyActions() internal override {
        osmMom.stop(ilk);
        emit Stop(osmMom.osms(ilk));
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the OSM instance is stopped.
     */
    function done() external view returns (bool) {
        return OsmLike(osmMom.osms(ilk)).stopped() == 1;
    }
}

contract SingleOsmStopFactory {
    event Deploy(bytes32 indexed ilk, address spell);

    function deploy(bytes32 ilk) external returns (address spell) {
        spell = address(new SingleOsmStopSpell(ilk));
        emit Deploy(ilk, spell);
    }
}

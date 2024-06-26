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

interface DdmMomLike {
    function disable(address plan) external;
}

interface DdmPlanLike {
    function active() external view returns (bool);
}

interface DdmHubLike {
    function plan(bytes32 ilk) external view returns (address plan);
}

contract SingleDdmDisableSpell is DssEmergencySpell {
    DdmMomLike public immutable ddmMom = DdmMomLike(_log.getAddress("DIRECT_MOM"));
    DdmHubLike public immutable ddmHub = DdmHubLike(_log.getAddress("DIRECT_HUB"));
    bytes32 public immutable ilk;

    event Disable(address indexed plan);

    constructor(bytes32 _ilk) {
        ilk = _ilk;
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | Disable DDM Plan: ", ilk));
    }

    function _emergencyActions() internal override {
        address plan = ddmHub.plan(ilk);
        ddmMom.disable(plan);
        emit Disable(plan);
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the plan instance has stopped = 3.
     */
    function done() external view returns (bool) {
        return DdmPlanLike(ddmHub.plan(ilk)).active() == false;
    }
}

contract SingleDdmDisableFactory {
    event Deploy(bytes32 indexed ilk, address spell);

    function deploy(bytes32 ilk) external returns (address spell) {
        spell = address(new SingleDdmDisableSpell(ilk));
        emit Deploy(ilk, spell);
    }
}

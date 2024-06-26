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

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssTest, DssInstance, MCD, GodMode} from "dss-test/DssTest.sol";
import {DssEmergencySpell} from "./DssEmergencySpell.sol";

contract DssEmergencySpellImpl is DssEmergencySpell {
    string public constant override description = "Emergency Spell";
    bool public constant override done = false;

    event EmergencyAction();

    // No-op
    function _emergencyActions() internal override {
        emit EmergencyAction();
    }
}

contract DssEmergencySpellTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    DssEmergencySpell spell;
    address pause;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);

        spell = new DssEmergencySpellImpl();
        pause = dss.chainlog.getAddress("MCD_PAUSE");
    }

    function testEmergencySpell() public {
        // Sanity checks

        assertEq(spell.pause(), pause, "invalid pause");
        assertEq(spell.action(), address(spell), "invalid action");
        assertEq(spell.eta(), 0, "invalid eta");
        assertEq(spell.nextCastTime(), block.timestamp, "invalid nextCastTime");
        assertEq(spell.nextCastTime(1231298123), block.timestamp, "invalid nextCastTime(uint256)");
        assertEq(spell.officeHours(), false, "invalid officeHours");
        assertEq(spell.sig(), abi.encodeWithSignature("execute()"), "invalid sig");
        {
            bytes32 hash;
            address _spell = address(spell);
            assembly {
                hash := extcodehash(_spell)
            }
            assertEq(spell.tag(), hash, "invalid tag");
        }

        // No-op checks. Allows some overhead for JUMPs and computation in the test itself.

        uint256 beforeCast = gasleft();
        spell.cast();
        assertApproxEqAbs(gasleft(), beforeCast, 800, "cast is not a no-op");

        uint256 beforeExecute = gasleft();
        spell.execute();
        assertApproxEqAbs(gasleft(), beforeExecute, 800, "execute is not a no-op");

        uint256 beforeActions = gasleft();
        spell.actions();
        assertApproxEqAbs(gasleft(), beforeActions, 800, "actions is not a no-op");

        // `schedule()` actually calls `_emergencyActions()`

        vm.expectEmit(true, true, true, true);
        emit EmergencyAction();
        spell.schedule();
    }

    event EmergencyAction();
}

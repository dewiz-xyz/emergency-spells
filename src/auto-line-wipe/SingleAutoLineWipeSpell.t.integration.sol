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
import {DssEmergencySpellLike} from "../DssEmergencySpell.sol";
import {SingleAutoLineWipeFactory} from "./SingleAutoLineWipeSpell.sol";

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
}

contract SingleAutoLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    bytes32 ilk = "ETH-A";
    address lineMom;
    AutoLineLike autoLine;
    SingleAutoLineWipeFactory factory;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        lineMom = dss.chainlog.getAddress("LINE_MOM");
        autoLine = AutoLineLike(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE"));
        factory = new SingleAutoLineWipeFactory();
        spell = DssEmergencySpellLike(factory.deploy(ilk));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testAutoLineWipeOnSchedule() public {
        (uint256 pmaxLine, uint256 pgap,,,) = autoLine.ilks(ilk);
        assertGt(pmaxLine, 0, "before: auto-line already wiped");
        assertGt(pgap, 0, "before: auto-line already wiped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, false);
        emit Wipe();
        spell.schedule();

        (uint256 maxLine, uint256 gap,,,) = autoLine.ilks(ilk);
        assertEq(maxLine, 0, "after: auto-line not wiped (maxLine)");
        assertEq(gap, 0, "after: auto-line not wiped (gap)");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertAutoLineWipeWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        (uint256 pmaxLine, uint256 pgap,,,) = autoLine.ilks(ilk);
        assertGt(pmaxLine, 0, "before: auto-line already wiped");
        assertGt(pgap, 0, "before: auto-line already wiped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        (uint256 maxLine, uint256 gap,,,) = autoLine.ilks(ilk);
        assertGt(maxLine, 0, "after: auto-line wiped unexpectedly");
        assertGt(gap, 0, "after: auto-line wiped unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    event Wipe();
}

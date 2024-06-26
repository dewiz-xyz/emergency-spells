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
import {SingleClipBreakerFactory} from "./SingleClipBreakerSpell.sol";

interface IlkRegistryLike {
    function xlip(bytes32 ilk) external view returns (address);
}

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface ClipLike {
    function stopped() external view returns (uint256);
}

contract SingleClipBreakerSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    IlkRegistryLike ilkReg;
    bytes32 ilk = "ETH-A";
    ClipperMomLike clipMom;
    ClipLike clip;
    SingleClipBreakerFactory factory;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        clipMom = ClipperMomLike(dss.chainlog.getAddress("CLIPPER_MOM"));
        clip = ClipLike(ilkReg.xlip(ilk));
        factory = new SingleClipBreakerFactory();
        spell = DssEmergencySpellLike(factory.deploy(ilk));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testClipBreakerOnSchedule() public {
        assertEq(clip.stopped(), 0, "before: clip already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, true);
        emit SetBreaker(address(clip));
        spell.schedule();

        assertEq(clip.stopped(), 3, "after: clip not stopped");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertClipBreakerWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        assertEq(clip.stopped(), 0, "before: clip already stopped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        assertEq(clip.stopped(), 0, "after: clip stopped unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    event SetBreaker(address indexed clip);
}

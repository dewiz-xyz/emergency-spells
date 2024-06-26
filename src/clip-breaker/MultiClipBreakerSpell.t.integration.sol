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
import {MultiClipBreakerSpell} from "./MultiClipBreakerSpell.sol";

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
    function xlip(bytes32 ilk) external view returns (address);
}

interface WardsLike {
    function wards(address who) external view returns (uint256);
}

interface ClipLike {
    function stopped() external view returns (uint256);
}

contract MultiClipBreakerSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    IlkRegistryLike ilkReg;
    address clipperMom;
    MultiClipBreakerSpell spell;

    mapping(bytes32 => bool) ilksToIgnore;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        clipperMom = dss.chainlog.getAddress("CLIPPER_MOM");
        spell = new MultiClipBreakerSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        _initIlksToIgnore();

        vm.makePersistent(chief);
    }

    /// @dev Ignore any of:
    ///      - non-Clip contracts.
    ///      - Clip contracts that are already stopped at some level.
    ///      - Clip contracts that did not rely on ClipperMom.
    function _initIlksToIgnore() internal {
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            string memory ilkStr = string(abi.encodePacked(ilks[i]));
            address clip = ilkReg.xlip(ilks[i]);
            if (clip == address(0)) {
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | No clipper", ilkStr);
                continue;
            }

            try ClipLike(clip).stopped() returns (uint256 stopped) {
                if (stopped == 3) {
                    ilksToIgnore[ilks[i]] = true;
                    emit log_named_string("Ignoring ilk | Clip already has stopped = 3", ilkStr);
                    continue;
                }
            } catch {
                // Most likely not a Clip instance.
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | Not a Clip", ilkStr);
                continue;
            }

            try WardsLike(clip).wards(clipperMom) returns (uint256 ward) {
                if (ward == 0) {
                    ilksToIgnore[ilks[i]] = true;
                    emit log_named_string("Ignoring ilk | ClipperMom not authorized", ilkStr);
                    continue;
                }
            } catch {
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | Not a Clip", ilkStr);
                continue;
            }
        }
    }

    function testMultiClipBreakerOnSchedule() public {
        _checkClipMaxStoppedStatus({ilks: ilkReg.list(), maxExpected: 2});
        assertFalse(spell.done(), "before: spell already done");

        spell.schedule();

        _checkClipStoppedStatus({ilks: ilkReg.list(), expected: 3});
        assertTrue(spell.done(), "after: spell not done");
    }

    function testMultiClipBreakerInBatches_Fuzz(uint256 batchSize) public {
        batchSize = bound(batchSize, 1, type(uint128).max);
        uint256 count = ilkReg.count();
        uint256 maxEnd = count - 1;
        uint256 start = 0;
        // End is inclusive, so we need to subtract 1
        uint256 end = start + batchSize - 1;

        _checkClipMaxStoppedStatus({ilks: ilkReg.list(), maxExpected: 2});

        while (start < count) {
            spell.setBreakerInBatch(start, end);

            _checkClipStoppedStatus({ilks: ilkReg.list(start, end < maxEnd ? end : maxEnd), expected: 3});

            start += batchSize;
            end += batchSize;
        }

        // Sanity check: the test iterated over the entire ilk registry.
        _checkClipStoppedStatus({ilks: ilkReg.list(), expected: 3});
    }

    function testUnauthorizedClipperMomShouldNotRevert() public {
        address clipEthA = ilkReg.xlip("ETH-A");
        // De-auth ClipperMom to force the error:
        stdstore.target(clipEthA).sig("wards(address)").with_key(clipperMom).checked_write(bytes32(0));
        // Updates the list of ilks to be ignored.
        _initIlksToIgnore();

        _checkClipMaxStoppedStatus({ilks: ilkReg.list(), maxExpected: 2});

        spell.schedule();

        _checkClipStoppedStatus({ilks: ilkReg.list(), expected: 3});
        assertEq(ClipLike(clipEthA).stopped(), 0, "ETH-A Clip was not ignored");
    }

    function testRevertMultiClipBreakerWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        _checkClipMaxStoppedStatus({ilks: ilkReg.list(), maxExpected: 2});
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        _checkClipMaxStoppedStatus({ilks: ilkReg.list(), maxExpected: 2});
        assertFalse(spell.done(), "false: spell done unexpectedly");
    }

    function _checkClipMaxStoppedStatus(bytes32[] memory ilks, uint256 maxExpected) internal view {
        assertTrue(ilks.length > 0, "empty ilks list");

        for (uint256 i = 0; i < ilks.length; i++) {
            if (ilksToIgnore[ilks[i]]) continue;

            address clip = ilkReg.xlip(ilks[i]);
            assertLe(
                ClipLike(clip).stopped(), maxExpected, string(abi.encodePacked("invalid stopped status: ", ilks[i]))
            );
        }
    }

    function _checkClipStoppedStatus(bytes32[] memory ilks, uint256 expected) internal view {
        assertTrue(ilks.length > 0, "empty ilks list");

        for (uint256 i = 0; i < ilks.length; i++) {
            if (ilksToIgnore[ilks[i]]) continue;

            address clip = ilkReg.xlip(ilks[i]);
            assertEq(ClipLike(clip).stopped(), expected, string(abi.encodePacked("invalid stopped status: ", ilks[i])));
        }
    }
}

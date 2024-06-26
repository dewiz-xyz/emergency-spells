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

interface OsmMomLike {
    function stop(bytes32 ilk) external;
    function osms(bytes32 ilk) external view returns (address);
}

interface OsmLike {
    function stopped() external view returns (uint256);
    function wards(address who) external view returns (uint256);
}

contract MultiOsmStopSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | Multi OSM Stop";

    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));
    OsmMomLike public immutable osmMom = OsmMomLike(_log.getAddress("OSM_MOM"));

    event Stop(bytes32 indexed ilk, address indexed osm);

    /**
     * @notice Stops, when possible, all OSMs that can be found through the ilk registry.
     */
    function _emergencyActions() internal override {
        bytes32[] memory ilks = ilkReg.list();
        _doStop(ilks);
    }

    /**
     * @notice Stops all OSMs in the batch.
     * @dev This is an escape hatch to prevent this spell from being blocked in case it would hit the block gas limit.
     *      In case `end` is greater than the ilk registry length, the iteration will be automatically capped.
     * @param start The index to start the iteration (inclusive).
     * @param end The index to stop the iteration (inclusive).
     */
    function stopBatch(uint256 start, uint256 end) external {
        uint256 maxEnd = ilkReg.count() - 1;
        bytes32[] memory ilks = ilkReg.list(start, end < maxEnd ? end : maxEnd);
        _doStop(ilks);
    }

    /**
     * @notice Stops, when possible, all OSMs that can be found from the `ilks` list.
     * @param ilks The list of ilks to consider.
     */
    function _doStop(bytes32[] memory ilks) internal {
        for (uint256 i = 0; i < ilks.length; i++) {
            address osm = osmMom.osms(ilks[i]);

            if (osm == address(0)) continue;

            try OsmLike(osm).wards(address(osmMom)) returns (uint256 ward) {
                // Ignore Osm instances that have not relied on OsmMom.
                if (ward == 0) continue;
            } catch Error(string memory reason) {
                // If the reason is empty, it means the contract is most likely not an OSM instance.
                require(bytes(reason).length == 0, reason);
            }

            // There might be some duplicate calls to the same OSM, however they are idempotent.
            try OsmMomLike(osmMom).stop(ilks[i]) {
                emit Stop(ilks[i], osm);
            } catch Error(string memory reason) {
                // If the reason is empty, it means the contract is most likely not an OSM instance.
                require(bytes(reason).length == 0, reason);
            }
        }
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if all possible OSM instances from the ilk registry are stopped.
     */
    function done() external view returns (bool) {
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            address osm = osmMom.osms(ilks[i]);

            if (osm == address(0)) continue;

            try OsmLike(osm).wards(address(osmMom)) returns (uint256 ward) {
                // Ignore Osm instances that have not relied on OsmMom.
                if (ward == 0) continue;
            } catch {
                // If the call failed, it means the contract is most likely not an OSM instance, so it can be ignored.
                continue;
            }

            try OsmLike(osm).stopped() returns (uint256 stopped) {
                // If any of the OSMs that match the conditions is not stopped, the spell was not executed yet.
                if (stopped == 0) return false;
            } catch {
                // If the call failed, it means the contract is most likely not an OSM instance, so it can be ignored.
                continue;
            }
        }
        return true;
    }
}

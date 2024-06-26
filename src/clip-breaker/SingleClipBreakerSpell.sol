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

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface ClipLike {
    function stopped() external view returns (uint256);
}

interface IlkRegistryLike {
    function xlip(bytes32 ilk) external view returns (address);
}

contract SingleClipBreakerSpell is DssEmergencySpell {
    /// @dev During an emergency, set the breaker level to 3  to prevent botyh `kick()`, `redo()` and `take()`.
    uint256 public constant BREAKER_LEVEL = 3;
    /// @dev The delay is not applicable for level 3 breakers, so we set it to zero.
    uint256 public constant BREAKER_DELAY = 0;

    ClipperMomLike public immutable clipperMom = ClipperMomLike(_log.getAddress("CLIPPER_MOM"));
    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));
    bytes32 public immutable ilk;

    event SetBreaker(address indexed clip);

    constructor(bytes32 _ilk) {
        ilk = _ilk;
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | Set Clip Breaker: ", ilk));
    }

    function _emergencyActions() internal override {
        address clip = ilkReg.xlip(ilk);
        clipperMom.setBreaker(clip, BREAKER_LEVEL, BREAKER_DELAY);
        emit SetBreaker(clip);
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the Clip instance has stopped = 3.
     */
    function done() external view returns (bool) {
        return ClipLike(ilkReg.xlip(ilk)).stopped() == BREAKER_LEVEL;
    }
}

contract SingleClipBreakerFactory {
    event Deploy(bytes32 indexed ilk, address spell);

    function deploy(bytes32 ilk) external returns (address spell) {
        spell = address(new SingleClipBreakerSpell(ilk));
        emit Deploy(ilk, spell);
    }
}

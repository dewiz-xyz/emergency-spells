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

interface ChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface DssExec {
    function action() external view returns (address);
    function cast() external;
    function description() external view returns (string memory);
    function done() external view returns (bool);
    function eta() external view returns (uint256);
    function expiration() external view returns (uint256);
    function log() external view returns (address);
    function nextCastTime() external view returns (uint256);
    function officeHours() external view returns (bool);
    function pause() external view returns (address);
    function schedule() external;
    function sig() external view returns (bytes memory);
    function tag() external view returns (bytes32);
}

interface DssAction {
    function actions() external;
    function description() external view returns (string memory);
    function execute() external;
    function nextCastTime(uint256 eta) external view returns (uint256);
    function officeHours() external view returns (bool);
}

interface DssEmergencySpellLike is DssExec, DssAction {
    function description() external view override(DssExec, DssAction) returns (string memory);
    function officeHours() external view override(DssExec, DssAction) returns (bool);
}

abstract contract DssEmergencySpell is DssEmergencySpellLike {
    /// @dev The chainlog contract reference.
    ChainlogLike internal constant _log = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    // @dev The reference to the `pause` contract.
    address public immutable pause = _log.getAddress("MCD_PAUSE");
    /// @dev The chainlog address.
    address public constant log = address(_log);
    /// @dev In regular spells, `eta` is used to enforce the GSM delay.
    ///      For emergency spells, the GSM delay is not applicable.
    uint256 public constant eta = 0;
    /// @dev Keeping the same value as regular spells.
    bytes public constant sig = abi.encodeWithSelector(DssAction.execute.selector);
    /// @dev Emergency spells should not expire.
    uint256 public constant expiration = type(uint256).max;
    // @dev Office Hours is always `false` for emergency spells.
    bool public constant officeHours = false;
    // @dev `action` is expected to return a valid address.
    //      We also implement the `DssAction` interface in this contract.
    address public immutable action = address(this);
    // @dev An emergency spell can be cast as soon as it is deployed.
    //      Notice that cast is always a no-op.
    uint256 internal immutable _nextCastTime = block.timestamp;

    /**
     * @dev In regular spells, `tag` is an immutable variable with the code hash of the spell action.
     *      It specifically uses a separate contract for spell action because `tag` is immutable and the code hash of
     *      the contract being initialized is not accessible in the constructor.
     *      Since we do not have a separate contract for actions in Emergency Spells, `tag` has to be turned into a
     *      getter function instead of an immutable variable.
     * @return The contract codehash.
     */
    function tag() external view returns (bytes32) {
        return address(this).codehash;
    }

    /**
     * @notice Triggers the emergency actions of the spell.
     * @dev Emergency spells are triggered when scheduled.
     *      This function maintains the name for compatibility with regular spells, however nothing is actually being
     *      scheduled. Emergency spells take affect immediately, so there is no need to call `pause.plot()`.
     */
    function schedule() external {
        _emergencyActions();
    }

    /**
     * @notice Implements the emergency actions to be triggered by the spell.
     */
    function _emergencyActions() internal virtual;

    /**
     * @notice Returns `_nextCastTime`.
     * @dev this function exists only to keep interface compatibility with regular spells.
     */
    function nextCastTime() external view returns (uint256 castTime) {
        return _nextCastTime;
    }

    /**
     * @notice No-op.
     * @dev this function exists only to keep interface compatibility with regular spells.
     */
    function cast() external {}

    /**
     * @notice No-op.
     * @dev this function exists only to keep interface compatibility with regular spells.
     */
    function execute() external {}

    /**
     * @notice No-op.
     * @dev this function exists only to keep interface compatibility with regular spells.
     */
    function actions() external {}

    /**
     * @notice Returns `nextCastTime`, regardless of the input parameter.
     * @dev this function exists only to keep interface compatibility with regular spells.
     */
    function nextCastTime(uint256) external view returns (uint256 castTime) {
        return _nextCastTime;
    }
}

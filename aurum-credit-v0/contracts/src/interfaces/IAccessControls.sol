






// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IAccessControls
 * @notice Interface for role-based access control system
 */
interface IAccessControls is IAccessControl {
    // Custom roles
    function VAULT_MANAGER_ROLE() external view returns (bytes32);
    function ORACLE_MANAGER_ROLE() external view returns (bytes32);
    function AUCTION_MANAGER_ROLE() external view returns (bytes32);
    function INSURANCE_MANAGER_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);

    // Extended view functions
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
}






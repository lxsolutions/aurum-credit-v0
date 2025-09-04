






// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IAccessControls} from "./interfaces/IAccessControls.sol";

/**
 * @title AccessControls
 * @notice Role-based access control system for Aurum Credit protocol
 * @dev Manages permissions for different protocol functions
 */
contract AccessControls is IAccessControls, AccessControl {
    // Role definitions
    bytes32 public constant override VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant override ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    bytes32 public constant override AUCTION_MANAGER_ROLE = keccak256("AUCTION_MANAGER_ROLE");
    bytes32 public constant override INSURANCE_MANAGER_ROLE = keccak256("INSURANCE_MANAGER_ROLE");
    bytes32 public constant override KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant override PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor() {
        // Grant deployer the default admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Set up role admins
        _setRoleAdmin(VAULT_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ORACLE_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(AUCTION_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(INSURANCE_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(KEEPER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        
        // Grant initial roles to deployer
        _grantRole(VAULT_MANAGER_ROLE, msg.sender);
        _grantRole(ORACLE_MANAGER_ROLE, msg.sender);
        _grantRole(AUCTION_MANAGER_ROLE, msg.sender);
        _grantRole(INSURANCE_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @notice Grant a role to an account
     * @param role Role to grant
     * @param account Account to grant role to
     */
    function grantRole(bytes32 role, address account) public override(IAccessControl, AccessControl) {
        super.grantRole(role, account);
    }

    /**
     * @notice Revoke a role from an account
     * @param role Role to revoke
     * @param account Account to revoke role from
     */
    function revokeRole(bytes32 role, address account) public override(IAccessControl, AccessControl) {
        super.revokeRole(role, account);
    }

    /**
     * @notice Renounce a role from the calling account
     * @param role Role to renounce
     * @param account Account to renounce role from
     */
    function renounceRole(bytes32 role, address account) public override(IAccessControl, AccessControl) {
        super.renounceRole(role, account);
    }

    /**
     * @notice Check if an account has a specific role
     * @param role Role to check
     * @param account Account to check
     * @return hasRole Whether the account has the role
     */
    function hasRole(bytes32 role, address account) public view override(IAccessControl, AccessControl) returns (bool) {
        return super.hasRole(role, account);
    }

    /**
     * @notice Get the admin role for a given role
     * @param role Role to get admin for
     * @return adminRole Admin role
     */
    function getRoleAdmin(bytes32 role) public view override(IAccessControl, AccessControl) returns (bytes32) {
        return super.getRoleAdmin(role);
    }

    /**
     * @notice Get the number of accounts with a specific role
     * @param role Role to check
     * @return count Number of accounts with the role
     */
    function getRoleMemberCount(bytes32 role) public view override returns (uint256) {
        return getRoleMemberCount(role);
    }

    /**
     * @notice Get a specific member of a role
     * @param role Role to check
     * @param index Index of the member
     * @return member Address of the role member
     */
    function getRoleMember(bytes32 role, uint256 index) public view override returns (address) {
        return getRoleMember(role, index);
    }

    // Role-specific convenience functions
    function isVaultManager(address account) public view returns (bool) {
        return hasRole(VAULT_MANAGER_ROLE, account);
    }

    function isOracleManager(address account) public view returns (bool) {
        return hasRole(ORACLE_MANAGER_ROLE, account);
    }

    function isAuctionManager(address account) public view returns (bool) {
        return hasRole(AUCTION_MANAGER_ROLE, account);
    }

    function isInsuranceManager(address account) public view returns (bool) {
        return hasRole(INSURANCE_MANAGER_ROLE, account);
    }

    function isKeeper(address account) public view returns (bool) {
        return hasRole(KEEPER_ROLE, account);
    }

    function isPauser(address account) public view returns (bool) {
        return hasRole(PAUSER_ROLE, account);
    }
}






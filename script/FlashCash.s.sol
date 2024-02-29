// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LendingPool} from "src/v2/flash-cash/LendingPool.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployFlashCashChallenge is Script {

    // ---- Usage ----
    // forge script script/FlashCash.s.sol:DeployFlashCashChallenge --chain-id 2442 --rpc-url https://rpc.cardona.zkevm-rpc.com --broadcast

    IERC20 public constant CRDNA = IERC20(0x94ab230b92A3f2899e81d46d4E874c6F006c88Aa);

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        LendingPool _lendingPool = new LendingPool();

        // seed the lending pool with CRDNA
        uint256 _amount = 10_000 * 1e18;
        CRDNA.approve(address(_lendingPool), _amount);
        _lendingPool.deposit(_amount);

        vm.stopBroadcast();
    }
}
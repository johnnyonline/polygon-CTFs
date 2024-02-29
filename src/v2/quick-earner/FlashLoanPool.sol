// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IFlashLoanEtherReceiver {
    function execute() external;
}

contract FlashLoanPool {

    using SafeERC20 for IERC20;

    IERC20 public constant CRDNA = IERC20(0x94ab230b92A3f2899e81d46d4E874c6F006c88Aa);

    error RepayFailed();

    event Deposit(address indexed who, uint256 amount);

    function deposit(uint256 _amount) external {
        CRDNA.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }

    function flashLoan(uint256 _amount) external {
        uint256 _balanceBefore = CRDNA.balanceOf(address(this));

        CRDNA.safeTransfer(msg.sender, _amount);
        IFlashLoanEtherReceiver(msg.sender).execute();

        if (CRDNA.balanceOf(address(this)) < _balanceBefore) revert RepayFailed();
    }
}
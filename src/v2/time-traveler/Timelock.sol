// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Timelock {

    using SafeERC20 for IERC20;

    uint256 public balance;
    uint256 public lockTime;

    IERC20 public constant CRDNA = IERC20(0x94ab230b92A3f2899e81d46d4E874c6F006c88Aa);

    event Deposit(address indexed _from, uint256 _amount);
    event Withdraw(address indexed _to, uint256 _amount);

    function deposit(uint256 _amount) external payable {
        balance += _amount;
        lockTime = block.timestamp + 1 weeks;

        emit Deposit(msg.sender, _amount);

        CRDNA.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function increaseLockTime(uint _secondsToIncrease) public {
        unchecked {
            lockTime += _secondsToIncrease;
        }
    }

    function withdraw() public {
        require(balance > 0, "Insufficient funds");
        require(block.timestamp > lockTime, "Lock time not expired");

        uint256 _amount = balance;
        balance = 0;

        emit Withdraw(msg.sender, _amount);

        CRDNA.safeTransfer(msg.sender, _amount);
    }
}
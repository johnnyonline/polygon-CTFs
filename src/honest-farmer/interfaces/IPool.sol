// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool {
    function totalSupply() external view returns (uint256);
    function getPoolId() external view returns (bytes32);
    function getNormalizedWeights() external view returns (uint256[] memory);
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface ICoin {
    function mint(address to, uint256 amount) external;
}

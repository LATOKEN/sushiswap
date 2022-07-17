// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

interface IZapLadex {
    function implementation() external view returns(address);
    function proxyOwner() external view returns(address);

    function owner() external view returns (address);

    function WETH() external view returns(address);
    function minimumAmount() view external returns(int256);

    function router() view external returns(address);

    function masterChef() view external returns(address);

    function initialize(address wethAddress, address routerAddress, address masterChefAddress) external;

    function setRouter(address routerAddress) external;

    function setMasterChef(address masterChefAddress) external;

    function deposit(uint256 pid, uint256 amount, address wantToken) external payable;

    function withdraw(uint256 pid, uint256 amount, address wantToken) external;

    function claim(uint256 pid) external;
}

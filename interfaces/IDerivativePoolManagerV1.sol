// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDerivativePoolManagerV1 {

    function entryPosition(address _user, address _from, address _to, uint256 _amount, uint256 _leverage, uint256 _orderType) external returns (uint256);
    function closePosition(address _user,address _from, address _to, uint256 _amountPosition, uint256 _orderType) external returns (uint256);
}

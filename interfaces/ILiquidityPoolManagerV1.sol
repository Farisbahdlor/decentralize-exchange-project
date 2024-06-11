// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidityPoolManagerV1 {

    struct Data{
        uint256 amount;
        uint256 index;
        uint256 timeLock;
    }

    function getPoolStaker(address _fromVault, address _provider) external view returns (Data [] memory);
    function getExactToken (address _from, address _to, uint256 _amountFromTokens) external view returns (uint256 _poolPrice);
    function initializePool (address _provider, address _fromVault, address _toVault, uint256 _amountFrom, uint256 _amountTo)external returns (bool);
    function depositStaking (address _staker, address _from, address _to, uint256 _amountStake, uint256 _timeLock) external returns (bool);
    function withdrawlStaking (address _staker, address _from, address _to, uint256 _amountStake, uint256 _index) external returns (bool);
    function swapToken(address _user, address _fromVault, address _toVault, uint256 _amountFromTokens) external returns (uint256);

    event DepositVault(address indexed depositor, uint256 numTokens);
    event WithdrawlVault(address indexed withdrawler, uint256 numTokens);
    event TransferVault(address indexed from, address indexed to, uint256 value);
    event ApprovalVault(address indexed owner, address indexed spender, uint256 value);
    event DeapprovalVault(address indexed owner, address indexed spender, uint256 value);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Vault {
    
    function totalSupplyVault() external view returns (uint256);
    function balanceOfVault(address account) external view returns (uint256);
    function allowanceVault(address owner, address spender) external view returns (uint256);
    function getNameVault() external returns (string memory);
    function getSymbolVault() external returns (string memory);
    function getDecimalsVault() external returns (uint8);

    function setPublicVariable(string memory name, string memory symbol, uint8 decimals) external returns (address);
    function setProtocolAddress (address _migrationAddress, address _lendingProtocol, address _liquidityPoolManagerV1, address _derivativePoolManagerV1) external returns (bool);
    function depositVault(address depositor, uint256 numTokens) external returns (bool);
    function withdrawlVault(address withdrawer, uint256 numTokens) external returns (bool);
    function transferVault(address sender, address recipient, uint256 amount) external returns (bool);
    function liquidityPoolDeposit (address owner, uint256 numTokens) external returns (bool);
    function liquidityPoolWithdrawl (address owner, uint256 numTokens) external returns (bool);
    function approveVault(address owner, address spender, uint256 amount) external returns (bool);
    function deapproveVault(address owner, address spender, uint256 numTokens) external returns (bool);
    function transferFromVault(address _spender, address sender, address recipient, uint256 amount) external returns (bool);

    event DepositVault(address indexed depositor, uint256 numTokens);
    event WithdrawlVault(address indexed withdrawler, uint256 numTokens);
    event TransferVault(address indexed from, address indexed to, uint256 value);
    event ApprovalVault(address indexed owner, address indexed spender, uint256 value);
    event DeapprovalVault(address indexed owner, address indexed spender, uint256 value);
}
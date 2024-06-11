// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IXchange {
    
    function vaultAddress (address originalContractAddress) external view returns (address Original, address Vault);
    function ERC20TokenRegistered () external view returns (address [] memory);
    function createVaultToken (address originalContractAddress, string memory _name, string memory _symbol, uint8 _decimals) external returns (bool);
    function balanceOf (address ERC20ContractAddress, address tokenOwner) external view returns (uint256);
    function deposit (address ERC20ContractAddress, uint256 _amount) external returns (bool);
    function withdrawl (address ERC20ContractAddress, uint _amount) external returns (bool);
    function approve(address ERC20ContractAddress, address _spender, uint256 _amount) external returns (uint256);
    function deapprove(address ERC20ContractAddress, address _spender, uint256 _amount) external returns (uint256);
    function transferFrom (address ERC20ContractAddress, address sender, address recepient, uint256 _amount) external returns (bool);
    function transfer(address ERC20ContractAddress, address recepient, uint256 _amount) external returns (bool);
    
    // function entryOrderBook(address _OriginalFromAsset, address _OriginalToAsset, int256 _OrderQty, int256 _OrderPrice, int _OrderType) external returns (bool);
    // function removeOrderBook (address _OriginalFromAsset, address _OriginalToAsset, int256 _OrderQty, int256 _OrderPrice) external returns (bool);
    // function getPrice (address _OriginalFromAsset, address _OriginalToAsset) external view returns (uint256, uint256); 

    function entryDerivativePosition (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amount, uint256 _leverage, uint256 _orderType) external returns (uint256); 
    function closeDerivativePosition (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amount, uint256 _orderType) external returns (uint256);  

    function initializePool (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountFrom, uint256 _amountTo)external returns (bool);
    function depositStaking (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountStake, uint256 _timeLock) external returns (bool);
    function withdrawlStaking (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountWithdrawl, uint256 _index) external returns (bool);
    function swapToken(address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountFromTokens) external returns (uint256);

    function lending (address _CollateralAsset, address _BorrowAsset, uint256 _Value, uint256 _DueTime) external returns (bool);
    function addCollateralLending(address _OriginalCollateralAsset, address _OriginalBorrowAsset, uint256 _Index, uint256 _AmountAdd) external returns (bool);
    function decreaseCollateralLending(address _OriginalCollateralAsset, address _OriginalBorrowAsset, uint256 _Index, uint256 _AmountAdd) external returns (bool);
    function LTVCheckLending(address _OriginalCollateralAsset, address _OriginalBorrowAsset, uint256 _Index, uint256 _Value) external view returns (uint256);
    

}
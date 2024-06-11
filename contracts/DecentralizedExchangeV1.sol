// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity ^0.8.0;

import "../interfaces/IAssetsPairOrderBook.sol";
import "../interfaces/IERC20Vault.sol";
import "../interfaces/ILiquidityPoolManagerV1.sol";
import "../interfaces/IDerivativePoolManagerV1.sol";
import "../interfaces/IXchange.sol";
import "../interfaces/ILendingProtocol.sol";
import {IERC20} from "ERC20/contracts/IERC20.sol";

contract ERC20Vault is IERC20Vault {

    string internal  name;
    string internal  symbol;
    uint8 internal   decimals;


    mapping(address => uint256) balances;
    mapping (address => uint256) allowanceLeft;
    mapping (address => uint256) liquidityLock;

    mapping(address => mapping (address => uint256)) allowed;

    mapping(address => uint) leverage;


    uint256 totalSupply_;
    address contractOwner;
    // address orderBook;
    address lendingProtocol;
    address liquidityPoolManagerV1;
    address derivativePoolManagerV1;
    address migrationAddress;
    address originalContractAddress;


   constructor(address _originalContractAddress, address _migrationAddress, address _lendingProtocol, address _liquidityPoolManagerV1, address _derivativePoolManagerV1) {
    totalSupply_ = 0;
    contractOwner = (msg.sender);
    // orderBook = _orderBook;
    migrationAddress = _migrationAddress;
    lendingProtocol = _lendingProtocol;
    liquidityPoolManagerV1 = _liquidityPoolManagerV1;
    derivativePoolManagerV1 = _derivativePoolManagerV1;
    originalContractAddress = _originalContractAddress;


    }

    modifier onlyAccHaveAccess {
        require(msg.sender == contractOwner || msg.sender == migrationAddress || msg.sender == liquidityPoolManagerV1 || msg.sender == derivativePoolManagerV1, "Only contract owner allow to use this function");
        _;
    }

    function getNameVault() external override view returns (string memory){
        return name;
    }

    function getSymbolVault() external override view returns (string memory){
        return symbol;
    }

    function getDecimalsVault() external override view returns (uint8){
        return decimals;
    }

    function setPublicVariable (string memory _name, string memory _symbol, uint8 _decimals) external onlyAccHaveAccess override returns (address) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        return (address(this));
    }

    function setProtocolAddress (address _migrationAddress, address _lendingProtocol, address _liquidityPoolManagerV1, address _derivativePoolManagerV1) external onlyAccHaveAccess override returns (bool){
        migrationAddress = _migrationAddress;
        lendingProtocol = _lendingProtocol;
        liquidityPoolManagerV1 = _liquidityPoolManagerV1;
        derivativePoolManagerV1 = _derivativePoolManagerV1;
        return true;
    }

    function totalSupplyVault() public override view returns (uint256) {
        return totalSupply_;
    }

    function balanceOfVault(address tokenOwner) public override view returns (uint256) {
        return balances[tokenOwner];
    }

    function depositVault(address depositor, uint256 numTokens) external onlyAccHaveAccess override returns (bool){
        require(IERC20 (originalContractAddress).allowance(depositor, address(this)) >= numTokens, "Not enough allowance to spend");
        require(IERC20 (originalContractAddress).transferFrom(depositor, address(this), numTokens), "Token deposit transfer failed");
        require (mint(address(0), numTokens), "Mint wrapped token failed");
        transferVault(address(0), depositor, numTokens);

        emit DepositVault(depositor, numTokens);
        return true;

    }

    function withdrawlVault(address withdrawer, uint256 numTokens) external onlyAccHaveAccess override returns (bool){
        require(balances[withdrawer] >= numTokens, "Not enough token to withdrawl");
        require(burn(withdrawer, numTokens), "Burn wrapped token failed");
        require(IERC20 (originalContractAddress).transfer(withdrawer, numTokens), "Withdrawl ERC20 tokens failed");

        emit WithdrawlVault (withdrawer, numTokens);
        return true;
    }

    function mint(address mintAddress, uint256 numTokens) internal returns (bool){
        balances[mintAddress] = balances[mintAddress] + numTokens;
        allowanceLeft[mintAddress] = numTokens;
        totalSupply_ = totalSupply_ + numTokens;
        return true;
    }

    function burn(address burnAddress, uint256 numTokens) internal returns (bool){
        balances[burnAddress] = balances[burnAddress] - numTokens;
        allowanceLeft[burnAddress] = allowanceLeft[burnAddress] - numTokens;
        totalSupply_ = totalSupply_ - numTokens;
        return true;
    }

    function transferVault(address sender, address receiver, uint256 numTokens) public onlyAccHaveAccess override returns (bool) {
        require(numTokens <= balances[sender], "Not enough balances to spend");
        require(numTokens <= allowanceLeft[sender], "Not enough allowance left to spend");
        balances[sender] = balances[sender]-numTokens;
        allowanceLeft[sender] = allowanceLeft[sender]-numTokens;
        balances[receiver] = balances[receiver]+numTokens;
        allowanceLeft[receiver] = allowanceLeft[receiver]+numTokens;
        emit TransferVault(sender, receiver, numTokens);
        return true;
    }

    function liquidityPoolDeposit (address owner, uint256 numTokens) external onlyAccHaveAccess override returns (bool){
        liquidityLock[owner] = liquidityLock[owner] + numTokens;
        transferVault(owner, address(this), numTokens);
        approveVault(address(this), liquidityPoolManagerV1, numTokens);
        return true;
    }

    function liquidityPoolWithdrawl (address owner, uint256 numTokens) external onlyAccHaveAccess override returns (bool){
        require(liquidityLock[owner] >= numTokens, "Not enough liquidity locked to withdrawl");
        liquidityLock[owner] = liquidityLock[owner] - numTokens;
        transferVault(address(this), owner, numTokens);
        deapproveVault(address(this), liquidityPoolManagerV1, numTokens);
        return true;
    }

    function approveVault(address owner, address spender, uint256 numTokens) public onlyAccHaveAccess override returns (bool) {
        require(numTokens <= balances[owner], "Not enough balances to spend");
        require(numTokens <= allowanceLeft[owner], "Not enough allowance left to spend");


        // if(msg.sender == liquidityPoolRouterV1){
        //     liquidityLock[owner] = liquidityLock[owner] + numTokens;

        // }

        allowed[owner][spender] += numTokens;
        allowanceLeft[owner] =  allowanceLeft[owner] - numTokens;
        emit ApprovalVault(owner, spender, numTokens);
        return true;
    }

    function deapproveVault(address owner, address spender, uint256 numTokens) public onlyAccHaveAccess override returns (bool) {
        require(numTokens <= balances[owner], "Not enough balances to cancel");
        require(numTokens <= allowed[owner][spender], "Not enough allowance to cancel");
        require(spender != liquidityPoolManagerV1 || spender != derivativePoolManagerV1, "Cant deapprove protocol address");

        // if(msg.sender == liquidityPoolRouterV1){
        //     require(numTokens <= liquidityLock[owner], "Not enough liquidity lock to cancel");
        //     liquidityLock[owner] = liquidityLock[owner] - numTokens;
        // }

        allowed[owner][spender] = allowed[owner][spender] - numTokens;
        allowanceLeft[owner] =  allowanceLeft[owner] + numTokens;
        emit DeapprovalVault(owner, spender, numTokens);
        return true;
    }

    function allowanceVault(address owner, address spender) public onlyAccHaveAccess override view returns (uint) {
        return allowed[owner][spender];
    }

    function transferFromVault(address _spender, address owner, address recipient, uint256 numTokens) public onlyAccHaveAccess override returns (bool) {
        require(numTokens <= balances[owner], "Not enough balances to spend");
        require(numTokens <= allowed[owner][_spender], "Not enough allowance to spend");
        balances[owner] = balances[owner] - numTokens;
        allowed[owner][_spender] = allowed[owner][_spender] - numTokens;
        balances[recipient] = balances[recipient] + numTokens;
        allowanceLeft[recipient] = allowanceLeft[recipient] + numTokens;
        emit TransferVault(owner, recipient, numTokens);
        return true;
    }
}

contract Xchange is IXchange{

    struct Token {
        address wrappedContractAddress;
        address originalContractAddress;
    }

    mapping (address => Token ) public ERC20VaultList;
    address [] public ERC20TokenList;

    ERC20Vault private vault;
    //Owner related address
    address owner;
    address backupAddress;
    //Developer related address
    address devOps;
    address extension;
    //Protocol address
    // address public orderBook;
    address migrationAddress;
    address public lendingProtocol;
    address public liquidityPoolManagerV1;
    address public derivativePoolManagerV1;

    constructor(address _migrationAddress, address _lendingProtocol, address _liquidityPoolManagerV1, address _derivativePoolManagerV1) {
        owner = msg.sender;
        // orderBook = _orderBook;
        migrationAddress = _migrationAddress;
        lendingProtocol = _lendingProtocol;
        liquidityPoolManagerV1 = _liquidityPoolManagerV1;
        derivativePoolManagerV1 = _derivativePoolManagerV1;
    }

    modifier onlyAccHaveAccess {
        require(msg.sender == owner || msg.sender == backupAddress || msg.sender == devOps || msg.sender == extension, "Only contract owner allow to access this function");
        _;
    }

    modifier onlyOwnerAccess {
        require(msg.sender == owner || msg.sender == backupAddress , "Only Contract Owner allow to access this function");
        _;
    }

    function vaultAddress (address originalContractAddress) public override view returns (address Original, address Vault){
        return (ERC20VaultList[originalContractAddress].wrappedContractAddress, ERC20VaultList[originalContractAddress].originalContractAddress);
    }

    function ERC20TokenRegistered () public override view returns (address [] memory){
        return ERC20TokenList;
    }

    function transferOwner (address _newOwner, address _newbackupAddress) external onlyOwnerAccess returns (bool){
        owner = _newOwner;
        backupAddress = _newbackupAddress;
        return true;
    }

    function broadcastProtocolAddress (address _migrationAddress, address _lendingProtocol, address _liquidityPoolManagerV1, address _derivativePoolManagerV1) internal returns (bool){
        for(uint256 i = ERC20TokenList.length - 1; i >= 0; i-- ){
            IERC20Vault(ERC20VaultList[ERC20TokenList[i]].wrappedContractAddress).setProtocolAddress (_migrationAddress, _lendingProtocol, _liquidityPoolManagerV1, _derivativePoolManagerV1);   
        }

        return true;
    }

    function changeMigrationAddress(address _newMigrationAddress) public  onlyAccHaveAccess returns (bool){
        migrationAddress = _newMigrationAddress;
        broadcastProtocolAddress(migrationAddress, lendingProtocol, liquidityPoolManagerV1, derivativePoolManagerV1);
        return true;
    }

    function changeLendingProtocol(address _newLendingProtocol) public  onlyAccHaveAccess returns (bool){
        lendingProtocol = _newLendingProtocol;
        broadcastProtocolAddress(migrationAddress, lendingProtocol, liquidityPoolManagerV1, derivativePoolManagerV1);
        return true;
    }

    function changeDerivativePoolManagerV1(address _newDerivativePoolManagerV1) public  onlyAccHaveAccess returns (bool){
        derivativePoolManagerV1 = _newDerivativePoolManagerV1;
        broadcastProtocolAddress(migrationAddress, lendingProtocol, liquidityPoolManagerV1, derivativePoolManagerV1);
        return true;
    }

    function changeLiquidityPoolManagerV1(address _newLiquidityPoolManagerV1) public  onlyAccHaveAccess returns (bool){
        liquidityPoolManagerV1 = _newLiquidityPoolManagerV1;
        broadcastProtocolAddress(migrationAddress, lendingProtocol, liquidityPoolManagerV1, derivativePoolManagerV1);
        return true;
    }

    function createVaultToken (address originalContractAddress, string memory _name, string memory _symbol, uint8 _decimals) external onlyAccHaveAccess override returns (bool) {
        vault = new ERC20Vault(originalContractAddress, migrationAddress, lendingProtocol, liquidityPoolManagerV1, derivativePoolManagerV1);
        address wrappedContractAddress = vault.setPublicVariable(_name, _symbol, _decimals);
        ERC20VaultList[originalContractAddress] = Token(wrappedContractAddress, originalContractAddress);
        ERC20TokenList.push(originalContractAddress);
        return true;
    }

    function balanceOf (address ERC20ContractAddress, address tokenOwner) external override view returns (uint256){
        return (IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).balanceOfVault(tokenOwner));
        
    }
    
    function deposit (address ERC20ContractAddress, uint256 _amount) external override returns (bool){
        IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).depositVault(msg.sender, _amount);
        return true;
    }

    function withdrawl (address ERC20ContractAddress, uint _amount) external override returns (bool){
        IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).withdrawlVault(msg.sender, _amount);
        return true;
    }

    function approve(address ERC20ContractAddress, address _spender, uint256 _amount) public override returns (uint256){
        IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).approveVault(msg.sender, _spender, _amount);
        
        return (IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).allowanceVault(msg.sender, _spender));
    }

    function deapprove(address ERC20ContractAddress, address _spender, uint256 _amount) external override returns (uint256){
        IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).deapproveVault(msg.sender, _spender, _amount);
        
        return (IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).allowanceVault(msg.sender, _spender));
    }


    function transferFrom (address ERC20ContractAddress, address sender, address recepient, uint256 _amount) external override returns (bool) {
        IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).transferFromVault(msg.sender, sender, recepient, _amount);
        return true;
        
    }
    
    function transfer(address ERC20ContractAddress, address recepient, uint256 _amount) external override returns (bool){
        IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).transferVault(msg.sender, recepient, _amount);
        return true;
    }
    
    ///////////////////////////////////////////
    /* OrderBook algoritm is expensive running in Ethereum mainnet, orderBook usecase possible to run on Ethereum L2 solution*/
    ///////////////////////////////////////////

    // function entryOrderBook(address _OriginalFromAsset, address _OriginalToAsset, int256 _OrderQty, int256 _OrderPrice, int _OrderType) external override returns (bool){
    //     if (_OrderType == 0 || _OrderType == 20){
    //         IERC20Vault (ERC20VaultList[_OriginalFromAsset].wrappedContractAddress).approveVault(msg.sender, orderBook, uint256 (_OrderQty));
    //         // IAssetsPairOrderBook (orderBook).entryOrderBook(ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, msg.sender, _OrderQty, _OrderPrice, _OrderType);
    //         // return true;
    //     }
    //     else if (_OrderType == 1 || _OrderType == 21){
    //         IERC20Vault (ERC20VaultList[_OriginalToAsset].wrappedContractAddress).approveVault(msg.sender, orderBook, uint256 (_OrderQty * _OrderPrice));
    //         // IAssetsPairOrderBook (orderBook).entryOrderBook(ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, msg.sender, _OrderQty, _OrderPrice, _OrderType);
    //         // return true;
    //     }
    //     else {
    //         return false;
    //     }
    //     IAssetsPairOrderBook (orderBook).entryOrderBook(ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, msg.sender, _OrderQty, _OrderPrice, _OrderType);
    //     return true;
        
    // }
    // function removeOrderBook(address _OriginalFromAsset, address _OriginalToAsset, int256 _OrderQty, int256 _OrderPrice) external override returns (bool){

    //     int _OrderType = IAssetsPairOrderBook(orderBook).removeOrderBook(ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, msg.sender, _OrderQty, _OrderPrice);
        
    //     if (_OrderType == 20){
    //         IERC20Vault (ERC20VaultList[_OriginalFromAsset].wrappedContractAddress).deapproveVault(msg.sender, orderBook, uint256 (_OrderQty));
    //         return true;
    //     }
    //     else if (_OrderType == 21){
    //         IERC20Vault (ERC20VaultList[_OriginalToAsset].wrappedContractAddress).deapproveVault(msg.sender, orderBook, uint256 (_OrderQty)); 
    //         return true;
    //     }
    //     else {
    //         return false;
    //     }
    // }
    // function getPrice(address _OriginalFromAsset, address _OriginalToAsset) external view override returns (uint256, uint256) {
    //     return IAssetsPairOrderBook (orderBook).getPrice(ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress);
    // }

    function entryDerivativePosition (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amount, uint256 _leverage, uint256 _orderType) external override returns (uint256) {
        return IDerivativePoolManagerV1(derivativePoolManagerV1). entryPosition(msg.sender, ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, _amount, _leverage, _orderType);
    }

    function closeDerivativePosition (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amount, uint256 _orderType) external override returns (uint256) {
        return IDerivativePoolManagerV1(derivativePoolManagerV1). closePosition(msg.sender, ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, _amount, _orderType);
    }

    function getPoolStaker(address _OriginalAsset) external view returns (ILiquidityPoolManagerV1.Data [] memory){
        return ILiquidityPoolManagerV1(liquidityPoolManagerV1).getPoolStaker(ERC20VaultList[_OriginalAsset].wrappedContractAddress, msg.sender);
    }
    
    function initializePool (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountFrom, uint256 _amountTo)external override returns (bool){
        return ILiquidityPoolManagerV1(liquidityPoolManagerV1).initializePool(msg.sender,ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, _amountFrom, _amountTo);
    }

    function depositStaking (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountStake, uint256 _timeLock) external override returns (bool){
        return ILiquidityPoolManagerV1(liquidityPoolManagerV1).depositStaking(msg.sender, ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, _amountStake, (block.timestamp + _timeLock));
    }

    function withdrawlStaking (address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountWithdrawl, uint256 _index) external override returns (bool){
        return ILiquidityPoolManagerV1(liquidityPoolManagerV1).withdrawlStaking(msg.sender, ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, _amountWithdrawl, _index);
    }

    function swapToken(address _OriginalFromAsset, address _OriginalToAsset, uint256 _amountFromTokens) external override returns (uint256){
        
        return ILiquidityPoolManagerV1(liquidityPoolManagerV1).swapToken(msg.sender,ERC20VaultList[_OriginalFromAsset].wrappedContractAddress, ERC20VaultList[_OriginalToAsset].wrappedContractAddress, _amountFromTokens);
    }


    function lending(address _OriginalCollateralAsset, address _OriginalBorrowAsset, uint256 _Value, uint256 _DueTime) external override returns (bool){
        require (IERC20Vault (ERC20VaultList[_OriginalCollateralAsset].wrappedContractAddress).approveVault(msg.sender, lendingProtocol, _Value), "Approval failed");
        
        require(ILendingProtocol (lendingProtocol).borrow(ERC20VaultList[_OriginalCollateralAsset].wrappedContractAddress, msg.sender, ERC20VaultList[_OriginalBorrowAsset].wrappedContractAddress, _Value, _DueTime));
        return true;
    }

    function addCollateralLending(address _OriginalCollateralAsset, address _OriginalBorrowAsset, uint256 _Index, uint256 _AmountAdd) external override returns (bool){
        require (IERC20Vault (ERC20VaultList[_OriginalCollateralAsset].wrappedContractAddress).approveVault(msg.sender, lendingProtocol, _AmountAdd), "Approval failed");
        
        require(ILendingProtocol (lendingProtocol).addCollateral(ERC20VaultList[_OriginalCollateralAsset].wrappedContractAddress, msg.sender, ERC20VaultList[_OriginalBorrowAsset].wrappedContractAddress, _Index, _AmountAdd));
        return true;
    }

    function decreaseCollateralLending(address _OriginalCollateralAsset, address _OriginalBorrowAsset, uint256 _Index, uint256 _AmountAdd) external override returns (bool){
        
        require(ILendingProtocol (lendingProtocol).decreaseCollateral(ERC20VaultList[_OriginalCollateralAsset].wrappedContractAddress, msg.sender, ERC20VaultList[_OriginalBorrowAsset].wrappedContractAddress, _Index, _AmountAdd));
        return true;
    }

    function LTVCheckLending(address _OriginalCollateralAsset, address _OriginalBorrowAsset, uint256 _Index, uint256 _Value) external view override returns (uint256){
        return (ILendingProtocol (lendingProtocol).LTVCheck(_OriginalCollateralAsset, msg.sender, _OriginalBorrowAsset, _Index, _Value));
    }



}
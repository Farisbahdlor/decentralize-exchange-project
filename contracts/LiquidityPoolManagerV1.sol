// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity ^0.8.0;

import "../interfaces/IXchange.sol";
import "../interfaces/IERC20Vault.sol";
import "../interfaces/ILiquidityPoolManagerV1.sol";
import "ERC20/contracts/IERC20.sol";


contract LiquidityPoolManagerV1 is ILiquidityPoolManagerV1 {

    
    //User that provide exact amount of pair tokens for liquidity pool to initialize
    //From vault address => To vault address => Pool provider => poolProviderData
    mapping(address => mapping (address => uint256)) public poolProvider;
    //User address that provide exact amount of tokens staked for liquidity pool
    mapping(address => mapping (address => Data [])) public poolStaker;

    //Specific pool balance tracker for pricing uint256 represent last address pool balance
    mapping (address => mapping (address => uint256)) public poolPairBalance;
    //Pool price define in ratio
    mapping (address => mapping (address => uint256)) public poolRatio;
    //Pool collected fee available amount
    uint256 public  poolCollectedFeesAvailable;
    //Staker collected fee available amount
    uint256 public stakerCollectedFeesAvailable;
    //Pool Fee Ratio 1 to 100
    uint8 public feeRatio;

    // IXchange public Exchange;
    address Xchange;
    address contractOwner;

    constructor (address _Xchange ){
        contractOwner = msg.sender;
        Xchange = _Xchange;
    }

    modifier onlyAccHaveAccess {
        require(msg.sender == contractOwner || msg.sender == Xchange, "Only contract owner allow to use this function");
        _;
    }

    function getPoolStaker(address _fromVault, address _provider) external override view returns (Data [] memory){
        return poolStaker[_fromVault][_provider];
    }

    function initializePool (address _provider, address _fromVault, address _toVault, uint256 _amountFrom, uint256 _amountTo)external onlyAccHaveAccess override returns (bool){
        require(poolRatio[_fromVault][_toVault] == 0 && poolRatio[_toVault][_fromVault] == 0, "Pool already initialize");
        
        uint256 _timestamp = block.timestamp;
        // uint256 _decimalsFrom = 10 ** (2 * IERC20Vault(_fromVault).getDecimalsVault());
        // uint256 _decimalsTo = 10 ** (2 * IERC20Vault(_toVault).getDecimalsVault());

        depositStaking(_provider, _fromVault, _toVault, _amountFrom, _timestamp);
        
        depositStaking(_provider, _toVault, _fromVault, _amountTo, _timestamp);

        // poolRatio[_fromVault][_toVault] = (_amountTo * _decimalsFrom) / _amountFrom;
        // poolRatio[_toVault][_fromVault] = (_amountFrom * _decimalsTo) / _amountTo;

        return true;
        
    }

    function deinitializePool () external returns (bool){
        
    }

    function commitToPool(address _provider, address _vaultAddress, uint256 _amount) internal returns (bool){
        return IERC20Vault(_vaultAddress).liquidityPoolDeposit(_provider, _amount);
    }

    function decommitToPool(address _provider, address _vaultAddress, uint256 _amount) internal returns (bool){
        return IERC20Vault(_vaultAddress).liquidityPoolWithdrawl(_provider, _amount);
    }

    function getExactToken(address _from, address _to, uint256 _amountFromTokens) public view override returns (uint256 _poolPrice){
        // uint256 _decimalsFrom = 10 ** (2 * IERC20Vault(_from).getDecimalsVault());
        return ((_amountFromTokens * 10 ** 36) / (_amountFromTokens + poolPairBalance[_to][_from]) * poolPairBalance[_from][_to]);
    }

    // Need further algoritm for process to provide new input deposit staking to LP
    function depositStaking (address _staker, address _from, address _to, uint256 _amountFromStake, uint256 _timeLock) public onlyAccHaveAccess override returns (bool){
        commitToPool(_staker, _from, _amountFromStake);
        uint256 _index = poolStaker[_from][_staker].length;
        if(_index == 0){
            _index = 0;
        }
        else {
            _index = _index - 1;
        }
        poolStaker[_from][_staker].push(Data(_amountFromStake, _index, _timeLock));
        poolPairBalance[_to][_from] = poolPairBalance[_to][_from] + _amountFromStake;

        return true;
    }

    // Need further algoritm process to provide user staking witdrawl rasio from LP
    function withdrawlStaking (address _staker, address _from, address _to, uint256 _amountFromStake, uint256 _index) external onlyAccHaveAccess override returns (bool){
        require(poolStaker[_from][_staker][_index].timeLock <= block.timestamp, "Not exceed the specified time for liquidity to withdrawl");
        require(poolPairBalance[_to][_from] >= _amountFromStake, "Not enough liquidity pool to withdrawl, please wait awhile for liquidity pool to adjust");
        decommitToPool(_staker, _from, _amountFromStake);
        deleteStakeData(_staker, _from, _index);
        poolPairBalance[_to][_from] = poolPairBalance[_to][_from] - _amountFromStake;
        return true;
    }

    function deleteStakeData (address _staker, address _vaultAddress, uint256 _index) internal returns (bool){
        if(_index == 0 || _index == poolStaker[_vaultAddress][_staker].length - 1){
            poolStaker[_vaultAddress][_staker].pop();
            return true;
        }
        else {
            for (;_index <= poolStaker[_vaultAddress][_staker].length; _index++){
                poolStaker[_vaultAddress][_staker][_index] = poolStaker[_vaultAddress][_staker][_index + 1];
            }
            poolStaker[_vaultAddress][_staker].pop();
            return true;
        }
        
    }

    function transfer(address _vault, address _from, address _to, uint256 _amountTokens) internal returns (bool){
        return IERC20Vault(_vault).transferFromVault(address(this), _from, _to, _amountTokens);
    }

    function updatePoolRatio (address _from, address _to, uint256 _decimalsFrom, uint256 _decimalsTo) internal returns (bool){
        poolRatio[_from][_to] = (poolPairBalance[_from][_to] * _decimalsFrom) / poolPairBalance[_to][_from];
        poolRatio[_to][_from] = (poolPairBalance[_to][_from] * _decimalsTo) / poolPairBalance[_from][_to];
        return true;
    }

    function swapToken(address _user, address _fromVault, address _toVault, uint256 _amountFromTokens) external onlyAccHaveAccess override returns (uint256){
        require(poolPairBalance[_toVault][_fromVault] != 0 && poolPairBalance[_fromVault][_toVault] != 0, "Not available pool to provide swap");
        IERC20Vault(_fromVault).approveVault(_user, address(this), _amountFromTokens);
        // require (IERC20Vault(_fromVault).allowanceVault(_user, address(this)) >= _amountFromTokens, "Not enough allowance balance to spend for swap tokens");
        // uint256 _decimalsFrom = 10 ** (2 * IERC20Vault(_fromVault).getDecimalsVault());
        // uint256 _decimalsTo = 10 ** (2 * IERC20Vault(_toVault).getDecimalsVault());

        // uint256 _amountToTokens = priceFeed(_fromVault, _toVault) * _amountFromTokens;
        uint256 _amountToTokens = getExactToken(_fromVault, _toVault, _amountFromTokens) / 10 ** 36;
        
        //Maximum swap amount limit to 5% of liquidity pool available
        require ((poolPairBalance[_fromVault][_toVault] / 20) >= _amountToTokens, "Please enter lower amount to provide swap");
        
        poolPairBalance[_toVault][_fromVault] = poolPairBalance[_toVault][_fromVault] + _amountFromTokens;
        transfer(_fromVault, _user, _fromVault, _amountFromTokens);
        IERC20Vault(_fromVault).approveVault(_fromVault, address(this), _amountFromTokens);
        
        poolPairBalance[_fromVault][_toVault] = poolPairBalance[_fromVault][_toVault] - _amountToTokens;
        transfer(_toVault, _toVault, _user, _amountToTokens);

        // updatePoolRatio(_fromVault, _toVault, _decimalsFrom, _decimalsTo);


        return _amountToTokens;



    }

}

// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity ^0.8.0;

import "../interfaces/IXchange.sol";
import "../interfaces/IERC20Vault.sol";
import "../interfaces/ILiquidityPoolManagerV1.sol";
import "../interfaces/IDerivativePoolManagerV1.sol";

import "hardhat/console.sol";

contract DerivativePoolManagerV1 is IDerivativePoolManagerV1 {

    struct PositionData{
        address fromVaultAddress;
        address positionVaultAddress;
        uint256 underlyingAsset;
        uint256 amountPosition;
        uint256 entryPoint;
        uint256 thresholdPoint;
    }

    // mapping (address =>)

    //User Long Position
    //token vault address => user => balance position
    // mapping(address => mapping (address => uint256)) public longBalanceOf;
    //token vault address => user => position data
    mapping(address => mapping (address => mapping(address => PositionData))) public longPosition;

    //User Short Position
    //token vault address => user => balance position
    // mapping(address => mapping (address => uint256)) public shortBalanceOf;
    //token vault address => user => position data
    mapping(address => mapping (address => mapping(address => PositionData))) public shortPosition;

    //Long pool position
    //token vault address => total long pool balance
    mapping (address => mapping (address => uint256)) public longPool;
    //Short pool position
    //token vault address => total short pool balance
    mapping (address => mapping (address => uint256)) public shortPool;
    mapping (address => mapping (address => uint256)) public underlyingPool;
    //User position record
    mapping (address => address []) userPositionList;

    address owner;
    address liquidityPoolManagerV1;

    constructor (address _liquidityPoolManagerV1){
        owner = msg.sender;
        liquidityPoolManagerV1 = _liquidityPoolManagerV1;
    }

    function entryPosition(address _user, address _from, address _to, uint256 _amount, uint256 _leverage, uint256 _orderType) external override returns (uint256){
        
        // IERC20Vault (_from).approveVault(_user, liquidityPoolManagerV1, _amount);
       
        uint256 _amountToToken = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).swapToken(_user,_from, _to, _amount);
        
        IERC20Vault (_to).approveVault(_user, address(this), _amountToToken);
        IERC20Vault (_to).transferFromVault( address(this), _user,  address(this), _amountToToken);
        
        uint256 _newEntryPrice;
        uint256 _newThreshold;
        // uint256 _decimals = 10 ** (2 * IERC20Vault(_from).getDecimalsVault());
        if(_orderType == 0){
            //Entry price in 10 ** 18
            _newEntryPrice = (_amountToToken * 10 ** 18) / _amount;
            _newThreshold = _newEntryPrice + (_newEntryPrice / _leverage);
            

            if(shortPosition[_from][_to][_user].amountPosition != 0){
                _newThreshold = ((shortPosition[_from][_to][_user].thresholdPoint * shortPosition[_from][_to][_user].amountPosition) + (_newThreshold * (_amount * _leverage))) / (shortPosition[_from][_to][_user].amountPosition + (_amount * _leverage));
                _newEntryPrice = ((shortPosition[_from][_to][_user].entryPoint * shortPosition[_from][_to][_user].amountPosition) + (_newEntryPrice * (_amount * _leverage))) / (shortPosition[_from][_to][_user].amountPosition + (_amount * _leverage));
                
            }
            else {
                userPositionList[_user].push(_to);
            }

            shortPosition[_from][_to][_user] = PositionData(_from, _to, (shortPosition[_from][_to][_user].underlyingAsset + _amountToToken), (shortPosition[_from][_to][_user].amountPosition + (_amount * _leverage)), _newEntryPrice, _newThreshold);
            // shortBalanceOf[_from][_user] = shortBalanceOf[_from][_user] + (_amount * _leverage);
            shortPool[_from][_to] = shortPool[_from][_to] + (_amount * _leverage);
            underlyingPool[_from][_to] = underlyingPool[_from][_to] + _amountToToken;
            
        }
        else if(_orderType == 1) {
            //Entry price in 10 ** 18
            _newEntryPrice = (_amount * 10 ** 18) / _amountToToken;
            _newThreshold = _newEntryPrice - (_newEntryPrice / _leverage);
                
            if(longPosition[_to][_from][_user].amountPosition != 0){
                _newThreshold = ((longPosition[_to][_from][_user].thresholdPoint * longPosition[_to][_from][_user].amountPosition) + (_newThreshold * (_amount * _leverage))) / (longPosition[_to][_from][_user].amountPosition + (_amount * _leverage));
                _newEntryPrice = ((longPosition[_to][_from][_user].entryPoint * longPosition[_to][_from][_user].amountPosition) + (_newEntryPrice * (_amount * _leverage))) / (longPosition[_to][_from][_user].amountPosition + (_amount * _leverage));
                
            }
            else {
                userPositionList[_user].push(_to);
            }
            
            longPosition[_to][_from][_user] = PositionData(_from, _to, (longPosition[_to][_from][_user].underlyingAsset + _amountToToken), (longPosition[_to][_from][_user].amountPosition + (_amountToToken * _leverage)), _newEntryPrice, _newThreshold);
            // longBalanceOf[_to][_user] = longBalanceOf[_to][_user] + (_amountToToken * _leverage);
            longPool[_to][_from] = longPool[_to][_from] + (_amountToToken * _leverage);
            underlyingPool[_from][_to] = underlyingPool[_from][_to] + _amountToToken;
        }
        else {
            require(1==2, "Order type didnt match");
            return 0;
        }

        return _newThreshold;
    }

    function pnlCalculator(uint256 _targetPoolPosition, uint256 _oppositePoolPosition, uint256 _targetPoolUnderlying, uint256 _oppositePoolUnderlying, uint256 _userPnLPosition, uint256 _userTargetPositon, uint256 _userTargetUnderlying, uint256 _price)internal pure returns (uint256 profit){
        // 
        // uint256 _poolRatio = _oppositePoolPosition / _targetPoolPosition;
        // uint256 _underlyingRatio = _oppositePoolUnderlying / (_targetPoolUnderlying * _price);
        // uint256 _userPoolRatio = (_userTargetUnderlying / _userTargetPositon) / (_targetPoolUnderlying / _targetPoolPosition);
        // uint256 _userProfitPollRatio = _userPnLPosition / _targetPoolPosition;
        console.log("_oppositePoolPosition / _targetPoolPosition : ", _oppositePoolPosition * 10 ** 18 / _targetPoolPosition);
        console.log("_oppositePoolUnderlying / (_targetPoolUnderlying * _price) : ", _oppositePoolUnderlying * 10 ** 36 / (_targetPoolUnderlying * _price));
        console.log("(_userTargetUnderlying / _userTargetPositon) / (_targetPoolUnderlying / _targetPoolPosition) : ", (_userTargetUnderlying * 10 ** 36 / _userTargetPositon) / (_targetPoolUnderlying * 10 ** 18 / _targetPoolPosition));
        console.log("_userPnLPosition / _targetPoolPosition : ", _userPnLPosition  * 10 ** 18 / _targetPoolPosition);
        // ???? MASIH EROR REVERT BUKAN SALAH VALUE DI PERKALIAN PNL KALKULATORNYA???
        // console.log("PnL Calculator : ", (((_oppositePoolUnderlying * 10 ** 36) / (_targetPoolUnderlying * _price)) * (_oppositePoolPosition * 10 ** 18 / _targetPoolPosition) * ((_userTargetUnderlying * 10 ** 36 / _userTargetPositon) / (_targetPoolUnderlying * 10 ** 18 / _targetPoolPosition)) / 10 ** 18 * (_userPnLPosition  * 10 ** 18 / _targetPoolPosition) * _oppositePoolUnderlying / 10 ** 72));
        return (((_oppositePoolUnderlying * 10 ** 36) / (_targetPoolUnderlying * _price)) * (_oppositePoolPosition * 10 ** 18 / _targetPoolPosition) * ((_userTargetUnderlying * 10 ** 36 / _userTargetPositon) / (_targetPoolUnderlying * 10 ** 18 / _targetPoolPosition)) / 10 ** 18 * (_userPnLPosition  * 10 ** 18 / _targetPoolPosition) * _oppositePoolUnderlying / 10 ** 54);
    }

    function shortClosePositionDataProcess (address _user,address _from, address _to, uint256 _amountPosition, uint256 _underlyingClose) internal returns (bool){
        // shortBalanceOf[_from][_user] = shortBalanceOf[_from][_user] - _amountPosition;
        shortPosition[_from][_to][_user].amountPosition = shortPosition[_from][_to][_user].amountPosition - _amountPosition;
        shortPosition[_from][_to][_user].underlyingAsset = shortPosition[_from][_to][_user].underlyingAsset - _underlyingClose;
        shortPool[_from][_to] = shortPool[_from][_to] - _amountPosition;
        if(shortPosition[_from][_to][_user].amountPosition == 0){
            shortPosition[_from][_to][_user].entryPoint = 0;
            shortPosition[_from][_to][_user].thresholdPoint = 0;
        }
        // underlyingPool[_from][_to] = underlyingPool[_from][_to] - _underlyingClose;
        return true;
    }

    function longClosePositionDataProcess (address _user,address _from, address _to, uint256 _amountPosition, uint256 _underlyingClose) internal returns (bool){
        // longBalanceOf[_from][_user] = longBalanceOf[_from][_user] - _amountPosition;
        longPosition[_from][_to][_user].amountPosition = longPosition[_from][_to][_user].amountPosition - _amountPosition;
        longPosition[_from][_to][_user].underlyingAsset = longPosition[_from][_to][_user].underlyingAsset - _underlyingClose;
        longPool[_from][_to] = longPool[_from][_to] - _amountPosition;
        if(longPosition[_from][_to][_user].amountPosition == 0){
            longPosition[_from][_to][_user].entryPoint = 0;
            longPosition[_from][_to][_user].thresholdPoint = 0;
        }
        // underlyingPool[_to][_from] = underlyingPool[_to][_from] - _underlyingClose;
        return true;
    }

    function closePosition(address _user,address _from, address _to, uint256 _amountPosition, uint256 _orderType) external override returns (uint256){
        
         
        if(_orderType == 0){
            PositionData memory _userData = shortPosition[_from][_to][_user];
            // console.log();
            require(_userData.amountPosition >= _amountPosition, "Cannot close short position more than user short position open");
            
            uint256 _underlyingClose = _amountPosition / _userData.amountPosition * _userData.underlyingAsset; 
            console.log(_underlyingClose);
            uint256 _currentPrice = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).getExactToken(_to, _from, _underlyingClose);
            _currentPrice = (_underlyingClose * 10 ** 36) / (_currentPrice / 10 ** 18);
            // console.log("_fromTokenAmount : ",_currentPrice);
            console.log("(_underlyingClose * 10 ** 36) / (_fromTokenAmount / 10 ** 18) : ",_currentPrice);
            console.log("user threshold : ", _userData.thresholdPoint);
            console.log(_userData.thresholdPoint);
            console.log("underlying pool : ",underlyingPool[_from][_to]);
            console.log("user underlying close : ",_underlyingClose);
            console.log("underlyingPool[_to][_from] : ", underlyingPool[_to][_from]);
            // require (_fromTokenAmount  / _underlyingClose / 10 ** 18 <= _userData.thresholdPoint, "Price exceed user threshold position, only can sell position BELOW threshold point");
            require (_currentPrice <= _userData.thresholdPoint, "Price exceed user threshold position, only can sell position BELOW threshold point");
            
            require(underlyingPool[_from][_to] >= _underlyingClose, "Not enough liquidity for Short Position to close");
            
            if(underlyingPool[_to][_from] == 0){
                // _underlyingClose = _underlyingClose / _userData.underlyingAsset * underlyingPool[_from][_to];
                uint256 _amountFromToken = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).swapToken(address(this),_to, _from, _underlyingClose);
                
                shortClosePositionDataProcess(_user, _from, _to, _amountPosition, _underlyingClose);
                underlyingPool[_from][_to] = underlyingPool[_from][_to] - _underlyingClose;
                
                IERC20Vault (_from).transferVault(address(this), _user, (_amountFromToken));

                return (_amountFromToken);
            }

            uint256 _userPnLPosition;
            if(int256(_currentPrice) - int256(_userData.entryPoint) < 0){
                _userPnLPosition = (_amountPosition) * (_userData.entryPoint - _currentPrice) / (_userData.thresholdPoint - _userData.entryPoint);
            }
            else {
                _userPnLPosition = (_amountPosition) * (_currentPrice - _userData.entryPoint) / (_userData.thresholdPoint - _userData.entryPoint);
            }
            
            console.log("_userPnLPosition : ",_userPnLPosition);
            uint256 _PnL_in_LongUnderlying = pnlCalculator(shortPool[_from][_to],
                                             longPool[_from][_to],
                                             underlyingPool[_from][_to],
                                             underlyingPool[_to][_from],
                                             _userPnLPosition,
                                             _userData.amountPosition,
                                             _userData.underlyingAsset,
                                             _currentPrice);
            

            console.log("_PnL_in_LongUnderlying : ",_PnL_in_LongUnderlying);
            console.log("underlyingPool[_to][_from] : ",underlyingPool[_to][_from]);
            
            require(underlyingPool[_to][_from] >= _PnL_in_LongUnderlying, "Not enough liquidity for Short Position to close");


            if(int256(_currentPrice) - int256(_userData.entryPoint) < 0){
                
                console.log ("if profit _underlyingClose : ", _underlyingClose);
                uint256 _amountFromToken = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).swapToken(address(this),_to, _from, _underlyingClose);
                console.log ("if profit _amountFromToken : ", _amountFromToken);
                shortClosePositionDataProcess(_user, _from, _to, _amountPosition, _underlyingClose);
                underlyingPool[_from][_to] = underlyingPool[_from][_to] - _underlyingClose;
                
                underlyingPool[_to][_from] = underlyingPool[_to][_from] - _PnL_in_LongUnderlying;

                console.log("if profit total return in long underlying : ", (_amountFromToken + _PnL_in_LongUnderlying));
                IERC20Vault (_from).transferVault(address(this), _user, (_amountFromToken + _PnL_in_LongUnderlying));

                return (_amountFromToken + _PnL_in_LongUnderlying);

            }
            else{
                shortClosePositionDataProcess(_user, _from, _to, _amountPosition, _underlyingClose);
              
                _underlyingClose = (_underlyingClose) - (((_PnL_in_LongUnderlying * 10 ** 36) * (_currentPrice)) / 10 ** 18);
                underlyingPool[_from][_to] = underlyingPool[_from][_to] - _underlyingClose;
                console.log ("else loss/equal _underlyingClose : ", _underlyingClose);
                uint256 _amountFromToken = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).swapToken(address(this),_to, _from, _underlyingClose);
                console.log ("else loss/equal _amountFromToken : ", _amountFromToken);
              
                IERC20Vault (_from).transferVault(address(this), _user, _amountFromToken);

                return _amountFromToken;
            }
        }
        else if(_orderType == 1) {
            PositionData memory _userData = longPosition[_from][_to][_user];
            require(_userData.amountPosition >= _amountPosition, "Cannot close long position more than user long position open");
            
            uint256 _underlyingClose = _amountPosition / _userData.amountPosition * _userData.underlyingAsset;
            uint256 _currentPrice = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).getExactToken(_from, _to, _underlyingClose);
            _currentPrice = (_currentPrice  / _underlyingClose / 10 ** 18);
            console.log("_toTokenAmount : ",_currentPrice);
            console.log("(_toTokenAmount  / _underlyingClose / 10 ** 18) : ",_currentPrice);
            console.log("user threshold : ", _userData.thresholdPoint);
            console.log(_userData.thresholdPoint);
            console.log("underlyingPool[_to][_from] : ",underlyingPool[_to][_from]);
            console.log("underlyingPool[_from][_to] : ",underlyingPool[_from][_to]);
            console.log("_underlyingClose : ",_underlyingClose);
            
            require (_currentPrice >= _userData.thresholdPoint, "Price exceed user threshold position, only can sell position ABOVE threshold point");
            require(underlyingPool[_to][_from] >= _underlyingClose, "Not enough liquidity for Long Position to close");

            if(underlyingPool[_from][_to] == 0){
                // _underlyingClose = _underlyingClose / _userData.underlyingAsset * underlyingPool[_to][_from];

                uint256 _amountToToken = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).swapToken(address(this),_from, _to, _underlyingClose);

                longClosePositionDataProcess(_user, _from, _to, _amountPosition, _underlyingClose);
                underlyingPool[_to][_from] = underlyingPool[_to][_from] - _underlyingClose;
                
                IERC20Vault (_to).transferVault(address(this), _user, (_amountToToken));

                return (_amountToToken);
            }

            uint256 _userPnLPosition;
            if(int256(_currentPrice) - int256(_userData.entryPoint) > 0){
                _userPnLPosition = (_amountPosition) * (_currentPrice - _userData.entryPoint) / (_userData.entryPoint - _userData.thresholdPoint);
            }
            else {
                _userPnLPosition = (_amountPosition) * (_userData.entryPoint - _currentPrice) / (_userData.entryPoint - _userData.thresholdPoint);
            }
            
            console.log("_userPnLPosition : ",_userPnLPosition);
            uint256 _PnL_in_ShortUnderlying = pnlCalculator(longPool[_from][_to],
                                             shortPool[_from][_to],
                                             underlyingPool[_to][_from],
                                             underlyingPool[_from][_to],
                                             _userPnLPosition,
                                             _userData.amountPosition,
                                             _userData.underlyingAsset,
                                             _currentPrice);
            
            console.log("_PnL_in_ShortUnderlying : ",_PnL_in_ShortUnderlying);
            console.log("underlyingPool[_to][_from] : ",underlyingPool[_to][_from]);
            
            require(underlyingPool[_from][_to] >= _PnL_in_ShortUnderlying, "Not enough liquidity for Short Position to close");

            

            if(int256(_currentPrice) - int256(_userData.entryPoint) > 0){
                console.log ("if profit _underlyingClose : ", _underlyingClose);
                uint256 _amountToToken = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).swapToken(address(this),_from, _to, _underlyingClose);
                console.log ("if profit _amountToToken : ", _amountToToken);
                longClosePositionDataProcess(_user, _from, _to, _amountPosition, _underlyingClose);
                underlyingPool[_to][_from] = underlyingPool[_to][_from] - _underlyingClose;

                underlyingPool[_from][_to] = underlyingPool[_from][_to] - _PnL_in_ShortUnderlying;
                console.log("if profit total return in short underlying : ", (_amountToToken + _PnL_in_ShortUnderlying));
                
                IERC20Vault (_to).transferVault(address(this), _user, (_amountToToken + _PnL_in_ShortUnderlying));

                return (_amountToToken + _PnL_in_ShortUnderlying);
            }
            else{
                longClosePositionDataProcess(_user, _from, _to, _amountPosition, _underlyingClose);
                _underlyingClose = (_underlyingClose) - (((_PnL_in_ShortUnderlying * 10 ** 36)  / _currentPrice) / 10 ** 18);
                underlyingPool[_to][_from] = underlyingPool[_to][_from] - _underlyingClose;
                console.log ("else loss/equal _underlyingClose : ", _underlyingClose);
                uint256 _amountToToken = ILiquidityPoolManagerV1 (liquidityPoolManagerV1).swapToken(address(this),_from, _to, _underlyingClose);
                console.log ("else loss/equal _amountToToken : ", _amountToToken);
                

                IERC20Vault (_to).transferVault(address(this), _user, _amountToToken);

                return _amountToToken;
            }
        }
        else {
            require(1==2, "Order type didnt match");
            return 0;
        }
    }
}
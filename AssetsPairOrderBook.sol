// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IAssetsPairOrderBook {

    // function fillOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice, int OrderType) external returns (bool);
    function entryOrderBook(address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) external returns (bool);
    function removeOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice) external returns (bool);
    function getPrice (address _FromAsset, address _ToAsset) external view returns (uint256, uint256);

    event Settlement (address _FromAsset, address _ToAsset, address _TraderAddress, address _TakerAddress, uint256 _OrderQty, uint256 _ValueSettlement, uint256 _Price);
    // event Transaction
    
}

interface IERC20Vault {
    function transfer(address _TraderAddressMaker, address _TraderAddressTaker, uint256 _ValueSettlement) external returns (bool) ;
}



contract AssetsPairOrderBook is IAssetsPairOrderBook {

    
    struct TransactionRecord {
        address OrderAddr;
        string FromAsset;
        string ToAsset;
        uint256 OrderQty;
        uint256 OrderPrice;
        uint256 Timestamp;
    }
    
    struct BlockOrder {
        address TraderAddress;
        int256 TotalValue;
        // int OrderType;
        
    }
    struct OrderPriceData {
        //Price should be to ToAsset value
        // int256 MarkPrice;
        int256 StartOrderBookBidPrice;
        int256 StartOrderBookAskPrice;
    }
    struct OrderStackData{
        address FromAsset;
        address ToAsset;
        address TraderAddress;
        int256 OrderQty;
        int256 OrderPrice;
        int OrderType;
    }

    //From Asset => To Asset => PriceData
    mapping (address => mapping (address => OrderPriceData)) public AssetPrice;
    //Order Book Listed
    //From Asset => To Asset => Pointer to Bid/Ask Price Order Book Asset => Block Order from Trader for certain price of asset.
    mapping (address => mapping (address => mapping (int256 => BlockOrder []))) public OrderBook;
    //StackOrderList... to prevent double entry or front running Entry order
    mapping(address => mapping(address => OrderStackData [])) public StackOrderList;
    
    //Order entry must be stacked in StackOrderList, and will be execute in order from the begining.
    //
    function entryOrderBook(address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) external override returns (bool){
        require(msg.sender == _FromAsset, "Only Vault have permission to fill order book");
        StackOrderList[_FromAsset][_ToAsset].push(OrderStackData(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, _OrderPrice, _OrderType));
        require(fillOrderBook(StackOrderList[_FromAsset][_ToAsset][0].FromAsset, 
        StackOrderList[_FromAsset][_ToAsset][0].ToAsset,
        StackOrderList[_FromAsset][_ToAsset][0].TraderAddress, 
        StackOrderList[_FromAsset][_ToAsset][0].OrderQty, 
        StackOrderList[_FromAsset][_ToAsset][0].OrderPrice,
        StackOrderList[_FromAsset][_ToAsset][0].OrderType), "Failed to execute stack order list");
        deleteStackOrderBook(_FromAsset, _ToAsset, 0);
        return true;
    }

    function deleteStackOrderBook(address _FromAsset, address _ToAsset, uint256 i) internal returns (bool){
        uint256 LenMin1 = StackOrderList[_FromAsset][_ToAsset].length-1;
        if(LenMin1 == 0 || i == LenMin1 +1){
            StackOrderList[_FromAsset][_ToAsset].pop();
            return true;
        }
        else {
            for(; i < LenMin1; i++){
                StackOrderList[_FromAsset][_ToAsset][i] = StackOrderList[_FromAsset][_ToAsset][i+1];
            }
            StackOrderList[_FromAsset][_ToAsset].pop();
            return true;
        }
    }

    function fillOrderBook (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) internal  returns (bool){
        //Ordertype 0 for sell, Ordertype 1 for buy, Ordertype 20 (SELL) & 21 (BUY) for Limit order
        if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice == 0 ||
        AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice == 0 ||
        _OrderType == 20 || _OrderType == 21){

            require(fillOrderbook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, _OrderPrice, _OrderType), "Order placement failed");
            return true;
        }
        else if (_OrderType == 0){
            if(_OrderPrice <= AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice){
                //Instant Sell
                require(processOrderBook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice, _OrderType), "Order placement failed");
                return true;
            }
        }
        else if(_OrderType == 1){
            if(_OrderPrice >= AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice){
                //Instant Buy
                require(processOrderBook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice, _OrderType), "Order placement failed");
                return true;
            }
        }
        else {
            return false;
        }
        
    }

    function processOrderBook (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) private returns (bool success){
        uint256 i;
        int256 _Value;
        int256 _OrderMustFiLL = _OrderQty * _OrderPrice;
        uint256 _ValueSettlement;
        uint256 _OrderQtySettlement;
        for(; _OrderMustFiLL > 0;){

            for(i = 0; OrderBook[_FromAsset][_ToAsset][_OrderPrice].length != 0; ){
                _Value = OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TotalValue;

                //if order already fullfill, no need to fill next orderbook list
                if(_OrderMustFiLL - _Value <= 0){
                    OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TotalValue -= _OrderMustFiLL;
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress;
                    require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), uint256 (_OrderMustFiLL)), "Order failed to execute");
                    _OrderMustFiLL = 0;
                    
                    emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), uint256 (_Value), uint256 (_OrderPrice) );
                    
                    break;
                    
                }
                //partial order fullfill, go to next orderbook list
                else {
                    _OrderMustFiLL -= _Value;
                    _OrderQtySettlement = uint256 (_Value / _OrderPrice);
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress;
                    require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, _OrderQtySettlement, uint256 (_Value)), "Order failed to execute");
                    deleteOrderbook(_FromAsset, _ToAsset, _OrderPrice, i);
                    emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, _OrderQtySettlement, _ValueSettlement, uint256 (_OrderPrice) );
                    if(OrderBook[_FromAsset][_ToAsset][_OrderPrice].length == 0){
                        
                        break;
                    }
                } 
            }

            if (_OrderType == 0){
                AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice = _OrderPrice;
                _OrderPrice --;
                _OrderMustFiLL = (_OrderMustFiLL / (_OrderPrice -1)) * _OrderPrice;
            }
            else if (_OrderType == 1){
                AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice = _OrderPrice;
                _OrderPrice ++;
            }
        }
        return true;
    }

    function deleteOrderbook (address _FromAsset, address _ToAsset, int256 _Price, uint256 i) private returns (bool){
        uint256 LenMin1 = OrderBook[_FromAsset][_ToAsset][_Price].length-1;
        if(LenMin1 == 0 || i == LenMin1 +1){
            OrderBook[_FromAsset][_ToAsset][_Price].pop();
            return true;
        }
        else {
            for(; i < LenMin1; i++){
                OrderBook[_FromAsset][_ToAsset][_Price][i] = OrderBook[_FromAsset][_ToAsset][_Price][i+1];
            }
            OrderBook[_FromAsset][_ToAsset][_Price].pop();
            return true;
        }
    }
        

    function fillOrderbook (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) private returns (bool){
        //convert order qty _FromAsset to _ToAsset value
        _OrderQty = _OrderQty * _OrderPrice;
        //insert order to orderbook list
        OrderBook[_FromAsset][_ToAsset][_OrderPrice].push(BlockOrder(_TraderAddress, _OrderQty));

        
        if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice == 0){
            AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice = _OrderPrice;
            return true;
        }
        else if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice == 0){
            AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice = _OrderPrice;
            return true;
        }
        else if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice < _OrderPrice && AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice > _OrderPrice){
            if (_OrderType == 20){
                AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice = _OrderPrice;
                return true;
            }
            else if (_OrderType == 21){
                AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice = _OrderPrice;
                return true;
            }
        }
        
        return true;
    }

    function removeOrderBook (address _FromAsset, address _ToAsset, address _OrderAddr, int256 _OrderQty, int256 _OrderPrice) external override returns (bool){
        uint256 i = 0;
        require(OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress != address(0), "Invalid Orderbook list to remove");
        //search orderbook list matched with trader address request
        while (OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress != address(0)){
            i++;
        }
        
        require(OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress == _OrderAddr, "Invalid Orderbook list to remove");
        //convert order qty _FromAsset to _ToAsset value
        _OrderQty = _OrderQty * _OrderPrice;
        require(_OrderQty <=  OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TotalValue, "Cant remove orderbook bigger then value listed");

        //Remove orderbook block if _OrderQty same value as TotalValue listed 
        if(_OrderQty == OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TotalValue){
            delete OrderBook[_FromAsset][_ToAsset][_OrderPrice][i];
            return true;

        }
        //Remove partial orderbook
        else {
            OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TotalValue -= _OrderQty;
            return true;
        }


    }

    function orderSettlement (address _FromAsset, address _ToAsset, address _TraderAddressMaker, address _TraderAddressTaker, uint256 _OrderQty, uint256 _ValueSettlement) private returns (bool){
        //Send _FromAsset from maker to taker 
        // require (IERC20Vault (_FromAsset).transfer(_TraderAddressMaker,_TraderAddressTaker, _OrderQty), "Order failed to settlement");
        //Send _ToAsset from taker to maker 
        // require (IERC20Vault (_ToAsset).transfer(_TraderAddressTaker,_TraderAddressMaker, _ValueSettlement), "Order failed to settlement");
        //emit settlement
        return true;
    }

    function getPrice (address _FromAsset, address _ToAsset) external override view returns (uint256, uint256) {
       return (uint256 (AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice), uint256 (AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice)) ;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IAssetsPairOrderBook {

    function fillOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice) external returns (bool);
    function removeOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice) external returns (bool);
    
    event Settlement (address _FromAsset, address _ToAsset, address _TraderAddress, address _TakerAddress, uint256 _OrderQty, uint256 _ValueSettlement, uint256 _Price);
    // event Transaction
}

interface IERC20 {
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
        
    }
    struct OrderPriceData {
        //Price should be to ToAsset value
        int256 StartOrderBookBidPrice;
        int256 StartOrderBookAskPrice;
    }

    //From Asset => To Asset => PriceData
    mapping (address => mapping (address => OrderPriceData)) public AssetPrice;
    //Order Book Listed
    //From Asset => To Asset => Pointer to Bid/Ask Price Order Book Asset => Block Order from Trader for certain price of asset.
    mapping (address => mapping (address => mapping (int256 => BlockOrder []))) public OrderBook;

    function fillOrderBook (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice) external override returns (bool){
        require(msg.sender == _FromAsset, "Only Vault have permission to fill order book");
        
        //if order price have same price as mark Bid/Ask price, then initiate to instant Buy/Sell
        if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice == _OrderPrice || 
        AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice == _OrderPrice){
            //Instant Buy
            if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice < _OrderPrice){
                require(fullfillBuyOrder(_FromAsset, _ToAsset, _TraderAddress, _OrderQty), "Order placement failed");
                return true;
            }
            //Instant Sell 
            else{
                require(fullfillSellOrder(_FromAsset, _ToAsset, _TraderAddress, _OrderQty), "Order placement failed");
                return true;
            }

        }
        else{
            require(fillOrderbook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, _OrderPrice), "Order palcement failed");
            return true;
        }
    }

    function fullfillBuyOrder (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty) private returns (bool success){
        uint256 i;
        int256 _BidPrice = AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice;
        //Order qty convert to ToAsset Value that must be fill
        int256 _OrderMustFiLL = _OrderQty * _BidPrice;
        int256 _Value;
        uint256 _ValueSettlement;
        uint256 _OrderQtySettlement;
        while(_OrderMustFiLL > 0){
            i = 0;
            while(OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TotalValue != 0){
                
                _Value = OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TotalValue;

                //if order already fullfill, no need to fill next orderbook list
                if(_OrderMustFiLL - _Value <= 0){
                    _ValueSettlement = uint256 (_Value - _OrderMustFiLL);
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TraderAddress;
                    require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement), "Order failed to execute");
                    //Delete certain block orderbook
                    if(_OrderMustFiLL - _Value == 0){
                        delete OrderBook[_FromAsset][_ToAsset][_BidPrice][i];
                        emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement, uint256 (_BidPrice) );
                        
                        return true;
                    }
                    //Partial block orderbook fullfill
                    else {
                        OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TotalValue -= _OrderMustFiLL;
                        emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement, uint256 (_BidPrice) );
                        return true;
                    }
                    
                }
                //partial order fullfill, go to next orderbook list
                else {
                    _ValueSettlement = uint256 (_OrderMustFiLL - _Value);
                    _OrderMustFiLL -= _Value;
                    _OrderQtySettlement = _ValueSettlement / uint256 (_BidPrice);
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TraderAddress;
                    require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, _OrderQtySettlement, _ValueSettlement), "Order failed to execute");
                    delete OrderBook[_FromAsset][_ToAsset][_BidPrice][i];
                    emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, _OrderQtySettlement, _ValueSettlement, uint256 (_BidPrice) );
                    i ++;
                } 
            }
            _BidPrice ++; 
        }
        AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice = _BidPrice;
    }

    function fullfillSellOrder (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty) private returns (bool success){
        uint256 i;
        int256 _AskPrice = AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice;
        //Order qty convert to ToAsset Value that must be fill
        int256 _OrderMustFiLL = _OrderQty * _AskPrice;
        int256 _Value;
        uint256 _ValueSettlement;
        uint256 _OrderQtySettlement;
        while(_OrderMustFiLL > 0){
            i = 0;
            while(OrderBook[_FromAsset][_ToAsset][_AskPrice][i].TotalValue != 0){
                
                _Value = OrderBook[_FromAsset][_ToAsset][_AskPrice][i].TotalValue;

                //if order already fullfill, no need to fill next orderbook list
                if(_OrderMustFiLL - _Value <= 0){
                    _ValueSettlement = uint256 (_Value - _OrderMustFiLL);
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_AskPrice][i].TraderAddress;
                    require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement), "Order failed to execute");
                    //Delete certain block orderbook
                    if(_OrderMustFiLL - _Value == 0){
                        delete OrderBook[_FromAsset][_ToAsset][_AskPrice][i];
                        emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement, uint256 (_AskPrice) );
                        
                        return true;
                    }
                    //Partial block orderbook fullfill
                    else {
                        OrderBook[_FromAsset][_ToAsset][_AskPrice][i].TotalValue -= _OrderMustFiLL;
                        emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement, uint256 (_AskPrice) );
                        return true;
                    }
                    
                }
                //partial order fullfill, go to next orderbook list
                else {
                    _ValueSettlement = uint256 (_OrderMustFiLL - _Value);
                    _OrderMustFiLL -= _Value;
                    _OrderQtySettlement = _ValueSettlement / uint256 (_AskPrice);
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_AskPrice][i].TraderAddress;
                    require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, _OrderQtySettlement, _ValueSettlement), "Order failed to execute");
                    delete OrderBook[_FromAsset][_ToAsset][_AskPrice][i];
                    emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, _OrderQtySettlement, _ValueSettlement, uint256 (_AskPrice) );
                    i ++;
                } 
            }
            _AskPrice --;
            
        }

        AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice = _AskPrice;
    }

    function fillOrderbook (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice) private returns (bool){
        //convert order qty _FromAsset to _ToAsset value
        _OrderQty = _OrderQty * _OrderPrice;
        //insert order to orderbook list
        OrderBook[_FromAsset][_ToAsset][_OrderPrice].push(BlockOrder(_TraderAddress, _OrderQty));
        if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice == 0 ){
            AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice = _OrderPrice;
        }
        else if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice == 0 && AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice > AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice){
            AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice = _OrderPrice;
        }
        return true;
    }

    function removeOrderBook (address _FromAsset, address _ToAsset, address _OrderAddr, int256 _OrderQty, int256 _OrderPrice) external override returns (bool){
        uint256 i = 0;
        require(OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress != address(0), "Invalid Orderbook list to remove");
        //search orderbook list matched with trader address request
        while (OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress != _OrderAddr){
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
        require (IERC20 (_FromAsset).transfer(_TraderAddressMaker,_TraderAddressTaker, _OrderQty), "Order failed to settlement");
        //Send _ToAsset from taker to maker 
        require (IERC20 (_ToAsset).transfer(_TraderAddressTaker,_TraderAddressMaker, _ValueSettlement), "Order failed to settlement");
        //emit settlement
        return true;
    }

}

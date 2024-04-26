// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IAssetsPairOrderBook {

    function fillOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice) external returns (bool);
    function removeOrderBook (address FromAsset, address ToAsset, address OrderAddr, uint256 OrderQty, uint256 OrderPrice) external returns (bool);
    
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
    mapping (address => mapping (address => OrderPriceData)) private AssetPrice;
    //Order Book Listed
    //From Asset => To Asset => Pointer to Bid/Ask Price Order Book Asset => Block Order from Trader for certain price of asset.
    mapping (address => mapping (address => mapping (int256 => BlockOrder []))) private OrderBook;

    function fillOrderBook (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice) external override returns (bool){
        require(msg.sender == _FromAsset, "Only Vault have permission to fill order book");
        if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice == _OrderPrice || 
        AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice == _OrderPrice){
            //Instant Buy
            if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice < _OrderPrice){
                require(fullfillOrder(_FromAsset, _ToAsset, _TraderAddress, _OrderQty), "Order placement failed");
            }
            //Instant Sell 
            else{

            }

        }

        return true;


    }

    function fullfillOrder (address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty) private returns (bool success){
        uint256 i;
        int256 _BidPrice = AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice;
        //Order qty convert to ToAsset Value that must be fill
        int256 _OrderMustFiLL = _OrderQty * _BidPrice;
        int256 _Value;
        while(_OrderQty != 0){
            i = 0;
            while(OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TotalValue != 0){
                
                _Value = OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TotalValue;

                //if order already fullfill, no need to fill next orderbook list
                if(_OrderMustFiLL - _Value <= 0){
                    uint256 _ValueSettlement = uint256 (_Value - _OrderMustFiLL);
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_BidPrice][i].TraderAddress;
                    require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement), "Order failed to execute");
                    emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), _ValueSettlement, uint256 (_BidPrice) );
                    return true;
                }
                
            }
            
        }
    }

    function removeOrderBook (address FromAsset, address ToAsset, address OrderAddr, uint256 OrderQty, uint256 OrderPrice) external override returns (bool){

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
// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity ^0.8.0;

import "../interfaces/IAssetsPairOrderBook.sol";
import "../interfaces/IERC20Vault.sol";


contract AssetsPairOrderBook is IAssetsPairOrderBook  {

    
    
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
        int OrderType;
        // int OrderType;
        
    }
    struct OrderPriceData {
        //Price should be to ToAsset value
        // int256 MarkPrice;
        int256 StartOrderBookBidPrice;
        int256 StartOrderBookAskPrice;
    }

    struct CollectionData{
        address FromAsset;
        address ToAsset;
        int256 Price;
        int256 TotalValue;
        int OrderType;
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
    //Trader Active Order Collection
    mapping (address => CollectionData[]) public ActiveOrderCollection;
    //StackOrderList... to prevent double entry or front running Entry order
    mapping(address => mapping(address => OrderStackData [])) public StackOrderList;
    
    constructor (){
        contractOwner = msg.sender;
    }

    address contractOwner;
    address Xchange;

    modifier onlyAccHaveAccess {
        require(msg.sender == contractOwner || msg.sender == Xchange , "Only contract owner allow to use this function");
        _;
    }

    function transferOwner(address _NewOwner) external onlyAccHaveAccess override returns (bool){
        contractOwner = _NewOwner;
        return true;
    }

    function setXchange(address _Xchange) external onlyAccHaveAccess override returns (bool){
        Xchange = _Xchange;
        return true;
    }

    //Order entry must be stacked in StackOrderList, and will be execute in order from the begining.
    //
    function entryOrderBook(address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) external onlyAccHaveAccess override returns (bool){
        
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
        if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice == 0 &&
        AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice == 0){

            require(fillOrderbook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, _OrderPrice, _OrderType), "Order placement failed");
            return true;
        }
        else if(_OrderType == 20){
            require (_OrderPrice > AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice, "Placement failed, limit order sell price should");
            require(fillOrderbook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, _OrderPrice, _OrderType), "Order placement failed");
            return true;
        }
        else if (_OrderType == 21){
            require (_OrderPrice < AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice, "Placement failed, limit order buy price should");
            require(fillOrderbook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, _OrderPrice, _OrderType), "Order placement failed");
            return true;
        }
        else if (_OrderType == 0){
            //Instant Sell
            require(_OrderPrice <= AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice, "Placement failed, instant order sell price should");
            require(processOrderBook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice, _OrderType), "Order placement failed");
            return true;
        }
        else if(_OrderType == 1){
            //Instant Buy
            require(_OrderPrice >= AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice, "Placement failed, instant order buy price should");
            require(processOrderBook(_FromAsset, _ToAsset, _TraderAddress, _OrderQty, AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice, _OrderType), "Order placement failed");
            return true;
        }
        else {
            return false;
        }
        
    }

    //**HARUS DITAMBAH CONSTRAIN MAKSIMUM INSTANT ORDER SESUAI DENGAN QTY ORDERBOOK TERSEDIA**//
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
                    _OrderQtySettlement = uint256 (_OrderMustFiLL / _OrderPrice);
                    if (_OrderType == 0){
                        require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderPrice), _OrderQtySettlement, uint256 (_OrderMustFiLL), _OrderType), "Order failed to execute");
                    }
                    else if (_OrderType == 1){
                        require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderPrice), uint256 (_OrderMustFiLL), _OrderQtySettlement, _OrderType), "Order failed to execute");
                    }
                    _OrderMustFiLL = 0;
                    
                    emit Settlement (_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderQty), uint256 (_Value), uint256 (_OrderPrice) );
                    
                    break;
                    
                }
                //partial order fullfill, go to next orderbook list
                else {
                    _OrderMustFiLL -= _Value;
                    _OrderQtySettlement = uint256 (_Value / _OrderPrice);
                    address _TakerAddress = OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TraderAddress;
                    if (_OrderType == 0 && _Value != 0){
                        require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderPrice), _OrderQtySettlement, uint256 (_Value), _OrderType), "Order failed to execute");
                    }
                    else if (_OrderType == 1 && _Value != 0){
                        require (orderSettlement(_FromAsset, _ToAsset, _TraderAddress, _TakerAddress, uint256 (_OrderPrice), uint256 (_Value), _OrderQtySettlement, _OrderType), "Order failed to execute");
                    }
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
                _OrderMustFiLL = (_OrderMustFiLL / (_OrderPrice + 1)) * _OrderPrice;
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
        OrderBook[_FromAsset][_ToAsset][_OrderPrice].push(BlockOrder(_TraderAddress, _OrderQty, _OrderType));

        
        if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice == 0){
            AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice = _OrderPrice;
            return true;
        }
        else if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice == 0){
            AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice = _OrderPrice;
            return true;
        }
        else if(AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice < _OrderPrice && AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice > _OrderPrice){
            
            // DITUKER ITU BID SAMA ASK PRICENYA< NTAR DICOBA
            if (_OrderType == 20){
                AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice = _OrderPrice;
                return true;
            }
            else if (_OrderType == 21){
                AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice = _OrderPrice;
                return true;
            }
        }
        
        return true;
    }

    function removeOrderBook (address _FromAsset, address _ToAsset, address _OrderAddr, int256 _OrderQty, int256 _OrderPrice) external onlyAccHaveAccess override returns (int){
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
            int _OrderType = OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].OrderType;
            delete OrderBook[_FromAsset][_ToAsset][_OrderPrice][i];
            return _OrderType;

        }
        //Remove partial orderbook
        else {
            int _OrderType = OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].OrderType;
            OrderBook[_FromAsset][_ToAsset][_OrderPrice][i].TotalValue -= _OrderQty;
            return _OrderType;
        }


    }

    function orderSettlement (address _FromAsset, address _ToAsset, address _TraderAddressMaker, address _TraderAddressTaker, uint256 _Price, uint256 _OrderQty, uint256 _ValueSettlement, int _OrderType) private returns (bool){
        if (_OrderType == 0 || _OrderType == 20){
            //Send _FromAsset from maker to taker 
            require (IERC20Vault (_FromAsset).transferFromVault(address(this), _TraderAddressMaker,_TraderAddressTaker, _OrderQty), "Order failed to settlement");
            //Send _ToAsset from taker to maker 
            require (IERC20Vault (_ToAsset).transferFromVault(address(this), _TraderAddressTaker,_TraderAddressMaker, _ValueSettlement), "Order failed to settlement");
            emit Settlement (_FromAsset, _ToAsset, _TraderAddressMaker, _TraderAddressTaker, _OrderQty, _ValueSettlement, _Price);
            return true;
        }
        else if (_OrderType == 1 || _OrderType == 21){
            // Send _ToAsset from maker to taker 
            require (IERC20Vault (_ToAsset).transferFromVault(address(this), _TraderAddressMaker,_TraderAddressTaker, _OrderQty), "Order failed to settlement");
            // Send _FromAsset from taker to maker 
            require (IERC20Vault (_FromAsset).transferFromVault(address(this), _TraderAddressTaker,_TraderAddressMaker, _ValueSettlement), "Order failed to settlement");
            emit Settlement (_FromAsset, _ToAsset, _TraderAddressMaker, _TraderAddressTaker, _OrderQty, _ValueSettlement, _Price);
            return true;
        }
        else{
            require(1 == 1, "Order failed to settlement");
            return false;
        }
        
        
    }

    function getPrice (address _FromAsset, address _ToAsset) external override view returns (uint256, uint256) {
       return (uint256 (AssetPrice[_FromAsset][_ToAsset].StartOrderBookBidPrice), uint256 (AssetPrice[_FromAsset][_ToAsset].StartOrderBookAskPrice)) ;
    }
}
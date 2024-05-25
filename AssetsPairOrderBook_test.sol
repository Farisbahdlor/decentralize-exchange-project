// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
// import "remix_accounts.sol";
//change index path to suit you file location
import "../DecentralizedExchange/contracts/AssetsPairOrderBook.sol";



contract testSuite {
    AssetsPairOrderBook public TestAssetsPairOrderBook;
    event TestResult (int256 Test1, int256 Test2);

    function beforeAll() public {
        // <instantiate contract>
        TestAssetsPairOrderBook = new AssetsPairOrderBook();
    }
    
    function checkSuccessFillOrder() public returns (bool success){
        
        int i;
        int j;
        i = 100;
        int256 Test1;
        int256 Test2;
        j = i / 2;
        i = j;
        while (i != 0){
            TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10, j, 20);
            j ++;
            i--;
            TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10, i, 21);
        }
        (Test1, Test2) = TestAssetsPairOrderBook.AssetPrice(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        emit TestResult (Test1,Test2);
        return true;
    }

    function checkInstantBuyOrder(int256 Price, int256 Qty) public returns (bool success){
        
        TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, Qty, Price,1);
        
        return true;
    }

    function checkInstantSellOrder(int256 Price, int256 Qty) public returns (bool success){
        TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, Qty, Price,0);
        return true;
    }

    function checkLimitOrder(int256 Price, int256 Qty, int OrderType) public returns (bool success){
        TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, Qty, Price,(20 + OrderType));
        return true;
    }

    function getValueAssetPrice() public view returns (int256,int256){
        
        return TestAssetsPairOrderBook.AssetPrice(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    }

    function getValueStack(uint256 i) public view returns (address,address,address,int256,int256,int){
        
        return TestAssetsPairOrderBook.StackOrderList(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984,i);
    }

    function getValueOrderBook(int256 price, uint256 index) public view returns (address,int256){
        
        return TestAssetsPairOrderBook.OrderBook(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, price, index);
    }
}

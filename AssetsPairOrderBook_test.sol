// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
//change index path to suit you file location
import "../Permissionless-L1-RollsUp/contracts/AssetsPairOrderBook.sol";



contract testSuite {
    AssetsPairOrderBook public TestAssetsPairOrderBook;
    event TestResult (int256 Test1, int256 Test2);

    function beforeAll() public {
        // <instantiate contract>
        TestAssetsPairOrderBook = new AssetsPairOrderBook();
    }
    
    //input OrderBook List from 0 to 9 price range with 10 qty
    function checkSuccessFillOrder() public returns (bool success){
        
        int i;
        int j;
        i = 10;
        int256 Test1;
        int256 Test2;
        j = i / 2;
        i = j;
        while (i != 0){
            TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10, j, 1);
            j ++;
            i--;
            TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10, i, 1);
        }
        (Test1, Test2) = TestAssetsPairOrderBook.AssetPrice(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        emit TestResult (Test1,Test2);
        return true;
    }

    //fullfill orderbook list with equal qty order 0 to 9 price range
    function checkSuccessFullfillOrder(int256 j) public returns (bool success){
        
        int i;
        int256 Test1;
        int256 Test2;
        i = j;
        for (;i != 10;){
            TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 10, i,1);
            
            i++;
            (Test1, Test2) = TestAssetsPairOrderBook.AssetPrice(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
            emit TestResult (Test1,Test2);
        }
        j--;
        for (;j != 0;){
            TestAssetsPairOrderBook.entryOrderBook(address(this), 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 10, j,1);
            
            j--;
            (Test1, Test2) = TestAssetsPairOrderBook.AssetPrice(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
            emit TestResult (Test1,Test2);
        }
        
        (Test1, Test2) = TestAssetsPairOrderBook.AssetPrice(address(this),0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        
        emit TestResult (Test1,Test2);
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
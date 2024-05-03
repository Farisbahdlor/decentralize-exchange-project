// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingProtocol {
    
    event LoanApproval (address _Collateral, address _Borrow, uint256 _CollateralAmount , uint256 _LoanAmount, uint256 Timestamp, uint256 DueTime);
}

interface IAssetsPairOrderBook {

    // function fillOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice, int OrderType) external returns (bool);
    // function entryOrderBook(address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) external returns (bool);
    // function removeOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice) external returns (bool);
    function getPrice (address _FromAsset, address _ToAsset) external view returns (uint256, uint256);

    // event Settlement (address _FromAsset, address _ToAsset, address _TraderAddress, address _TakerAddress, uint256 _OrderQty, uint256 _ValueSettlement, uint256 _Price);
    // event Transaction
    
}

interface IERC20 {
    function transfer(address _TraderAddressMaker, address _TraderAddressTaker, uint256 _ValueSettlement) external returns (bool) ;
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract LendingProtocol is ILendingProtocol {

    struct LendingData {
        uint256 collateral;
        uint256 InitialLTV;
        uint256 LoanAmount;
        uint256 LoanInterest;
        uint256 StartTime;
        uint256 EndTime;
    }

    //User Lending Data
    //Collateral Asset => Borrowed Asset => User or Vault  => Lending Data
    //Allow user or Vault to borrow from one asset to multiple asset.
    mapping(address => mapping (address => mapping (address => LendingData[]))) private Lending;

    //Loan to Value Ratio
    mapping(address => mapping(address => uint256)) public LoanToValue;
    uint256 LoanFee;

    address Owner;
    address AssetPairOrderBook;


    function isOwner () internal view returns (bool){
        require(msg.sender == Owner, "Only owner have access");
        return true;

    }

    function setLTV (address _CollateralAsset, address _BorrowAsset, uint256 _ValueLTV) external returns (bool){
        require (isOwner(), "Owner validation failed");
        LoanToValue[_CollateralAsset][_BorrowAsset] = _ValueLTV;
        return true;
    }

    function loanAmount(address _CollateralAsset, address _BorrowAsset, uint256 _Value) internal view returns (uint256){
        uint256 _bidPrice;
        uint256 _askPrice;
        uint256 _AmountAfterLTV = _Value * LoanToValue[_CollateralAsset][_BorrowAsset];
        (_bidPrice, _askPrice) = IAssetsPairOrderBook (AssetPairOrderBook).getPrice(_CollateralAsset, _BorrowAsset);
        uint256 _LoanAmountToBorrow = _AmountAfterLTV *  ((_bidPrice + _askPrice) / 2);
        return _LoanAmountToBorrow;
    }

    function Borrow(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Value, uint256 _DueTime) external returns (bool){
        //Borrower must approve first in main contract to execute this function.
        require(IERC20 (_CollateralAsset).allowance(_Borrower, _CollateralAsset) >= _Value);
        //Get loan amount 
        uint256 _LoanAmount = loanAmount(_CollateralAsset, _BorrowAsset, _Value);
        //Transfer collateral asset from user to vault based on loan requested using approval and transferfrom method.
        require(IERC20 (_CollateralAsset).transferFrom(_Borrower, _CollateralAsset, _Value), "Transfer From collateral failed.");
        //Transfer loan asset from vault to user based on loan amount calculation.
        require(IERC20 (_CollateralAsset).transfer(_BorrowAsset, _Borrower, _LoanAmount), "Transfer loan failed.");
        //Loan transaction timestamp
        uint256 _Timestamp = block.timestamp;
        //push Lending Data for record
        Lending[_CollateralAsset][_BorrowAsset][_Borrower].push
        (LendingData(_Value, LoanToValue[_CollateralAsset][_BorrowAsset], _LoanAmount, 0, _Timestamp, _DueTime));
        // Event  Loan Approval.
        emit LoanApproval (_CollateralAsset, _BorrowAsset, _Value, _LoanAmount, _Timestamp, _DueTime);

        return true;
    }


}
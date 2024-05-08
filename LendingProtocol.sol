// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingProtocol {
    function borrow(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Value, uint256 _DueTime) external returns (bool);
    function addCollateral(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _AmountAdd) external returns (bool);
    function decreaseCollateral(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _AmountDecrease) external returns (bool);
    function LTVCheck(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _Value) external view returns (uint256);
    

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

interface IERC20Vault {
    function transfer(address _TraderAddressMaker, address _TraderAddressTaker, uint256 _ValueSettlement) external returns (bool) ;
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract LendingProtocol is ILendingProtocol {

    struct LendingData {
        uint256 Collateral;
        uint256 LTV;
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
    mapping(address => mapping(address => uint256)) public LiquidationRatio;
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

    function borrow(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Value, uint256 _DueTime) external override returns (bool){
        //Borrower must approve first in main contract to execute this function.
        require(IERC20Vault (_CollateralAsset).allowance(_Borrower, address(this)) >= _Value);
        //Get loan amount 
        uint256 _LoanAmount = loanAmount(_CollateralAsset, _BorrowAsset, _Value);
        //Transfer collateral asset from user to vault based on loan requested using approval and transferfrom method.
        require(IERC20Vault (_CollateralAsset).transferFrom(_Borrower, _CollateralAsset, _Value), "Transfer From collateral failed.");
        //Transfer loan asset from vault to user based on loan amount calculation.
        require(IERC20Vault (_BorrowAsset).transfer(_BorrowAsset, _Borrower, _LoanAmount), "Transfer loan failed.");
        //Loan transaction timestamp
        uint256 _Timestamp = block.timestamp;
        //push Lending Data for record
        Lending[_CollateralAsset][_BorrowAsset][_Borrower].push
        (LendingData(_Value, LoanToValue[_CollateralAsset][_BorrowAsset], _LoanAmount, 0, _Timestamp, _DueTime));
        // Event  Loan Approval.
        emit LoanApproval (_CollateralAsset, _BorrowAsset, _Value, _LoanAmount, _Timestamp, _DueTime);

        return true;
    }
    

    function addCollateral(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _AmountAdd) external override returns (bool){
        //Borrower must approve first in main contract to execute this function.
        require(IERC20Vault (_CollateralAsset).allowance(_Borrower, address(this)) >= _AmountAdd);
        //Transfer collateral asset from user to vault based on loan requested using approval and transferfrom method.
        
        uint256 _NewCollateral = Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral + _AmountAdd;
        uint256 _NewLTV = LTVCheck(_CollateralAsset, _Borrower, _BorrowAsset, _Index, _NewCollateral);
        require(_NewLTV >= LiquidationRatio[_CollateralAsset][_BorrowAsset], "New LTV must lower then liquidation ratio");
        require(IERC20Vault (_CollateralAsset).transferFrom(_Borrower, _CollateralAsset, _AmountAdd), "Transfer From new added collateral failed.");
        require(loanToValueUpdate(_CollateralAsset, _Borrower, _BorrowAsset, _Index, _NewCollateral, _NewLTV), "LTV update failed");

        return true;
    }

    function decreaseCollateral(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _AmountDecrease) external override returns (bool){
        uint256 _NewCollateral = Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral + _AmountDecrease;
        uint256 _NewLTV = LTVCheck(_CollateralAsset, _Borrower, _BorrowAsset, _Index, _NewCollateral);
        require(_NewLTV >= LiquidationRatio[_CollateralAsset][_BorrowAsset], "New LTV must lower then liquidation ratio");
        require(IERC20Vault (_CollateralAsset).transfer(_CollateralAsset, _Borrower, _AmountDecrease), "Transfer amount collateral decrease failed");
        require(loanToValueUpdate(_CollateralAsset, _Borrower, _BorrowAsset, _Index, _NewCollateral, _NewLTV), "LTV update failed");

        return true;
    }
    function loanToValueUpdate(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _NewCollateralValue, uint256 _NewLTV) internal returns (bool){
        Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LTV = _NewLTV;
        Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral = _NewCollateralValue;
        return true;
    }

    //LTV check public to external
    function LTVCheck(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _Value) public view override returns (uint256){
        // uint256 _LoanAmount = Lending[_CollateralAsset][_BorrowAsset][_Borrower].LoanAmount;
        uint256 _NewLTV = Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanAmount / loanAmount(_CollateralAsset, _BorrowAsset, _Value) * 100;
        return _NewLTV;
    }

    function paybackLoan(address _CollateralAsset, address _Borrower, address _BorrowAsset) external returns (bool){

    }

}

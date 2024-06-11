// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity ^0.8.0;

import "../interfaces/IAssetsPairOrderBook.sol";
import "../interfaces/IERC20Vault.sol";
import "../interfaces/ILendingProtocol.sol";


contract LendingProtocol is ILendingProtocol {

    struct LendingData {
        uint256 Collateral;
        uint256 LTV;
        uint256 LoanAmount;
        uint256 LoanInterest;
        uint256 StartTime;
        uint256 EndTime;
    }

    struct LoanLiquidationData {
        uint256 Collateral;
        uint256 StartTime;
        uint256 EndTime;
        bool LiquidationStatus;
    }

    mapping (address => mapping(address => LoanLiquidationData[])) private LoanLiquidationList;

    //User Lending Data
    //Collateral Asset => Borrowed Asset => User or Vault  => Lending Data
    //Allow user or Vault to borrow from one asset to multiple asset.
    mapping(address => mapping (address => mapping (address => LendingData[]))) private Lending;

    //Loan to Value Ratio
    mapping(address => mapping(address => uint256)) public LoanToValue;
    mapping(address => mapping(address => uint256)) public LiquidationRatio;

    //Loan fee for 24 hour.
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
        uint256 _price;
        uint256 _AmountAfterLTV = _Value * LoanToValue[_CollateralAsset][_BorrowAsset];
        _price = getPrice(_CollateralAsset, _BorrowAsset);
        uint256 _LoanAmountToBorrow = _AmountAfterLTV *  _price;
        return _LoanAmountToBorrow;
    }

    function getPrice(address _CollateralAsset, address _BorrowAsset) internal view returns (uint256){
        uint256 _bidPrice;
        uint256 _askPrice;
        (_bidPrice, _askPrice) = IAssetsPairOrderBook (AssetPairOrderBook).getPrice(_CollateralAsset, _BorrowAsset);
        return ((_bidPrice + _askPrice) / 2);
    }

    function borrow(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Value, uint256 _DueTime) external override returns (bool){
        //Borrower must approve first in main contract to execute this function.
        require(IERC20Vault (_CollateralAsset).allowanceVault(_Borrower, address(this)) >= _Value);
        //Get loan amount 
        uint256 _LoanAmount = loanAmount(_CollateralAsset, _BorrowAsset, _Value);
        //Transfer collateral asset from user to vault based on loan requested using approval and transferfrom method.
        require(IERC20Vault (_CollateralAsset).transferFromVault(_Borrower, _CollateralAsset, _Value), "Transfer From collateral failed.");
        //Transfer loan asset from vault to user based on loan amount calculation.
        require(IERC20Vault (_BorrowAsset).transferVault(_BorrowAsset, _Borrower, _LoanAmount), "Transfer loan failed.");
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
        require(IERC20Vault (_CollateralAsset).allowanceVault(_Borrower, address(this)) >= _AmountAdd);
        //Transfer collateral asset from user to vault based on loan requested using approval and transferfrom method.
        
        uint256 _NewCollateral = Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral + _AmountAdd;
        uint256 _NewLTV = LTVCheck(_CollateralAsset, _Borrower, _BorrowAsset, _Index, _NewCollateral);
        require(_NewLTV >= LiquidationRatio[_CollateralAsset][_BorrowAsset], "New LTV must lower then liquidation ratio");
        require(IERC20Vault (_CollateralAsset).transferFromVault(_Borrower, _CollateralAsset, _AmountAdd), "Transfer From new added collateral failed.");
        require(loanToValueUpdate(_CollateralAsset, _Borrower, _BorrowAsset, _Index, _NewCollateral, _NewLTV), "LTV update failed");

        return true;
    }

    function decreaseCollateral(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _AmountDecrease) external override returns (bool){
        uint256 _NewCollateral = Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral - _AmountDecrease;
        uint256 _NewLTV = LTVCheck(_CollateralAsset, _Borrower, _BorrowAsset, _Index, _NewCollateral);
        require(_NewLTV >= LiquidationRatio[_CollateralAsset][_BorrowAsset], "New LTV must lower then liquidation ratio");
        require(IERC20Vault (_CollateralAsset).transferVault(_CollateralAsset, _Borrower, _AmountDecrease), "Transfer amount collateral decrease failed");
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

    function updateLoanInterest(address _collateralAsset, address _borrower, address _borrowAsset, uint256 _index) internal view returns (uint256){
        return ((block.timestamp - Lending[_collateralAsset][_borrowAsset][_borrower][_index].StartTime) % 86400) * LoanFee / 100 * Lending[_collateralAsset][_borrowAsset][_borrower][_index].LoanAmount;

    }

    function repayLoan(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _Amount) external override returns (bool) {
        // require(expire);
        require(IERC20Vault(_BorrowAsset).allowanceVault(_Borrower, address(this)) >= _Amount, "Insufficient allowance");
        require(IERC20Vault(_BorrowAsset).transferFromVault(_Borrower, _BorrowAsset, _Amount), "Transfer loan repayment failed.");
        Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanInterest = updateLoanInterest(_CollateralAsset, _Borrower, _BorrowAsset, _Index);
        uint256 _repayAmount = _Amount - Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanInterest;
        require(Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanAmount >= _repayAmount , "Repay amount more than remaining borrowed asset");
        Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanInterest = 0;
        uint256 _percentageRepay = _repayAmount / Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanAmount;
        uint256 _repayAmountConvert = (_percentageRepay * _repayAmount) / getPrice(_CollateralAsset, _BorrowAsset);
        Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral -= _repayAmountConvert;
        Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanAmount -= _repayAmount;
        require(IERC20Vault (_CollateralAsset).transferVault(_CollateralAsset, _Borrower, _repayAmountConvert), "Transfer amount collateral decrease failed");
        Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].StartTime = block.timestamp;
        emit LoanRepaid(_CollateralAsset, _BorrowAsset, _Borrower, _Amount, block.timestamp);
        if(Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral == 0 && Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].LoanAmount == 0){
            deleteLoan(_CollateralAsset, _Borrower, _BorrowAsset, _Index);
        }
        else if(Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].StartTime >= Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].EndTime){
            liquidationLoan(_CollateralAsset, _Borrower, _BorrowAsset, _Index);
        }
        else if(1==1){}//LTV Check//)
        return true;
    }

    function deleteLoan(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index) internal returns (bool){
        uint256 LenMin1 = Lending[_CollateralAsset][_BorrowAsset][_Borrower].length-1;
        // uint256 i;
        if(LenMin1 == 0 || _Index == LenMin1 +1){
            Lending[_CollateralAsset][_BorrowAsset][_Borrower].pop();
            return true;
        }
        else {
            for(; _Index < LenMin1; _Index++){
                Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index] = Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index+1];
            }
            Lending[_CollateralAsset][_BorrowAsset][_Borrower].pop();
            return true;
        }
    }

    function liquidationLoan(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index) public override returns (bool) {
        require(block.timestamp >= Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].EndTime, "Loan not matured yet");
        uint256 liquidationAmount = Lending[_CollateralAsset][_BorrowAsset][_Borrower][_Index].Collateral * LiquidationRatio[_CollateralAsset][_BorrowAsset] / 100;
        require(addLiquidationData(_CollateralAsset, _BorrowAsset, liquidationAmount), "Add liquidation data failed");
        require(deleteLoan(_CollateralAsset, _Borrower, _BorrowAsset, _Index), "Delete loan failed");
        emit LoanLiquidated(_CollateralAsset, _BorrowAsset, _Borrower, liquidationAmount, block.timestamp);
        return true;
    }

    function addLiquidationData(address _CollateralAsset, address _BorrowAsset, uint256 _Amount) internal returns (bool){
        LoanLiquidationList[_CollateralAsset][_BorrowAsset].push(LoanLiquidationData(_Amount, block.timestamp, block.timestamp + 86400, true));
        return true;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingProtocol {
    function borrow(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Value, uint256 _DueTime) external returns (bool);
    function addCollateral(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _AmountAdd) external returns (bool);
    function decreaseCollateral(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _AmountDecrease) external returns (bool);
    function LTVCheck(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _Value) external view returns (uint256);
    function repayLoan(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index, uint256 _Amount) external returns (bool);
    function liquidationLoan(address _CollateralAsset, address _Borrower, address _BorrowAsset, uint256 _Index) external returns (bool);

    event LoanLiquidated(address _CollateralAsset, address _BorrowAsset, address _Borrower, uint256 _LiquidationAmount, uint256 _timestamp);
    event LoanApproval (address _Collateral, address _Borrow, uint256 _CollateralAmount , uint256 _LoanAmount, uint256 _timestamp, uint256 _dueTime);
    event LoanRepaid(address _collateralAsset, address _borrowAsset, address _borrower, uint256 _amount, uint256 _timestamp);
}
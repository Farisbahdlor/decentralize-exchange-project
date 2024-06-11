// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAssetsPairOrderBook {

    // function fillOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice, int OrderType) external returns (bool);
    function entryOrderBook(address _FromAsset, address _ToAsset, address _TraderAddress, int256 _OrderQty, int256 _OrderPrice, int _OrderType) external returns (bool);
    function removeOrderBook (address FromAsset, address ToAsset, address OrderAddr, int256 OrderQty, int256 OrderPrice) external returns (int);
    function getPrice (address _FromAsset, address _ToAsset) external view returns (uint256, uint256);
    function transferOwner(address _NewOwner) external returns (bool);
    function setXchange(address _Xchange) external returns (bool);

    event Settlement (address _FromAsset, address _ToAsset, address _TraderAddress, address _TakerAddress, uint256 _OrderQty, uint256 _ValueSettlement, uint256 _Price);
    // event Transaction
    
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



interface IERC20Vault {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function getName() external returns (string memory);
    function getSymbol() external returns (string memory);
    function getDecimals() external returns (uint8);

    function setPublicVariable (string memory name, string memory symbol, uint8 decimals) external returns (address);
    function deposit(address depositor, uint256 numTokens) external returns (bool);
    function transfer(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address owner, address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Deposit(address indexed depositor, uint256 numTokens);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20 {
    function name() external view returns (string calldata) ;
    function symbol() external view returns (string calldata) ;
    function decimals() external view returns (uint8) ;
    function totalSupply() external view returns (uint256) ;
    function balanceOf(address _owner) external view returns (uint256 balance) ;
    function transfer(address _to, uint256 _value) external returns (bool success) ;
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success) ;
    function approve(address _spender, uint256 _value) external returns (bool success) ;
    function allowance(address _owner, address _spender) external view returns (uint256 remaining) ;
}


contract ERC20Vault is IERC20Vault {

    string internal  name;
    string internal  symbol;
    uint8 internal   decimals;


    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;

    uint256 totalSupply_;
    address contractOwner;
    address originalContractAddress;


   constructor(address _originalContractAddress) {
    // balances[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = totalSupply_ *10 ** 18;
    totalSupply_ = 0;
    contractOwner = (msg.sender);
    originalContractAddress = _originalContractAddress;

    }

    function getName() external override view returns (string memory){
        return name;
    }

    function getSymbol() external override view returns (string memory){
        return symbol;
    }

    function getDecimals() external override view returns (uint8){
        return decimals;
    }

    function setPublicVariable (string memory _name, string memory _symbol, uint8 _decimals) external override returns (address) {
        require ((msg.sender) == contractOwner);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        return (address(this));
    }

    function totalSupply() public override view returns (uint256) {
    return totalSupply_;
    }

    function balanceOf(address tokenOwner) public override view returns (uint256) {
        return balances[tokenOwner];
    }

    function deposit(address depositor, uint256 numTokens) external override returns (bool){
        require(IERC20 (originalContractAddress).allowance(depositor, address(this)) >= numTokens, "Not enough allowance to spend");
        IERC20 (originalContractAddress).transferFrom(depositor, address(this), numTokens);
        require (mint(address(0), numTokens), "Mint wrapped token failed");
        transfer(address(0), depositor, numTokens);

        emit Deposit(depositor, numTokens);
        return true;

    }

    function mint(address mintAddress, uint256 numToken) internal returns (bool){
        balances[mintAddress] += numToken;
        return true;
    }

    function transfer(address sender, address receiver, uint256 numTokens) public override returns (bool) {

        require(numTokens <= balances[sender]);
        balances[sender] = balances[sender]-numTokens;
        balances[receiver] = balances[receiver]+numTokens;
        emit Transfer(sender, receiver, numTokens);
        return true;
    }

    function approve(address owner, address spender, uint256 numTokens) public override returns (bool) {
       
        allowed[owner][spender] = numTokens;
        emit Approval(owner, spender, numTokens);
        return true;
    }

    function allowance(address owner, address spender) public override view returns (uint) {
        return allowed[owner][spender];
    }



    function transferFrom(address owner, address recipient, uint256 numTokens) public override returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);
        balances[owner] = balances[owner]-numTokens;
        allowed[owner][msg.sender] = allowed[owner][msg.sender]-numTokens;
        balances[recipient] = balances[recipient]+numTokens;
        emit Transfer(owner, recipient, numTokens);
        return true;
    }
}


interface IDex {

    function createVaultToken (address originalContractAddress, string memory _name, string memory _symbol, uint8 _decimals) external returns (bool);
    function balanceOf (address indeERC20ContractAddress, address tokenOwner) external view returns (uint256);
    function deposit (address ERC20ContractAddress, uint256 _amount) external returns (bool);
    function approve(address ERC20ContractAddress, uint256 _amount) external returns (uint256);

}


contract Xchange is IDex{

    // event Bought(uint256 amount);
    // event Sold(uint256 amount);

    struct Token {
        address wrappedContractAddress;
        address originalContractAddress;
    }

    mapping (address => Token ) public ERC20VaultList;
    address [] public ERC20TokenList;

    ERC20Vault private vault;
    address owner;

    constructor() {
        owner = msg.sender;
        
    }


    function createVaultToken (address originalContractAddress, string memory _name, string memory _symbol, uint8 _decimals) external override returns (bool) {
        require((msg.sender) == owner, "Only owner can create new ERC20 token vault");
        vault = new ERC20Vault(originalContractAddress);
        address wrappedContractAddress = addTokenDetails(_name, _symbol, _decimals);
        ERC20VaultList[originalContractAddress] = Token(wrappedContractAddress, originalContractAddress);
        ERC20TokenList.push(originalContractAddress);
        return true;
    }

    function addTokenDetails (string memory _name, string memory _symbol, uint8 _decimals) internal returns (address){
        return vault.setPublicVariable(_name, _symbol, _decimals);
    }

    function balanceOf (address ERC20ContractAddress, address tokenOwner) external override view returns (uint256){
        return (IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).balanceOf(tokenOwner));
        
    }
    
    function deposit (address ERC20ContractAddress, uint256 _amount) external override returns (bool){
        require(IERC20 (ERC20ContractAddress).approve(ERC20VaultList[ERC20ContractAddress].wrappedContractAddress, _amount), "Approval Failed");
        require(IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).deposit(msg.sender, _amount), "Failed to transfer deposit balance");
        return true;
    }

    function approve(address ERC20ContractAddress, uint256 _amount) external override returns (uint256){
        require (IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).approve(msg.sender, address(this), _amount), "Approval failed");
        
        return (IERC20Vault (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).allowance(msg.sender, address(this)));
    }

    function transferFrom (address wrappedContractAddress, address sender, address recepient, uint256 _amount) internal returns (bool) {
        require (IERC20Vault (wrappedContractAddress).transferFrom(sender, recepient, _amount), "Transfer from method failed");
        return true;
        
    }

}

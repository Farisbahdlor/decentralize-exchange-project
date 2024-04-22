// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function getName() external returns (string memory);
    function getSymbol() external returns (string memory);
    function getDecimals() external returns (uint8);

    function setPublicVariable (string memory name, string memory symbol, uint8 decimals) external returns (address);
    function deposit(address depositor, uint256 numTokens) external returns (bool);
    function transfer(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Deposit(address indexed depositor, uint256 numTokens);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract ERC20Basic is IERC20 {

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
        require(IERC20 (originalContractAddress).allowance(depositor, address(this)) >= numTokens);
        IERC20 (originalContractAddress).transferFrom(depositor, address(this), numTokens);
        transfer(address(0), depositor, numTokens);

        emit Deposit(depositor, numTokens);
        return true;

    }
    function transfer(address sender, address receiver, uint256 numTokens) public override returns (bool) {

        require(numTokens <= balances[sender]);
        balances[sender] = balances[sender]-numTokens;
        balances[receiver] = balances[receiver]+numTokens;
        emit Transfer(sender, receiver, numTokens);
        return true;
    }

    function approve(address spender, uint256 numTokens) public override returns (bool) {
        allowed[msg.sender][spender] = numTokens;
        emit Approval(msg.sender, spender, numTokens);
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
    function transfer(address ERC20ContractAddress, address recepient, uint256 _amount) external returns (bool);

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

    IERC20 private vault;
    address owner;

    constructor() {
        owner = msg.sender;
        
    }


    function createVaultToken (address originalContractAddress, string memory _name, string memory _symbol, uint8 _decimals) external override returns (bool) {
        require((msg.sender) == owner, "Only owner can create new ERC20 token vault");
        vault = new ERC20Basic(originalContractAddress);
        address wrappedContractAddress = addTokenDetails(_name, _symbol, _decimals);
        ERC20VaultList[originalContractAddress] = Token(wrappedContractAddress, originalContractAddress);
        ERC20TokenList.push(originalContractAddress);
        return true;
    }

    function addTokenDetails (string memory _name, string memory _symbol, uint8 _decimals) internal returns (address){
        return vault.setPublicVariable(_name, _symbol, _decimals);
    }

    function balanceOf (address ERC20ContractAddress, address tokenOwner) external override view returns (uint256){
        return (IERC20 (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).balanceOf(tokenOwner));
        
    }
    
    function deposit (address ERC20ContractAddress, uint256 _amount) external override returns (bool){
        require(IERC20 (ERC20ContractAddress).approve(ERC20VaultList[ERC20ContractAddress].wrappedContractAddress, _amount), "Approval Failed");
        require(IERC20 (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).deposit(msg.sender, _amount), "Failed to transfer deposit balance");
        return true;
    }

    function transfer(address ERC20ContractAddress, address recepient, uint256 _amount) external override returns (bool){
        return (IERC20 (ERC20VaultList[ERC20ContractAddress].wrappedContractAddress).transfer(msg.sender, recepient, _amount));
    }


    // function buy() payable public {
    //     uint256 amountTobuy = msg.value;
    //     uint256 dexBalance = token.balanceOf(address(this));
    //     require(amountTobuy > 0, "You need to send some ether");
    //     require(amountTobuy <= dexBalance, "Not enough tokens in the reserve");
    //     // token.transfer(msg.sender, amountTobuy);
    //     emit Bought(amountTobuy);
    // }

    // function sell(uint256 amount) public {
    //     require(amount > 0, "You need to sell at least some tokens");
    //     uint256 allowance = token.allowance(msg.sender, address(this));
    //     require(allowance >= amount, "Check the token allowance");
    //     token.transferFrom(msg.sender, address(this), amount);
    //     payable(msg.sender).transfer(amount);
    //     emit Sold(amount);
    // }

}

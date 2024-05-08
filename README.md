# Decentralize-Exchange-Project
Date : 08/05/2024

Ongoing progress making Decentralized Exchange (DEX) smart contract write in solidity, some more DEX feature available will be explained later...

1. **ERC20Vault Interface (`IERC20Vault`)**: Defines the interface for an ERC20 token vault, including functions for total supply, balance of an account, allowance, token name, symbol, and decimals. It also includes functions for deposit, withdrawal, transfer, and approval.

2. **ERC20 Interface (`IERC20`)**: Defines the standard ERC20 interface with functions like name, symbol, decimals, total supply, balance of an account, transfer, transferFrom, approve, and allowance.

3. **ERC20Vault Contract (`ERC20Vault`)**: Implements the ERC20Vault interface. This contract serves as a vault for wrapping ERC20 tokens. It allows depositing and withdrawing tokens, as well as transferring tokens between accounts. Additionally, it handles approvals for transferring tokens on behalf of another account.

4. **DEX Interface (`IDex`)**: Defines the interface for a decentralized exchange (DEX) contract. It includes functions for creating vault tokens, checking balances, depositing and withdrawing tokens, approving token transfers, transferring tokens, lending assets, managing collateral, and interacting with an order book.

5. **Lending Protocol Interface (`ILendingProtocol`)**: Defines the interface for a lending protocol contract. It includes functions for borrowing assets, adding collateral, decreasing collateral, and checking loan-to-value (LTV) ratios.

6. **Assets Pair Order Book Interface (`IAssetsPairOrderBook`)**: Defines the interface for an order book contract that manages trading pairs. It includes functions for entering orders, removing orders, and getting price information for trading pairs.

7. **Xchange Contract (`Xchange`)**: Implements the DEX interface. This contract allows creating vault tokens, managing balances, depositing and withdrawing tokens, approving token transfers, transferring tokens, lending assets, managing collateral, and interacting with an order book.

Overall, its provides a framework for creating and managing ERC20 tokens, as well as enabling decentralized exchange and lending functionalities. Users can interact with the system to trade tokens, lend assets, and manage their balances and orders.

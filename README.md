## При клонировании требуется:

# Установить библиотеки:
bun install
forge install 
forge install uniswap/universal-router@705f7bb9836ebc4f6ad1aad91629c3d0fc4128d4

'Для установки корректной версии universal-router следует использовать с хэшем коммитам, иначе ставится версия по последнему тегу 2024 года

# Создать файл .env в корневой директории:
MAINNET_RPC_URL=""
SEPOLIA_RPC_URL=""
ETHERSCAN_API_KEY=""
PRIVATE_KEY=""

# Создать файл .env в директории Web3\WeValue-wagmi:
VITE_MAINNET_RPC_URL=""
VITE_SEPOLIA_RPC_URL=""

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## При клонировании требуется:

# Установить библиотеки:
bun install

forge install 

forge install uniswap/universal-router@705f7bb9836ebc4f6ad1aad91629c3d0fc4128d4

'Для установки корректной версии universal-router следует использовать с хэшем коммитом, иначе ставится версия по последнему тегу 2024 года

# Создать файл .env в корневой директории:
MAINNET_RPC_URL=""
## Только для скриптов
PRIVATE_KEY=""

MULTISIG_ADDRESS=""

PROXY_ADDRESS=""

SEPOLIA_RPC_URL=""

ETHERSCAN_API_KEY=""

# Для запуска всех тестов 
### должны пройти всех кроме test_EvacuateIfDepegged_Fork_Flashloan_Success так как фокус с займом не срабатывает

forge test --fork-url mainnet --mc WeValueTest

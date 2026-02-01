import { useReadContracts, useGasPrice, useBalance, type BaseError } from 'wagmi'
import { WeValueContractConfig } from './contracts'
import { formatUnits, formatEther } from 'viem'

interface ReadContractProps {
  address: `0x${string}` | undefined;
}

/**
 * Компонент для отображения публичной информации о контракте WeValue.
 * Отображается всегда, независимо от подключения кошелька.
 */
export function ContractInfo() {
  // Запрос публичных данных, который выполняется всегда
  const { data: publicData, isLoading } = useReadContracts({
    contracts: [
      {
        ...WeValueContractConfig,
        functionName: 'name',
      },
      {
        ...WeValueContractConfig,
        functionName: 'decimals',
      },
      {
        ...WeValueContractConfig,
        functionName: 'totalSupply',
      },
      {
        ...WeValueContractConfig,
        functionName: 'protectedAsset',
      },
    ],
  });

  const [name, decimals, totalSupply, protectedAsset] = publicData?.map(item => item.result) ?? [];

  if (isLoading) return <div>Fetching contract info...</div>;

  return (
    <>
      <div>Общий баланс всех пользователей: {totalSupply !== undefined && decimals !== undefined ? formatUnits(totalSupply, decimals) : 'N/A'} {name}</div>
      <br />
      <ReadContractProtectedAsset address={protectedAsset} />
    </>
  )
}

/**
 * Компонент для отображения баланса токенов WeValue для конкретного пользователя.
 * Отображается только при подключенном кошельке.
 */
export function UserTokenBalance({ address }: ReadContractProps) {
  const { data, isLoading } = useReadContracts({
    contracts: [
      { ...WeValueContractConfig, functionName: 'balanceOf', args: [address!] },
      { ...WeValueContractConfig, functionName: 'name' },
      { ...WeValueContractConfig, functionName: 'decimals' },
    ],
    query: { enabled: !!address },
  });

  if (isLoading) return <div>Fetching your token balance...</div>;

  const [balance, name, decimals] = data?.map(item => item.result) ?? [];

  return (
    <div>
      <h2>Созданная Вами ценность</h2>
      <div>Ваш баланс: {balance !== undefined && decimals !== undefined ? formatUnits(balance, decimals) : '0'} {name}</div>
    </div>
  );
}

function ReadContractProtectedAsset({ address }: ReadContractProps) {
  // Если адрес еще не загружен, ничего не рендерим
  if (!address) {
    return <div>Loading protected asset info...</div>;
  }

  const { data: publicData, isLoading } = useReadContracts({
    contracts: [
      {
        address: address, // Адрес protectedAsset
        abi: WeValueContractConfig.abi, // Используем более полный ABI от WeValue, т.к. он тоже erc20
        functionName: 'name',
      },
      {
        address: address, 
        abi: WeValueContractConfig.abi, 
        functionName: 'decimals',
      },
      {
        address: address, 
        abi: WeValueContractConfig.abi, 
        functionName: 'balanceOf',
        args: [WeValueContractConfig.address], // Баланс контракта WeValue
      }
    ],
  });

  if (isLoading) return <div>Fetching protected asset balance...</div>;
    
  const [name, decimals, balance] = publicData?.map(item => item.result) ?? [];
  console.log("Адрес токена: ", address);
  console.log("Баланс фонда: ", balance, "Валюта: ", name, "Десятичные цифры: ", decimals);

  return (
    <div>Баланс фонда: {balance !== undefined && decimals !== undefined ? formatUnits(balance, decimals) : 'N/A'} {name} </div>
  )  
}

export function CurrentPriceGaz({ chain }: { chain?: { nativeCurrency?: { decimals: number; symbol: string } } }){
  const { data, isLoading, isError } = useGasPrice();
   if (isLoading) return <div>Fetching gas price</div>;
   if (isError) return <div>Error fetching gas price</div>;
   
   const gasPriceFormatted = data && chain?.nativeCurrency
     ? formatUnits(data, chain.nativeCurrency.decimals)
     : 'N/A';
 
   return (
     <div>Текущая цена газа: {gasPriceFormatted} {chain?.nativeCurrency?.symbol}</div>
   );
}

export function BalanceWallet({ address }: ReadContractProps) {
  if (!address) return null;

  const { data, isLoading, isError } = useBalance({
    address: address
  });

  if (isLoading) return <div>Fetching native balance...</div>;
  if (isError) return <div>Error fetching native balance</div>;
  return (
    <div>Баланс кошелька: {data?.value && data?.decimals ? formatEther(data?.value, "gwei") : 'N/A'} gwei </div>
  )
}

export function BalanceContract() {
  if (!WeValueContractConfig.address) return null;

  const { data, isLoading, isError } = useBalance({
    address: WeValueContractConfig.address
  });

  if (isLoading) return <div>Fetching native balance...</div>;
  if (isError) return <div>Error fetching native balance</div>;
  return (
    <div>Баланс контракта: {data?.value && data?.decimals ? formatEther(data?.value, "gwei") : 'N/A'} gwei </div>
  )
}
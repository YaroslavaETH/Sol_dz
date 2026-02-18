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
  const { data: publicData, isLoading, isError, error } = useReadContracts({
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
  
  if (isLoading) return <div className="alert alert-info">Загрузка информации о контракте...</div>;
  if (isError) {
    return <div className="alert alert-danger">Ошибка загрузки данных: {(error as BaseError).shortMessage || error.message}</div>
  }

  return (
    <div className="mb-3">
      <div className="alert alert-success">
        <strong>Общий баланс всех пользователей:</strong> {totalSupply !== undefined && decimals !== undefined ? formatUnits(totalSupply, decimals) : 'N/A'} {name}
      </div>
      <ReadContractProtectedAsset address={protectedAsset} />
    </div>
  )
}

/**
 * Компонент для отображения баланса токенов WeValue для конкретного пользователя.
 * Отображается только при подключенном кошельке.
 */
export function UserTokenBalance({ address }: ReadContractProps) {
  const { data, isLoading, isError, error } = useReadContracts({
    contracts: [
      { ...WeValueContractConfig, functionName: 'balanceOf', args: [address!] },
      { ...WeValueContractConfig, functionName: 'name' },
      { ...WeValueContractConfig, functionName: 'decimals' },
    ],
    query: { enabled: !!address },
  });

  if (isLoading) return <div className="alert alert-info">Загрузка вашего баланса...</div>;
  if (isError) {
    return <div className="alert alert-danger">Ошибка загрузки баланса: {(error as BaseError).shortMessage || error.message}</div>
  }

  const [balance, name, decimals] = data?.map(item => item.result) ?? [];

  return (
    <div className="mt-3">
      <h3 className="mb-3">Созданная Вами ценность</h3>
      <div className="alert alert-primary">
        <strong>Ваш баланс:</strong> {balance !== undefined && decimals !== undefined ? formatUnits(balance, decimals) : '0'} {name}
      </div>
    </div>
  );
}

function ReadContractProtectedAsset({ address }: ReadContractProps) {
  // Если адрес еще не загружен, ничего не рендерим
  if (!address) {
    return <div className="alert alert-info">Загрузка информации о защищенном активе...</div>;
  }

  const { data: publicData, isLoading, isError, error } = useReadContracts({
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

  if (isLoading) return <div className="alert alert-info">Загрузка баланса защищенного актива...</div>;
  if (isError) {
    return <div className="alert alert-danger">Ошибка загрузки баланса фонда: {(error as BaseError).shortMessage || error.message}</div>
  }
    
  const [name, decimals, balance] = publicData?.map(item => item.result) ?? [];

  return (
    <div className="alert alert-info">
      <strong>Баланс фонда:</strong> {balance !== undefined && decimals !== undefined ? formatUnits(balance, decimals) : 'N/A'} {name}
    </div>
  )  
}

export function BalanceWallet({ address }: ReadContractProps) {
  if (!address) return null;

  const { data, isLoading, isError } = useBalance({
    address: address
  });

  if (isLoading) return <div className="alert alert-info">Загрузка баланса...</div>;
  if (isError) return <div className="alert alert-danger">Ошибка загрузки баланса</div>;
  return (
    <div className="alert alert-secondary">
      <strong>Баланс кошелька:</strong> {data?.value && data?.decimals ? formatEther(data?.value, "wei") : 'N/A'} wei
    </div>
  )
}

export function BalanceContract() {
  if (!WeValueContractConfig.address) return null;

  const { data, isLoading, isError } = useBalance({
    address: WeValueContractConfig.address
  });

  if (isLoading) return <div className="alert alert-info">Загрузка баланса контракта...</div>;
  if (isError) return <div className="alert alert-danger">Ошибка загрузки баланса контракта</div>;
  return (
    <div className="alert alert-warning">
      <strong>Баланс контракта:</strong> {data?.value && data?.decimals ? formatEther(data?.value, "wei") : 'N/A'} wei
    </div>
  )
}
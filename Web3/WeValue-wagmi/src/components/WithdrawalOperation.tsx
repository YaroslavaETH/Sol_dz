import { useReadContracts, useGasPrice, useBalance, type BaseError } from 'wagmi'
import { WeValueContractConfig } from '../contracts'

export function WithdrawalOperation() {
// Запрос публичных данных, который выполняется всегда
  const { data: publicData, isLoading, isError, error } = useReadContracts({
    contracts: [
      {
        ...WeValueContractConfig,
        functionName: 'getUnconfirmedOperationsCount',
      },
      {
        ...WeValueContractConfig,
        functionName: 'withdrawalCount',
      },
    ],
  });

  const [UnconfirmedOperationsCount, withdrawalCount] = publicData?.map(item => item.result) ?? [];
  
  if (isLoading) return <div className="alert alert-info">Загрузка информации о контракте...</div>;
  if (isError) {
    return <div className="alert alert-danger">Ошибка загрузки данных: {(error as BaseError).shortMessage || error.message}</div>
  }
  const all = withdrawalCount as number;
  const Unconfirmed = UnconfirmedOperationsCount as number;

  return (
    <div className="mb-3">
      <div className="alert alert-success">
        <strong>Общее количество транзакций оказанной помощи:</strong> {all}
          <br />
        <strong>Из них не подтверждено:</strong> {Unconfirmed}
      </div>
    </div>
  )   
}

export default WithdrawalOperation;
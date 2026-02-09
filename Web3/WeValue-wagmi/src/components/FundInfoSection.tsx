import { useConnection } from 'wagmi';
import { ContractInfo, UserTokenBalance, BalanceContract } from '../read-contract.tsx';

export function FundInfoSection() {
  const connection = useConnection();

  return (
    <section className="card shadow-sm h-100">
      <div className="card-body d-flex flex-column">
        <h2 className="card-title mb-4">Информация по благотворительному фонду</h2>
        <ContractInfo />
        <BalanceContract />
        {connection.isConnected && (
          <UserTokenBalance address={connection.address} />
        )}
      </div>
    </section>
  );
}

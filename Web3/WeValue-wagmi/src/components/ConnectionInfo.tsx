import { useConnection } from 'wagmi';
import { BalanceWallet } from '../read-contract.tsx';

export function ConnectionInfo() {
  const connection = useConnection();

  return (
    <div className="mt-3">
      <BalanceWallet address={connection.address} />
    </div>
  );
}

import { useConnection } from 'wagmi';
import { CurrentPriceGaz, BalanceWallet } from '../read-contract.tsx';

export function ConnectionInfo() {
  const connection = useConnection();

  return (
    <div className="mt-3">
      <CurrentPriceGaz chain={connection.chain} />
      <BalanceWallet address={connection.address} />
    </div>
  );
}

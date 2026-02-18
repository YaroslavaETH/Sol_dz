import { useConnection } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { ConnectionInfo } from './ConnectionInfo';
import { DonationSection } from './DonationSection';

export function ConnectionSection() {
  const connection = useConnection();

  return (
    <section className="card shadow-sm h-100">
      <div className="card-body d-flex flex-column">
        <h2 className="card-title mb-3">Подключение</h2>
        <div className="mb-3">
          <ConnectButton showBalance={true} />
        </div>
        <ConnectionInfo />
        {connection.isConnected && <DonationSection />}
      </div>
    </section>
  );
}

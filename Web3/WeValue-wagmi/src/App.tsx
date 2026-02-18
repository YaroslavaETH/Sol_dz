import { ConnectionSection } from './components/ConnectionSection';
import { FundInfoSection } from './components/FundInfoSection';
import { StatisticsSection } from './components/StatisticsSection';
import { MultiSigManagement } from './components/MultiSigManagement';
import { useAccount } from 'wagmi';

function App() {
  const { isConnected } = useAccount();
  
  return (
    <main className="container-xl container-md" data-bs-theme="dark">
      <div className="row g-4">
        {/* Основные секции */}
        <div className="col-12 col-lg-4">
          <ConnectionSection />
        </div>
        <div className="col-12 col-lg-4">
          <FundInfoSection />
        </div>
        <div className="col-12 col-lg-4">
          <StatisticsSection />
        </div>
        
        {/* MultiSig секция (показывается только владельцам) */}
        {isConnected && (
          <div className="col-12">
            <MultiSigManagement />
          </div>
        )}
      </div>
    </main>
  );
}

export default App;

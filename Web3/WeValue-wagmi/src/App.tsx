import { ConnectionSection } from './components/ConnectionSection';
import { FundInfoSection } from './components/FundInfoSection';
import { StatisticsSection } from './components/StatisticsSection';

function App() {
  return (
    <main className="container-xl container-md" data-bs-theme="dark">
      <div className="row g-4">
        <div className="col-12 col-lg-4">
          <ConnectionSection />
        </div>
        <div className="col-12 col-lg-4">
          <FundInfoSection />
        </div>
        <div className="col-12 col-lg-4">
          <StatisticsSection />
        </div>
      </div>
    </main>
  );
}

export default App;

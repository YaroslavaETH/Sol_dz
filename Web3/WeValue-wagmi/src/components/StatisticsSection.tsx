import DonationChart from '../DonationChart.tsx';
import WithdrawalOperation from './WithdrawalOperation.tsx'

export function StatisticsSection() {
  return (
    <section className="card shadow-sm h-100">
      <div className="card-body d-flex flex-column">
        <h2 className="card-title mb-4">Пожертвования фонду</h2>
        <div className="flex-grow-1">
          <DonationChart />
        </div>
        <h2 className="card-title mb-4">Оказанная помощь фондом </h2>
        <div>
          <WithdrawalOperation/>
        </div>
      </div>
    </section>
  );
}

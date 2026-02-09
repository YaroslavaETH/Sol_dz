import DonationChart from '../DonationChart.tsx';

export function StatisticsSection() {
  return (
    <section className="card shadow-sm h-100">
      <div className="card-body d-flex flex-column">
        <h2 className="card-title mb-4">Статистика помощи фонду</h2>
        <div className="flex-grow-1">
          <DonationChart />
        </div>
      </div>
    </section>
  );
}

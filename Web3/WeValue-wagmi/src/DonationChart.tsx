import { useEffect, useState, useRef } from 'react';
import { useQuery } from '@tanstack/react-query';
import {Chart} from 'chart.js/auto';
import { formatEther } from 'viem';

const DonationChart = () => {
  const [donations, setDonations] = useState<[]>([]);
  const chartRef = useRef<Chart | null>(null);

  // Получаем данные из The Graph
  const { isLoading, data, error } = useQuery({
    queryKey: ['donations'],
    queryFn: async () => {
      const response = await fetch(`https://api.studio.thegraph.com/query/1724651/we-value/version/latest`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          query: `
            {
              donations(orderBy: blockTimestamp, orderDirection: desc) {
                id
                account
                amount
                blockTimestamp
              }
            }
          `,
        }),
      });

      const result = await response.json();
      return result.data.donations;
    },
    staleTime: 60000, // кеш на 1 минуту
  });

  useEffect(() => {
    if (data) {
      setDonations(data);
    }
  }, [data]);

  useEffect(() => {
    if (donations.length > 0) {
      // Уничтожаем предыдущий экземпляр графика, если он существует
      if (chartRef.current) {
        chartRef.current.destroy();
      }

      // Сортируем пожертвования по времени (от старых к новым)
      const sortedDonations = [...donations].sort((a, b) => Number(a.blockTimestamp) - Number(b.blockTimestamp));

      let cumulativeAmount = 0;
      const cumulativeData = sortedDonations.map(d => {
        cumulativeAmount += parseFloat(formatEther(d.amount));
        return cumulativeAmount;
      });

      // Создаем график
      const ctx = document.getElementById('donationChart') as HTMLCanvasElement;
      chartRef.current = new Chart(ctx, {
        // Тип графика не указывается здесь для смешанных диаграмм
        data: {
          labels: sortedDonations.map(d => new Date(Number(d.blockTimestamp) * 1000).toLocaleDateString()),
          datasets: [
            {
              type: 'line', // Этот набор данных будет линией
              label: 'Общая сумма помощи (ETH)',
              data: cumulativeData,
              borderColor: 'rgba(75, 192, 192, 1)',
              backgroundColor: 'rgba(75, 192, 192, 0.2)',
              fill: true,
            },
            {
              type: 'bar', // Этот набор данных будет столбцами
              label: 'Размер пожертвования (ETH)',
              data: sortedDonations.map(d => parseFloat(formatEther(d.amount))),
              backgroundColor: 'rgba(255, 159, 64, 0.5)',
              borderColor: 'rgba(255, 159, 64, 1)',
              barPercentage: 0.5, // Ширина столбца (50% от доступного пространства)
              categoryPercentage: 0.5, // Пространство для категории (50% от доступного)
            },
          ],
        },
        options: {
          responsive: false, // Отключаем отзывчивость, чтобы график использовал размеры canvas
          scales: {
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Сумма (ETH)',
              },
            },
            x: {
              title: {
                display: true,
                text: 'Время',
              },
            },
          },
        },
      });
    }
  }, [donations]);

  if (isLoading) return <div>Загрузка...</div>;
  if (error) return <div>Ошибка при загрузке данных</div>;

  return (
    <div className="donation-chart">
      <div>
        <canvas id="donationChart"></canvas>
        </div>
    </div>
  );
};

export default DonationChart;

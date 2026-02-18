import { useReadContracts, type BaseError } from 'wagmi';
import { WeValueContractConfig } from '../contracts';
import { formatUnits } from 'viem';

/**
 * Компонент для отображения текущей цены protectedAsset и порога депега
 */
export function ProtectedAssetPriceInfo() {
  const { data, isLoading, isError, error } = useReadContracts({
    contracts: [
      {
        ...WeValueContractConfig,
        functionName: 'priceOracle',
      },
      {
        ...WeValueContractConfig,
        functionName: 'depegThreshold',
      },
    ],
  });

  if (isLoading) {
    return (
      <div className="alert alert-info">
        Загрузка информации о цене...
      </div>
    );
  }

  if (isError) {
    return (
      <div className="alert alert-danger">
        Ошибка: {(error as BaseError).shortMessage || error.message}
      </div>
    );
  }

  const [priceOracleAddress, depegThreshold] = data?.map(item => item.result) ?? [];

  if (!priceOracleAddress || !depegThreshold) {
    return null;
  }

  return (
    <>
      <OraclePrice oracleAddress={priceOracleAddress as `0x${string}`} />
      <DepegThreshold threshold={depegThreshold as bigint} />
    </>
  );
}

/**
 * Получить и отобразить текущую цену от оракула Chainlink
 */
function OraclePrice({ oracleAddress }: { oracleAddress: `0x${string}` }) {
  const chainlinkAbi = [
    {
      inputs: [],
      name: 'latestRoundData',
      outputs: [
        { name: 'roundId', type: 'uint80' },
        { name: 'answer', type: 'int256' },
        { name: 'startedAt', type: 'uint256' },
        { name: 'updatedAt', type: 'uint256' },
        { name: 'answeredInRound', type: 'uint80' },
      ],
      stateMutability: 'view',
      type: 'function',
    },
    {
      inputs: [],
      name: 'decimals',
      outputs: [{ name: '', type: 'uint8' }],
      stateMutability: 'view',
      type: 'function',
    },
  ];

  const { data, isLoading } = useReadContracts({
    contracts: [
      {
        address: oracleAddress,
        abi: chainlinkAbi,
        functionName: 'latestRoundData',
      },
      {
        address: oracleAddress,
        abi: chainlinkAbi,
        functionName: 'decimals',
      },
      {
        address: oracleAddress,
        abi: chainlinkAbi,
        functionName: 'description',
      },
    ],
  });

  if (isLoading) return null;

  const [priceData, decimals, description] = data?.map(item => item.result) ?? [];
  
  if (!priceData || !decimals) return null;

  const [, price] = priceData as [bigint, bigint, bigint, bigint, bigint];
  const priceDecimals = decimals as number;
  
  const formattedPrice = formatUnits(price, priceDecimals);
  const priceNumber = parseFloat(formattedPrice);

  return (
    <div className="alert alert-info mb-2">
      <strong>Текущая цена (Chainlink):</strong> {description as string} {priceNumber.toFixed(4)}
    </div>
  );
}

/**
 * Отобразить порог депега
 */
function DepegThreshold({ threshold }: { threshold: bigint }) {
  // Chainlink использует 8 decimals
  const formattedThreshold = formatUnits(threshold, 8);
  const thresholdNumber = parseFloat(formattedThreshold);

  return (
    <div className="alert alert-warning mb-2">
      <strong>Пороговая цена для эвакуации:</strong> ${thresholdNumber.toFixed(4)}
    </div>
  );
}

import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { MultiSigContractConfig, WeValueContractConfig } from '../contracts';
import { encodeFunctionData } from 'viem';
import { ProtectedAssetPriceInfo } from './ProtectedAssetPriceInfo';
import { AdminPanel } from './AdminPanel';

/**
 * Компонент для управления MultiSig кошельком
 * Отображается только для владельцев мультисига
 */
export function MultiSigManagement() {
  const { address } = useAccount();

  // Проверяем является ли пользователь владельцем
  const { data: isOwner } = useReadContract({
    ...MultiSigContractConfig,
    functionName: 'isOwner',
    args: [address!],
    query: { enabled: !!address },
  });

  if (!isOwner) {
    return null; // Не показываем компонент если не владелец
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">🔐 Управление фондом (MultiSig)</h2>
        <p className="text-muted">Раздел доступен только владельцам мультисиг кошелька</p>

        <div className="mt-4">
          {/* Информация о текущей цене, пороге и безопасном активе */}
          <section className="mb-4">
            <ProtectedAssetPriceInfo />
            <SafeAssetInfo />
          </section>

          {/* Функции, доступные любому из владельцев (onlyMultiSigOwner) */}
          <hr />
          <section className="mb-4">
            <h3 className="h5 mb-3">Функции для владельцев фонда (onlyMultiSigOwner)</h3>
            <AdminPanel />
          </section>

          {/* Транзакции MultiSig, ожидающие подтверждения */}
          <hr />
          <section className="mb-4">
            <PendingTransactions />
          </section>

          {/* Предложение транзакций onlyOwner через MultiSig */}
          <hr />
          <section className="mb-2">
            <h3 className="h5 mb-3">Предложить транзакции владельца (onlyOwner)</h3>
            <ProposeTransactionForm />
            <div className="mt-4">
              <UpgradeProposalSection />
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}

/**
 * Список ожидающих транзакций
 */
function PendingTransactions() {
  const { address } = useAccount();

  // Получаем список pending транзакций
  const { data: pendingTxIds } = useReadContract({
    ...MultiSigContractConfig,
    functionName: 'getPendingTransactions',
  });

  // Получаем required подтверждений
  const { data: required } = useReadContract({
    ...MultiSigContractConfig,
    functionName: 'required',
  });

  if (!pendingTxIds || pendingTxIds.length === 0) {
    return (
      <div className="alert alert-info">
        Нет ожидающих транзакций
      </div>
    );
  }

  return (
    <div>
      <h3>Ожидающие транзакции ({pendingTxIds.length})</h3>
      <div className="list-group">
        {pendingTxIds.map((txId) => (
          <TransactionItem
            key={txId.toString()}
            txId={txId}
            required={required || 2n}
            userAddress={address}
          />
        ))}
      </div>
    </div>
  );
}

/**
 * Отдельная транзакция
 */
function TransactionItem({
  txId,
  required,
  userAddress
}: {
  txId: bigint;
  required: bigint;
  userAddress: `0x${string}` | undefined;
}) {
  const { data: tx } = useReadContract({
    ...MultiSigContractConfig,
    functionName: 'getTransaction',
    args: [txId],
  });

  const { data: hasConfirmed } = useReadContract({
    ...MultiSigContractConfig,
    functionName: 'hasConfirmed',
    args: [txId, userAddress!],
    query: { enabled: !!userAddress },
  });

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash });

  if (!tx) return null;

  const [target, value, data, executed, confirmations, description, timestamp] = tx;

  const confirmTx = () => {
    writeContract({
      ...MultiSigContractConfig,
      functionName: 'confirmTransaction',
      args: [txId],
    });
  };

  const revokeTx = () => {
    writeContract({
      ...MultiSigContractConfig,
      functionName: 'revokeConfirmation',
      args: [txId],
    });
  };

  const date = new Date(Number(timestamp) * 1000).toLocaleString();

  return (
    <div className="list-group-item">
      <div className="d-flex justify-content-between align-items-start">
        <div className="flex-grow-1">
          <h5 className="mb-1">
            TX #{txId.toString()}
            {executed && <span className="badge bg-success ms-2">Выполнена</span>}
          </h5>
          <p className="mb-1">{description}</p>
          <small className="text-muted">
            Создана: {date} |
            Подтверждений: {confirmations.toString()}/{required.toString()}
          </small>
          <div className="mt-2">
            <small className="text-muted d-block">Target: <code>{target}</code></small>
            {value > 0n && <small className="text-muted d-block">Value: {value.toString()} wei</small>}
          </div>
        </div>

        <div className="ms-3">
          {!executed && (
            <>
              {hasConfirmed ? (
                <button
                  className="btn btn-sm btn-warning"
                  onClick={revokeTx}
                  disabled={isPending || isConfirming}
                >
                  Отозвать
                </button>
              ) : (
                <button
                  className="btn btn-sm btn-primary"
                  onClick={confirmTx}
                  disabled={isPending || isConfirming}
                >
                  Подтвердить
                </button>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * Форма для создания новой транзакции
 */
function ProposeTransactionForm() {
  const [txType, setTxType] = useState<
    'convertEthToProtectedAsset' | 'setSafeAsset' | 'setThreshold' | 'confirmWithdrawal'
  >('convertEthToProtectedAsset');
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handlePropose = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.target as HTMLFormElement);

    let data: `0x${string}`;
    let description: string;

    if (txType === 'setSafeAsset') {
      const newSafeAsset = formData.get('newSafeAsset') as `0x${string}`;
      const newOracle = formData.get('newOracle') as `0x${string}`;

      data = encodeFunctionData({
        abi: WeValueContractConfig.abi,
        functionName: 'setSafeAsset',
        args: [newSafeAsset, newOracle],
      });
      description = `Установить safe asset  ${newSafeAsset}`;
    } else if (txType === 'convertEthToProtectedAsset') {
      const minAmountOut = BigInt(formData.get('minAmountOut') as string);

      data = encodeFunctionData({
        abi: WeValueContractConfig.abi,
        functionName: 'convertEthToProtectedAsset',
        args: [minAmountOut],
      });
      description = `Обменять eth на защищенный актив`;
    } else if (txType === 'setThreshold') {
      const threshold = BigInt(formData.get('threshold') as string);

      data = encodeFunctionData({
        abi: WeValueContractConfig.abi,
        functionName: 'setDepegThreshold',
        args: [threshold],
      });
      description = `Установить пороговую цены для эвакуации ${threshold}`;
    } else {
      const operationId = BigInt(formData.get('operationId') as string);

      data = encodeFunctionData({
        abi: WeValueContractConfig.abi,
        functionName: 'confirmWithdrawal',
        args: [operationId],
      });
      description = `Подтвердить вывод средств #${operationId}`;
    }

    writeContract({
      ...MultiSigContractConfig,
      functionName: 'proposeTransaction',
      args: [WeValueContractConfig.address, 0n, data, description],
    });
  };

  return (
    <div>
      <h3>Предложить новую транзакцию</h3>

      <div className="mb-3">
        <label className="form-label">Тип операции</label>
        <select
          className="form-select"
          value={txType}
          onChange={(e) => setTxType(e.target.value as any)}
        >
          <option value="convertEthToProtectedAsset">Обмен eth фонда</option>
          <option value="setSafeAsset">Изменить безопасный актив</option>
          <option value="setThreshold">Изменить порог депега</option>
          <option value="confirmWithdrawal">Подтвердить вывод средств</option>
        </select>
      </div>

      <form onSubmit={handlePropose}>
        {txType === 'setSafeAsset' && (
          <>
            <div className="mb-3">
              <label className="form-label">Адрес Safe Asset</label>
              <input type="text" name="newSafeAsset" className="form-control" placeholder="0x..." required />
            </div>
            <div className="mb-3">
              <label className="form-label">Адрес Oracle Safe Asset</label>
              <input type="text" name="newOracle" className="form-control" placeholder="0x..." required />
            </div>
          </>
        )}

        {txType === 'convertEthToProtectedAsset' && (
          <div className="mb-3">
            <label className="form-label">Минимальная сумма на выходе обмена</label>
            <input type="number" name="minAmountOut" className="form-control" required />
          </div>
        )}

        {txType === 'setThreshold' && (
          <div className="mb-3">
            <label className="form-label">Пороговая цена(8 decimals, например, 95000000 = $0.95)</label>
            <input type="number" name="threshold" className="form-control" required />
          </div>
        )}

        {txType === 'confirmWithdrawal' && (
          <div className="mb-3">
            <label className="form-label">ID операции вывода для подтверждения</label>
            <input type="number" name="operationId" className="form-control" required />
          </div>
        )}

        <button type="submit" className="btn btn-primary" disabled={isPending || isConfirming}>
          {isPending ? 'Отправка...' : isConfirming ? 'Ожидание...' : 'Предложить транзакцию'}
        </button>
      </form>

      {hash && (
        <div className="alert alert-info mt-3">
          <strong>Hash:</strong> <code>{hash}</code>
        </div>
      )}
      {isSuccess && (
        <div className="alert alert-success mt-3">
          Транзакция предложена! Ожидайте подтверждения других владельцев.
        </div>
      )}
      {error && (
        <div className="alert alert-danger mt-3">
          Ошибка: {error.message}
        </div>
      )}
    </div>
  );
}

/**
 * Секция для предложения обновления реализации (UUPS) как onlyOwner-транзакции через MultiSig
 */
function UpgradeProposalSection() {
  const [newImplementation, setNewImplementation] = useState('');
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // ABI для функции upgradeTo
  const upgradeToAbi = [
    {
      name: 'upgradeTo',
      type: 'function',
      inputs: [{ name: 'newImplementation', type: 'address' }],
      outputs: [],
      stateMutability: 'nonpayable',
    },
  ] as const;

  const handleProposeUpgrade = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    if (!newImplementation) return;

    // Кодируем данные для вызова upgradeTo на прокси
    const encodedData = encodeFunctionData({
      abi: upgradeToAbi,
      functionName: 'upgradeTo',
      args: [newImplementation as `0x${string}`],
    });

    // Предлагаем транзакцию через MultiSig
    writeContract({
      ...MultiSigContractConfig,
      functionName: 'proposeTransaction',
      args: [
        WeValueContractConfig.address,
        0n,
        encodedData,
        `Обновление реализации WeValue до ${newImplementation}`,
      ],
    });
  };

  return (
    <div>
      <h4>Предложение обновления реализации</h4>
      <p className="text-muted small">
        Предложите обновление реализации контракта WeValue. Это потребует подтверждения от других владельцев через
        MultiSig.
      </p>

      <div className="alert alert-warning">
        <strong>Внимание:</strong> Обновление контракта — ответственная операция. Убедитесь, что новый контракт
        протестирован и имеет совместимый интерфейс.
      </div>

      <form onSubmit={handleProposeUpgrade}>
        <div className="mb-3">
          <label className="form-label">Адрес новой реализации</label>
          <input
            type="text"
            className="form-control"
            value={newImplementation}
            onChange={(e) => setNewImplementation(e.target.value)}
            placeholder="0x..."
            required
          />
        </div>

        <button type="submit" className="btn btn-danger" disabled={isPending || isConfirming}>
          {isPending ? 'Отправка...' : isConfirming ? 'Подтверждение...' : 'Предложить обновление'}
        </button>
      </form>

      {hash && (
        <div className="alert alert-info mt-3">
          <strong>Hash:</strong> <code>{hash}</code>
        </div>
      )}
      {isSuccess && (
        <div className="alert alert-success mt-3">
          Предложение обновления создано! Ожидайте подтверждения от других владельцев.
        </div>
      )}
      {error && (
        <div className="alert alert-danger mt-3">
          Ошибка: {error.message}
        </div>
      )}
    </div>
  );
}

/**
 * Информация о Safe Asset
 */
function SafeAssetInfo() {
  const { data } = useReadContract({
    ...WeValueContractConfig,
    functionName: 'safeAsset',
  });

  const safeAssetAddress = data as `0x${string}` | undefined;

  if (!safeAssetAddress || safeAssetAddress === '0x0000000000000000000000000000000000000000') {
    return (
      <div className="alert alert-warning">
        <strong>Safe Asset:</strong> Не установлен
      </div>
    );
  }

  return <SafeAssetDetails address={safeAssetAddress} />;
}

function SafeAssetDetails({ address }: { address: `0x${string}` }) {
  const { data } = useReadContract({
    address: address,
    abi: WeValueContractConfig.abi,
    functionName: 'name',
  });

  const { data: symbol } = useReadContract({
    address: address,
    abi: WeValueContractConfig.abi,
    functionName: 'symbol',
  });

  return (
    <div className="alert alert-info">
      <strong>Safe Asset (для эвакуации):</strong> {data as string} ({symbol as string})
      <br />
      <small className="text-muted">
        <code>{address}</code>
      </small>
    </div>
  );
}
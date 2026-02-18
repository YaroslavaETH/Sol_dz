import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { WeValueContractConfig, MultiSigContractConfig } from '../contracts';
import { parseUnits } from 'viem';

/** Минимальный ERC20 ABI для чтения decimals, name, symbol */
const erc20MetaAbi = [
  { name: 'decimals', type: 'function', inputs: [], outputs: [{ type: 'uint8' }], stateMutability: 'view' },
  { name: 'name', type: 'function', inputs: [], outputs: [{ type: 'string' }], stateMutability: 'view' },
  { name: 'symbol', type: 'function', inputs: [], outputs: [{ type: 'string' }], stateMutability: 'view' },
] as const;

/**
 * Компонент админ-панели для владельцев
 * Позволяет напрямую выполнять функции с модификатором onlyMultiSigOwner
 */
export function AdminPanel() {
  const { address } = useAccount();
  const [activeTab, setActiveTab] = useState<'direct' | 'withdrawal'>('direct');

  // Проверяем является ли пользователь владельцем
  const { data: isOwner } = useReadContract({
    ...MultiSigContractConfig,
    functionName: 'isOwner',
    args: [address!],
    query: { enabled: !!address },
  });

  if (!isOwner) {
    return null;
  }

  return (
    <div className="card mt-4">
      <div className="card-body">
        <h2 className="card-title">⚙️ Админ-панель</h2>
        <p className="text-muted">Функции для владельцев фонда</p>

        <div className="nav nav-tabs" id="adminTab" role="tablist">
          <button
            className={`nav-link ${activeTab === 'direct' ? 'active' : ''}`}
            tabIndex={0}
            role="tab"
            type="button"
            onClick={() => setActiveTab('direct')}
          >
            Эвакуация активов
          </button>
          <button
            className={`nav-link ${activeTab === 'withdrawal' ? 'active' : ''}`}
            tabIndex={1}
            role="tab"
            type="button"
            onClick={() => setActiveTab('withdrawal')}
          >
            Вывод средств
          </button>
        </div>

        <div className="tab-content mt-3" id="adminTabContent">
          <div
            className={`tab-pane fade ${activeTab === 'direct' ? 'show active' : ''}`}
            role="tabpanel"
            tabIndex={0}
          >
            <DirectExecutionSection />
          </div>
          <div
            className={`tab-pane fade ${activeTab === 'withdrawal' ? 'show active' : ''}`}
            role="tabpanel"
            tabIndex={1}
          >
            <WithdrawalSection />
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * Секция для прямого выполнения функции эвакуации (onlyMultiSigOwner)
 */
function DirectExecutionSection() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data: safeAssetAddress } = useReadContract({
    ...WeValueContractConfig,
    functionName: 'safeAsset',
  });

  const { data: protectedAssetAddress } = useReadContract({
    ...WeValueContractConfig,
    functionName: 'protectedAsset',
  });

  const safeAddr = safeAssetAddress as `0x${string}` | undefined;
  const protectedAddr = protectedAssetAddress as `0x${string}` | undefined;

  // ========== Safe Asset (КУДА эвакуируемся) ==========
  const { data: safeDecimals } = useReadContract({
    address: safeAddr!,
    abi: erc20MetaAbi,
    functionName: 'decimals',
    query: { enabled: !!safeAddr && safeAddr !== '0x0000000000000000000000000000000000000000' },
  });

  const { data: safeName } = useReadContract({
    address: safeAddr!,
    abi: erc20MetaAbi,
    functionName: 'name',
    query: { enabled: !!safeAddr && safeAddr !== '0x0000000000000000000000000000000000000000' },
  });

  const { data: safeSymbol } = useReadContract({
    address: safeAddr!,
    abi: erc20MetaAbi,
    functionName: 'symbol',
    query: { enabled: !!safeAddr && safeAddr !== '0x0000000000000000000000000000000000000000' },
  });

  // ========== Protected Asset (ОТКУДА эвакуируемся) ==========
  const { data: protectedDecimals } = useReadContract({
    address: protectedAddr!,
    abi: erc20MetaAbi,
    functionName: 'decimals',
    query: { enabled: !!protectedAddr && protectedAddr !== '0x0000000000000000000000000000000000000000' },
  });

  const { data: protectedName } = useReadContract({
    address: protectedAddr!,
    abi: erc20MetaAbi,
    functionName: 'name',
    query: { enabled: !!protectedAddr && protectedAddr !== '0x0000000000000000000000000000000000000000' },
  });

  const { data: protectedSymbol } = useReadContract({
    address: protectedAddr!,
    abi: erc20MetaAbi,
    functionName: 'symbol',
    query: { enabled: !!protectedAddr && protectedAddr !== '0x0000000000000000000000000000000000000000' },
  });

  const safeD = safeDecimals as number | undefined;
  const protectedD = protectedDecimals as number | undefined;

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    if (!safeD || !protectedD) {
      alert('Decimals еще не загружены');
      return;
    }

    const formData = new FormData(e.target as HTMLFormElement);

    const evacuationMinReturn = parseUnits(
      (formData.get('evacuationMinReturn') as string) || '0',
      safeD
    );
    const flashLoanAmount = parseUnits(
      (formData.get('flashLoanAmount') as string) || '0',
      safeD
    );
    const simpleSwapMinReturn = parseUnits(
      (formData.get('simpleSwapMinReturn') as string) || '0',
      safeD
    );

    const manipulationMinReturn = parseUnits(
      (formData.get('manipulationMinReturn') as string) || '0',
      protectedD
    );

    writeContract({
      ...WeValueContractConfig,
      functionName: 'evacuateIfDepegged',
      args: [evacuationMinReturn, flashLoanAmount, manipulationMinReturn, simpleSwapMinReturn],
    });
  };

  return (
    <div>
      {/* Информационный блок */}
      <div className="alert alert-info mb-3">
        <h6 className="alert-heading">📊 Информация об эвакуации</h6>
        <div className="row">
          <div className="col-md-6">
            <p className="mb-1">
              <strong>Откуда эвакуируем:</strong>
              <br />
              {protectedName as string} ({protectedSymbol as string})
              <br />
            </p>
          </div>
          <div className="col-md-6">
            <p className="mb-1">
              <strong>Куда эвакуируем:</strong>
              <br />
              {safeName as string} ({safeSymbol as string})
              <br />
            </p>
          </div>
        </div>
      </div>

      <div className="alert alert-warning">
      Функция выполняется напрямую. Каждый владелец мультисиг-кошелька может вызвать её без подтверждения других владельцев.
      </div>

      <form onSubmit={handleSubmit}>
        <div className="mb-3">
          <label className="form-label">
            Минимальная сумма при эвакуации (в {safeSymbol as string})
          </label>
          <input
            type="number"
            step="0.000001"
            name="evacuationMinReturn"
            className="form-control"
            placeholder="0"
            required
            disabled={!safeD}
          />
          <small className="text-muted">
            Минимум {safeSymbol as string}, который должны получить после основного свопа
          </small>
        </div>

        <div className="mb-3">
          <label className="form-label">
            Сумма Flash Loan (в {safeSymbol as string}) — 0 = без манипуляции
          </label>
          <input
            type="number"
            step="0.000001"
            name="flashLoanAmount"
            className="form-control"
            placeholder="0"
            disabled={!safeD}
          />
          <small className="text-muted">
            Сколько {safeSymbol as string} занять в Aave для манипуляции ценой
          </small>
        </div>

        <div className="mb-3">
          <label className="form-label">
            Минимальная сумма при манипуляции (в {protectedSymbol as string}) ⚠️
          </label>
          <input
            type="number"
            step="0.000001"
            name="manipulationMinReturn"
            className="form-control"
            placeholder="0"
            disabled={!protectedD}
          />
          <small className="text-muted">
            Минимум {protectedSymbol as string}, который получим при свопе {safeSymbol as string} → {protectedSymbol as string}
          </small>
        </div>

        <div className="mb-3">
          <label className="form-label">
            Сумма при простом обмене (в {safeSymbol as string})
          </label>
          <input
            type="number"
            step="0.000001"
            name="simpleSwapMinReturn"
            className="form-control"
            placeholder="0"
            disabled={!safeD}
          />
          <small className="text-muted">
            Для проверки прибыльности (сколько получили бы без манипуляции)
          </small>
        </div>

        <button
          type="submit"
          className="btn btn-danger"
          disabled={isPending || isConfirming || !safeD || !protectedD}
        >
          {isPending ? 'Отправка...' : isConfirming ? 'Подтверждение...' : '🚨 Эвакуировать средства'}
        </button>
      </form>

      {hash && (
        <div className="alert alert-info mt-3">
          <strong>Hash:</strong> <code>{hash}</code>
        </div>
      )}
      {isSuccess && (
        <div className="alert alert-success mt-3">
          ✅ Эвакуация выполнена!
        </div>
      )}
      {error && (
        <div className="alert alert-danger mt-3">
          <strong>Ошибка:</strong> {error.message}
        </div>
      )}
    </div>
  );
}

/**
 * Секция для вывода средств
 */
function WithdrawalSection() {
  const [operationType, setOperationType] = useState<'withdraw' | 'addCheck'>('withdraw');
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data: protectedAssetAddress } = useReadContract({
    ...WeValueContractConfig,
    functionName: 'protectedAsset',
  });

  const tokenAddress = protectedAssetAddress as `0x${string}` | undefined;

  const { data: tokenDecimals } = useReadContract({
    address: tokenAddress!,
    abi: erc20MetaAbi,
    functionName: 'decimals',
    query: { enabled: !!tokenAddress && tokenAddress !== '0x0000000000000000000000000000000000000000' },
  });

  const { data: tokenName } = useReadContract({
    address: tokenAddress!,
    abi: erc20MetaAbi,
    functionName: 'name',
    query: { enabled: !!tokenAddress && tokenAddress !== '0x0000000000000000000000000000000000000000' },
  });

  const { data: tokenSymbol } = useReadContract({
    address: tokenAddress!,
    abi: erc20MetaAbi,
    functionName: 'symbol',
    query: { enabled: !!tokenAddress && tokenAddress !== '0x0000000000000000000000000000000000000000' },
  });

  const decimals = tokenDecimals as number | undefined;
  const tokenLabel = (tokenName as string) || 'protected asset';
  const symbol = (tokenSymbol as string) || '???';

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.target as HTMLFormElement);

    if (operationType === 'withdraw') {
      if (!decimals) {
        alert('Decimals не загружены');
        return;
      }

      const recipient = formData.get('recipient') as `0x${string}`;
      const amountRaw = formData.get('amount') as string;
      const amount = parseUnits(amountRaw || '0', decimals);
      const offchain = formData.get('offchain') === 'on';
      const description = formData.get('description') as string;

      writeContract({
        ...WeValueContractConfig,
        functionName: 'withdrawalProtectedAsset',
        args: [recipient, amount, offchain, description],
      });
    } else if (operationType === 'addCheck') {
      const operationId = BigInt(formData.get('operationId') as string);
      const date = BigInt(formData.get('date') as string);
      const fn = BigInt(formData.get('fn') as string);
      const fd = Number(formData.get('fd') as string);
      const fpd = Number(formData.get('fpd') as string);

      writeContract({
        ...WeValueContractConfig,
        functionName: 'addCheckToWithdrawal',
        args: [operationId, date, fn, fd, fpd],
      });
    }
  };

  return (
    <div>
      <h4>Вывод средств</h4>
      <p className="text-muted small">
        Управление выводом средств из фонда (в {symbol}).
      </p>

      <div className="mb-3">
        <label className="form-label">Тип операции</label>
        <select
          className="form-select"
          value={operationType}
          onChange={(e) => setOperationType(e.target.value as any)}
        >
          <option value="withdraw">Вывод средств</option>
          <option value="addCheck">Добавить чек</option>
        </select>
      </div>

      <form onSubmit={handleSubmit}>
        {operationType === 'withdraw' && (
          <>
            <div className="mb-3">
              <label className="form-label">Получатель</label>
              <input
                type="text"
                name="recipient"
                className="form-control"
                placeholder="0x..."
                required
              />
            </div>
            <div className="mb-3">
              <label className="form-label">
                Сумма (в {tokenLabel})
              </label>
              <input
                type="number"
                step="0.000001"
                name="amount"
                className="form-control"
                placeholder="100"
                required
                disabled={decimals == null}
              />
            </div>
            <div className="mb-3">
              <label className="form-label">Описание</label>
              <input
                type="text"
                name="description"
                className="form-control"
                placeholder="На что выводятся средства"
                required
              />
            </div>
            <div className="mb-3 form-check">
              <input
                type="checkbox"
                name="offchain"
                className="form-check-input"
                id="offchainCheck"
              />
              <label className="form-check-label" htmlFor="offchainCheck">
                Оффчейн (требует подтверждения чеками)
              </label>
            </div>
          </>
        )}

        {operationType === 'addCheck' && (
          <>
            <div className="mb-3">
              <label className="form-label">ID операции</label>
              <input type="number" name="operationId" className="form-control" required />
            </div>
            <div className="mb-3">
              <label className="form-label">Дата (YYYYMMDDHHSS)</label>
              <input type="number" name="date" className="form-control" required />
              <small className="text-muted">Пример: 202612181430 = 18.12.2026 14:30</small>
            </div>
            <div className="mb-3">
              <label className="form-label">ФН</label>
              <input type="number" name="fn" className="form-control" required />
            </div>
            <div className="mb-3">
              <label className="form-label">ФД</label>
              <input type="number" name="fd" className="form-control" required />
            </div>
            <div className="mb-3">
              <label className="form-label">ФПД</label>
              <input type="number" name="fpd" className="form-control" required />
            </div>
          </>
        )}

        <button
          type="submit"
          className="btn btn-primary"
          disabled={isPending || isConfirming || (operationType === 'withdraw' && decimals == null)}
        >
          {isPending ? 'Отправка...' : isConfirming ? 'Подтверждение...' : 'Выполнить'}
        </button>
      </form>

      {hash && (
        <div className="alert alert-info mt-3">
          <strong>Hash:</strong> <code>{hash}</code>
        </div>
      )}
      {isSuccess && (
        <div className="alert alert-success mt-3">
          Операция выполнена!
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

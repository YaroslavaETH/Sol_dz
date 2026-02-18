import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { WeValueContractConfig, MultiSigContractConfig } from '../contracts';
import { parseEther } from 'viem';

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

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.target as HTMLFormElement);

    const evacuationMinReturn = parseEther((formData.get('evacuationMinReturn') as string) || '0');
    const flashLoanAmount = parseEther((formData.get('flashLoanAmount') as string) || '0');
    const manipulationMinReturn = parseEther((formData.get('manipulationMinReturn') as string) || '0');
    const simpleSwapMinReturn = parseEther((formData.get('simpleSwapMinReturn') as string) || '0');

    writeContract({
      ...WeValueContractConfig,
      functionName: 'evacuateIfDepegged',
      args: [evacuationMinReturn, flashLoanAmount, manipulationMinReturn, simpleSwapMinReturn],
    });
  };

  return (
    <div>
      <p className="text-muted small">
        Функция выполняется напрямую. Каждый владелец мультисиг-кошелька может вызвать её без подтверждения других владельцев.
      </p>

      <form onSubmit={handleSubmit}>
        <div className="mb-3">
          <label className="form-label">Минимальная сумма при эвакуации</label>
          <input
            type="number"
            step="0.000001"
            name="evacuationMinReturn"
            className="form-control"
            placeholder="0"
            required
          />
        </div>
        <div className="mb-3">
          <label className="form-label">Сумма Flash Loan (0 = без манипуляции)</label>
          <input
            type="number"
            step="0.000001"
            name="flashLoanAmount"
            className="form-control"
            placeholder="0"
          />
        </div>
        <div className="mb-3">
          <label className="form-label">Минимальная сумма при манипуляции</label>
          <input
            type="number"
            step="0.000001"
            name="manipulationMinReturn"
            className="form-control"
            placeholder="0"
          />
        </div>
        <div className="mb-3">
          <label className="form-label">Сумма при простом обмене (для проверки прибыльности)</label>
          <input
            type="number"
            step="0.000001"
            name="simpleSwapMinReturn"
            className="form-control"
            placeholder="0"
          />
        </div>

        <button type="submit" className="btn btn-warning" disabled={isPending || isConfirming}>
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
          Операция выполнена успешно!
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
 * Секция для вывода средств
 */
function WithdrawalSection() {
  const [operationType, setOperationType] = useState<'withdraw' | 'addCheck'>('withdraw');
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.target as HTMLFormElement);

    if (operationType === 'withdraw') {
      const recipient = formData.get('recipient') as `0x${string}`;
      const amount = parseEther(formData.get('amount') as string);
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
        Управление выводом средств из фонда.
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
              <label className="form-label">Сумма (в USDC, 6 decimals)</label>
              <input
                type="number"
                step="0.01"
                name="amount"
                className="form-control"
                placeholder="100"
                required
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
              <input
                type="number"
                name="operationId"
                className="form-control"
                placeholder="1"
                required
              />
            </div>
            <div className="mb-3">
              <label className="form-label">Дата (YYYYMMDDHHSS)</label>
              <input
                type="number"
                name="date"
                className="form-control"
                placeholder="202412311200"
                required
              />
            </div>
            <div className="mb-3">
              <label className="form-label">ФН (Фискальный накопитель)</label>
              <input
                type="number"
                name="fn"
                className="form-control"
                placeholder="1234567890"
                required
              />
            </div>
            <div className="mb-3">
              <label className="form-label">ФД (Порядковый номер)</label>
              <input
                type="number"
                name="fd"
                className="form-control"
                placeholder="1"
                required
              />
            </div>
            <div className="mb-3">
              <label className="form-label">ФПД (Фискальный признак)</label>
              <input
                type="number"
                name="fpd"
                className="form-control"
                placeholder="1234567890"
                required
              />
            </div>
          </>
        )}

        <button type="submit" className="btn btn-primary" disabled={isPending || isConfirming}>
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
          Операция выполнена успешно!
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

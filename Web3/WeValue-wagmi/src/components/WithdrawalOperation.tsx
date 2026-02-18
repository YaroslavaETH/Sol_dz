import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useReadContract, useReadContracts } from 'wagmi';
import { WeValueContractConfig } from '../contracts';
import { formatUnits } from 'viem';
import { useState } from 'react';

const GRAPH_URL = 'https://api.studio.thegraph.com/query/1724651/we-value/version/latest';

type WithdrawalAsset = {
  token: string;
  amount: string;
  recipient: string;
  offchain: boolean;
  operationId: string;
  transactionHash: string;
  decription: string;
};

type AddCheckToWithdrawal = {
  id: string;
  operationId: string;
  date: string;
  fn: string;
  fd: string;
  fpd: string;
};

export function WithdrawalOperation() {
  const [expandedChecks, setExpandedChecks] = useState<Record<string, AddCheckToWithdrawal[] | null>>({});
  const [showList, setShowList] = useState(false);

  const { data: unconfirmedCount } = useReadContract({
    ...WeValueContractConfig,
    functionName: 'getUnconfirmedOperationsCount',
  });

  const { data: withdrawalCount } = useReadContract({
    ...WeValueContractConfig,
    functionName: 'withdrawalCount',
  });

  const total = Number(withdrawalCount ?? 0);
  const unconfirmed = Number(unconfirmedCount ?? 0);
  const count = unconfirmed;

  const contracts = useMemo(
    () =>
      count > 0
        ? Array.from({ length: count }, (_, i) => ({
            ...WeValueContractConfig,
            functionName: 'unconfirmedOperations' as const,
            args: [BigInt(i)] as const,
          }))
        : [],
    [count]
  );

  const { data: unconfirmedData } = useReadContracts({
    contracts: contracts as readonly object[],
    query: { enabled: count > 0 && contracts.length > 0 },
  });

  const unconfirmedIds = useMemo(() => {
    if (!unconfirmedData) return [] as string[];
    return unconfirmedData
      .map((r) => (r.result as bigint | undefined)?.toString())
      .filter((id): id is string => id != null);
  }, [unconfirmedData]);

  const unconfirmedSet = useMemo(() => new Set(unconfirmedIds), [unconfirmedIds]);

  const withdrawalsQuery = useQuery({
    queryKey: ['withdrawalProtectedAssets'],
    queryFn: async () => {
      const response = await fetch(GRAPH_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: `
            {
              withdrawalProtectedAssets(orderBy: operationId, orderDirection: desc) {
                token
                amount
                recipient
                offchain
                operationId
                transactionHash
                decription
              }
            }
          `,
        }),
      });

      const result = await response.json();
      if (result.errors) throw new Error(result.errors[0]?.message ?? 'GraphQL error');
      return (result.data?.withdrawalProtectedAssets ?? []) as WithdrawalAsset[];
    },
    staleTime: 60000,
  });

  if (withdrawalsQuery.isLoading) return <div className="alert alert-info">Загрузка операций вывода...</div>;
  if (withdrawalsQuery.error)
    return (
      <div className="alert alert-danger">
        Ошибка загрузки данных: {(withdrawalsQuery.error as Error).message}
      </div>
    );

  const withdrawals = withdrawalsQuery.data ?? [];
  const unconfirmedPct = total > 0 ? ((unconfirmed / total) * 100).toFixed(1) : '0';

  return (
    <div className="mb-3">
      <div className="alert alert-info mb-3">
        <strong>Общее количество транзакций оказанной помощи:</strong> {total}
        <br />
        <strong>Из них не подтверждено:</strong> {unconfirmed} ({unconfirmedPct}%)
      </div>
      {withdrawals.length > 0 && (
        <>
          <button
            type="button"
            className="btn btn-outline-secondary btn-sm mb-2"
            onClick={() => setShowList((v) => !v)}
          >
            {showList ? 'Скрыть список операций' : 'Показать список операций'}
          </button>
          {showList && (
            <div className="list-group">
              {withdrawals.map((op) => (
                <WithdrawalItem
                  key={`${op.operationId}-${op.transactionHash ?? ''}`}
                  op={op}
                  isConfirmed={!unconfirmedSet.has(String(op.operationId))}
                  expandedChecks={expandedChecks}
                  onToggleChecks={setExpandedChecks}
                />
              ))}
            </div>
          )}
        </>
      )}
      {withdrawals.length === 0 && <div className="alert alert-secondary">Нет операций вывода</div>}
    </div>
  );
}

function WithdrawalItem({
  op,
  isConfirmed,
  expandedChecks,
  onToggleChecks,
}: {
  op: WithdrawalAsset;
  isConfirmed: boolean;
  expandedChecks: Record<string, AddCheckToWithdrawal[] | null>;
  onToggleChecks: React.Dispatch<React.SetStateAction<Record<string, AddCheckToWithdrawal[] | null>>>;
}) {
  const [isLoadingChecks, setIsLoadingChecks] = useState(false);

  const loadChecks = async () => {
    const id = String(op.operationId);
    if (expandedChecks[id] !== undefined) {
      onToggleChecks((prev) => {
        const next = { ...prev };
        delete next[id];
        return next;
      });
      return;
    }

    setIsLoadingChecks(true);
    try {
      const response = await fetch(GRAPH_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: `
            {
              addCheckToWithdrawals(where: {operationId: "${op.operationId}"}) {
                id
                operationId
                date
                fn
                fd
                fpd
              }
            }
          `,
        }),
      });

      const result = await response.json();
      const list = (result.data?.addCheckToWithdrawals ?? []) as AddCheckToWithdrawal[];
      onToggleChecks((prev) => ({ ...prev, [id]: list }));
    } catch {
      onToggleChecks((prev) => ({ ...prev, [id]: [] }));
    } finally {
      setIsLoadingChecks(false);
    }
  };

  const checks = expandedChecks[String(op.operationId)];

  const amountDisplay = (() => {
    try {
      const amount = BigInt(op.amount);
      if (amount < 1e12) return op.amount;
      return formatUnits(amount, 6);
    } catch {
      return op.amount;
    }
  })();

  return (
    <div className="list-group-item">
      <div className="d-flex justify-content-between align-items-start flex-wrap gap-2">
        <div className="flex-grow-1">
          <div className="d-flex align-items-center gap-2 mb-1">
            <strong>#{op.operationId}</strong>
            {isConfirmed ? (
              <span className="badge bg-success">Подтверждена</span>
            ) : (
              <span className="badge bg-warning text-dark">Не подтверждена</span>
            )}
            {op.offchain && <span className="badge bg-info">Оффчейн</span>}
          </div>
          <div className="small text-muted">
            <span>Сумма: {amountDisplay}</span>
            <span className="ms-2">Токен: {op.token}</span>
            <span className="ms-2">Получатель: {op.recipient}</span>
          </div>
          {op.decription && <div className="small mt-1">{op.decription}</div>}
          {op.transactionHash && (
            <a
              href={`https://sepolia.etherscan.io/tx/${op.transactionHash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="small"
            >
              Транзакция
            </a>
          )}
        </div>
        {op.offchain && (
          <button
            type="button"
            className="btn btn-sm btn-outline-secondary"
            onClick={loadChecks}
            disabled={isLoadingChecks}
          >
            {isLoadingChecks ? 'Загрузка...' : checks === undefined ? 'Показать чеки' : 'Скрыть чеки'}
          </button>
        )}
      </div>
      {op.offchain && checks != null && checks.length > 0 && (
        <div className="mt-3 pt-2 border-top">
          <strong className="small">Чеки:</strong>
          <ul className="list-unstyled mb-0 mt-1 small">
            {checks.map((c) => (
              <li key={c.id}>
                ФН: {c.fn}, ФД: {c.fd}, ФПД: {c.fpd}, Дата: {c.date}
              </li>
            ))}
          </ul>
        </div>
      )}
      {op.offchain && checks != null && checks.length === 0 && (
        <div className="mt-3 pt-2 border-top small text-muted">Чеков нет</div>
      )}
    </div>
  );
}

export default WithdrawalOperation;

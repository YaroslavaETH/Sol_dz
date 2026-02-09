import { useConnection } from 'wagmi';

export function ConnectionStatus() {
  const connection = useConnection();

  return (
    <div className="mt-3">
      <ul className="list-group list-group-flush">
        <li className="list-group-item">
          <strong>Статус:</strong> <span className="badge bg-primary">{connection.status}</span>
        </li>
        <li className="list-group-item">
          <strong>Адреса:</strong> {JSON.stringify(connection.addresses)}
        </li>
        <li className="list-group-item">
          <strong>Текущий адрес:</strong> <code>{JSON.stringify(connection.address)}</code>
        </li>
        <li className="list-group-item">
          <strong>Chain ID:</strong> <span className="badge bg-secondary">{connection.chainId}</span>
        </li>
      </ul>
    </div>
  );
}

import {  useConnection } from 'wagmi'
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { ContractInfo, UserTokenBalance, CurrentPriceGaz, BalanceWallet, BalanceContract } from  './read-contract.tsx';
import {DonationForm} from './write-contract.tsx';
import DonationChart from './DonationChart.tsx';


function App() {
  const connection = useConnection()
  // const { disconnect } = useDisconnect()

  return (
    <>
      <div>
        <h2>Connection</h2>
        <ConnectButton showBalance={true}/>
        <div>
          Статус: {connection.status}
          <br />
          Адреса: {JSON.stringify(connection.addresses)}
          <br />
          Текущий адрес: {JSON.stringify(connection.address)}
          <br />
          chainId: {connection.chainId}
          <br />
          <CurrentPriceGaz chain={connection.chain}/>
          <br />
          <BalanceWallet address={connection.address} />
          {connection.isConnected && (
            <div>
              <h2>Помочь фонду</h2>
              <DonationForm />
            </div>
          )}
        </div>
      </div>
      <hr />
      <div>
        <h2>Информация по благотворительному фонду</h2>
        <ContractInfo />
        <br />
        <BalanceContract />
        {connection.isConnected && <UserTokenBalance address={connection.address} />}
      </div>
      <hr />
      <div>
        <h2>Статистика помощи фонду</h2>
        <DonationChart />
      </div>
    </>
  )
}

export default App

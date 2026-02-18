import { mainnet, sepolia } from 'wagmi/chains'
import '@rainbow-me/rainbowkit/styles.css';
import {
  getDefaultConfig,
  RainbowKitProvider,
} from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';

const sepoliaRpcUrl = import.meta.env.VITE_SEPOLIA_RPC_URL;

export const config = getDefaultConfig({
  appName: 'WeValue App',
  projectId: 'ae13ca8d63ff115b1f9ce2311e233ba7',
  chains: [sepolia],
  transports: {
    [sepolia.id]: http(sepoliaRpcUrl),
  },
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}

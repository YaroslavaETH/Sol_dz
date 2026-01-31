import { mainnet, sepolia } from 'wagmi/chains'
import '@rainbow-me/rainbowkit/styles.css';
import {
  getDefaultConfig,
  RainbowKitProvider,
} from '@rainbow-me/rainbowkit';
import { WagmiProvider } from 'wagmi';
import {
  QueryClientProvider,
  QueryClient,
} from "@tanstack/react-query";

export const config = getDefaultConfig({
  appName: 'WeValue App',
  projectId: 'ae13ca8d63ff115b1f9ce2311e233ba7',
  chains: [mainnet, sepolia]
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}

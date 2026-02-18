import abiWeValue from './abi/WeValue_v3.sol/WeValue.json';
import abiMultiSig from './abi/MultiSigWallet.sol/MultiSigWallet.json';

// WeValue Contract
export const WeValueContractConfig = {
  address: '0x0A8F04D29977f58FC452c69f115fd598C4B0bf6d' as `0x${string}`,
  abi: abiWeValue.abi,
} as const;

// MultiSig Wallet Contract
export const MultiSigContractConfig = {
  address: '0x305E96cF0257f8C439FF80d0D4C9AFBc276f0ad1' as `0x${string}`,
  abi: abiMultiSig.abi,
} as const;

// Helper functions for encoding
export const encodeEvacuateIfDepegged = (
  evacuationMinReturn: bigint,
  flashLoanAmount: bigint,
  manipulationMinReturn: bigint,
  simpleSwapMinReturn: bigint
) => {
  return encodeFunctionData({
    abi: WeValueContractConfig.abi,
    functionName: 'evacuateIfDepegged',
    args: [evacuationMinReturn, flashLoanAmount, manipulationMinReturn, simpleSwapMinReturn],
  });
};

export const encodeSetSafeAsset = (
  newSafeAsset: `0x${string}`,
  newSafeAssetOracle: `0x${string}`
) => {
  return encodeFunctionData({
    abi: WeValueContractConfig.abi,
    functionName: 'setSafeAsset',
    args: [newSafeAsset, newSafeAssetOracle],
  });
};

export const encodeSetDepegThreshold = (newThreshold: bigint) => {
  return encodeFunctionData({
    abi: WeValueContractConfig.abi,
    functionName: 'setDepegThreshold',
    args: [newThreshold],
  });
};

// Import this helper
import { encodeFunctionData } from 'viem';

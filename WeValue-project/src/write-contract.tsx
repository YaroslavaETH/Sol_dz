import * as React from 'react'
import { 
  type BaseError, 
  useWriteContract, 
  useWaitForTransactionReceipt 
} from 'wagmi'
import { WeValueContractConfig } from './contracts'
import { parseEther } from 'viem'
 
export function DonationForm() {
  const { data: hash, error, isPending, writeContract } = useWriteContract()

  async function submit(e: React.FormEvent<HTMLFormElement>) { 
    e.preventDefault() 
    const formData = new FormData(e.target as HTMLFormElement) 
    const donationValue = formData.get('Donation') as string 
    writeContract({
      address: WeValueContractConfig.address,
      abi:WeValueContractConfig.abi,
      functionName: 'donation',
      args: [],
      value: parseEther(donationValue),
    })
  } 

  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({ 
      hash, 
    })

  return (
    <form onSubmit={submit}>
      <input name="Donation" placeholder="0.05" required />
      <button disabled={isPending} type="submit">
        {isPending ? 'Подтвердите в кошельке...' : 'Отправить'}
      </button>
      {hash && <div>Transaction Hash: {hash}</div>}
      {isConfirming && <div>Ожидание подтверждения...</div>}
      {isConfirmed && <div>Транзакция подтверждена. Спасибо!</div>}
      {error && (
        <div>Ошибка: {(error as BaseError).shortMessage || error.message}</div>
      )}
    </form>
  )
}
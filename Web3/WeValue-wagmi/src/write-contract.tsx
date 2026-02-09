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
    <form onSubmit={submit} className="row g-3">
      <div className="col-md-8">
        <input 
          name="Donation" 
          placeholder="0.05" 
          required 
          className="form-control"
          type="number"
          step="0.001"
          min="0"
        />
      </div>
      <div className="col-md-4">
        <button 
          disabled={isPending} 
          type="submit"
          className="btn btn-primary w-100"
        >
          {isPending ? 'Подтвердите в кошельке...' : 'Отправить'}
        </button>
      </div>
      {hash && (
        <div className="col-12">
          <div className="alert alert-info">
            <strong>Transaction Hash:</strong> <code>{hash}</code>
          </div>
        </div>
      )}
      {isConfirming && (
        <div className="col-12">
          <div className="alert alert-warning">Ожидание подтверждения...</div>
        </div>
      )}
      {isConfirmed && (
        <div className="col-12">
          <div className="alert alert-success">Транзакция подтверждена. Спасибо!</div>
        </div>
      )}
      {error && (
        <div className="col-12">
          <div className="alert alert-danger">
            <strong>Ошибка:</strong> {(error as BaseError).shortMessage || error.message}
          </div>
        </div>
      )}
    </form>
  )
}
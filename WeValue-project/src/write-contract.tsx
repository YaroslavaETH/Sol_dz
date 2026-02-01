import * as React from 'react'
import { useWriteContract } from 'wagmi'
import { WeValueContractConfig } from './contracts'
import { parseEther } from 'viem'
 
export function DonationForm() {
  const { data: hash, writeContract } = useWriteContract()

  async function submit(e: React.FormEvent<HTMLFormElement>) { 
    e.preventDefault() 
    const formData = new FormData(e.target as HTMLFormElement) 
    const Donation = formData.get('Donation') as string 
    writeContract({
      address: WeValueContractConfig.address,
      abi:WeValueContractConfig.abi,
      functionName: 'donation',
      args: [],
      value: parseEther(Donation),
    })
  } 

  return (
    <form onSubmit={submit}>
      <input name="Donation" required />
      <button type="submit">Donation</button>
      {hash && <div>Transaction Hash: {hash}</div>}
    </form>
  )
}
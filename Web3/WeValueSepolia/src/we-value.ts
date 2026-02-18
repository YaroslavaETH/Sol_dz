import {
  AddCheckToWithdrawal as AddCheckToWithdrawalEvent,
  Approval as ApprovalEvent,
  AssetsEvacuated as AssetsEvacuatedEvent,
  Donation as DonationEvent,
  EIP712DomainChanged as EIP712DomainChangedEvent,
  EthConverted as EthConvertedEvent,
  Help as HelpEvent,
  Initialized as InitializedEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  ProtectedAssetRotated as ProtectedAssetRotatedEvent,
  SafeAssetChanged as SafeAssetChangedEvent,
  Transfer as TransferEvent,
  Upgraded as UpgradedEvent,
  WithdrawalConfirmed as WithdrawalConfirmedEvent,
  WithdrawalProtectedAsset as WithdrawalProtectedAssetEvent
} from "../generated/WeValue/WeValue"
import {
  AddCheckToWithdrawal,
  Approval,
  AssetsEvacuated,
  Donation,
  EIP712DomainChanged,
  EthConverted,
  Help,
  Initialized,
  OwnershipTransferred,
  ProtectedAssetRotated,
  SafeAssetChanged,
  Transfer,
  Upgraded,
  WithdrawalConfirmed,
  WithdrawalProtectedAsset
} from "../generated/schema"

export function handleAddCheckToWithdrawal(
  event: AddCheckToWithdrawalEvent
): void {
  let entity = new AddCheckToWithdrawal(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.operationId = event.params.operationId
  entity.date = event.params.date
  entity.fn = event.params.fn
  entity.fd = event.params.fd
  entity.fpd = event.params.fpd

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleApproval(event: ApprovalEvent): void {
  let entity = new Approval(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.owner = event.params.owner
  entity.spender = event.params.spender
  entity.value = event.params.value

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleAssetsEvacuated(event: AssetsEvacuatedEvent): void {
  let entity = new AssetsEvacuated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.amountIn = event.params.amountIn
  entity.amountOut = event.params.amountOut

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleDonation(event: DonationEvent): void {
  let entity = new Donation(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.account = event.params.account
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleEIP712DomainChanged(
  event: EIP712DomainChangedEvent
): void {
  let entity = new EIP712DomainChanged(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleEthConverted(event: EthConvertedEvent): void {
  let entity = new EthConverted(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.ethAmount = event.params.ethAmount
  entity.protectedAssetAmount = event.params.protectedAssetAmount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleHelp(event: HelpEvent): void {
  let entity = new Help(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.accountTo = event.params.accountTo
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleInitialized(event: InitializedEvent): void {
  let entity = new Initialized(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.version = event.params.version

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleProtectedAssetRotated(
  event: ProtectedAssetRotatedEvent
): void {
  let entity = new ProtectedAssetRotated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.oldProtectedAsset = event.params.oldProtectedAsset
  entity.newProtectedAsset = event.params.newProtectedAsset

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSafeAssetChanged(event: SafeAssetChangedEvent): void {
  let entity = new SafeAssetChanged(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.newSafeAsset = event.params.newSafeAsset

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTransfer(event: TransferEvent): void {
  let entity = new Transfer(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.from = event.params.from
  entity.to = event.params.to
  entity.value = event.params.value

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleUpgraded(event: UpgradedEvent): void {
  let entity = new Upgraded(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.implementation = event.params.implementation

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleWithdrawalConfirmed(
  event: WithdrawalConfirmedEvent
): void {
  let entity = new WithdrawalConfirmed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.operationId = event.params.operationId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleWithdrawalProtectedAsset(
  event: WithdrawalProtectedAssetEvent
): void {
  let entity = new WithdrawalProtectedAsset(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.operationId = event.params.operationId
  entity.amount = event.params.amount
  entity.token = event.params.token
  entity.recipient = event.params.recipient
  entity.offchain = event.params.offchain
  entity.decription = event.params.decription

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

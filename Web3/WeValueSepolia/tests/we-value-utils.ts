import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
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
} from "../generated/WeValue/WeValue"

export function createAddCheckToWithdrawalEvent(
  operationId: BigInt,
  date: BigInt,
  fn: BigInt,
  fd: BigInt,
  fpd: BigInt
): AddCheckToWithdrawal {
  let addCheckToWithdrawalEvent =
    changetype<AddCheckToWithdrawal>(newMockEvent())

  addCheckToWithdrawalEvent.parameters = new Array()

  addCheckToWithdrawalEvent.parameters.push(
    new ethereum.EventParam(
      "operationId",
      ethereum.Value.fromUnsignedBigInt(operationId)
    )
  )
  addCheckToWithdrawalEvent.parameters.push(
    new ethereum.EventParam("date", ethereum.Value.fromUnsignedBigInt(date))
  )
  addCheckToWithdrawalEvent.parameters.push(
    new ethereum.EventParam("fn", ethereum.Value.fromUnsignedBigInt(fn))
  )
  addCheckToWithdrawalEvent.parameters.push(
    new ethereum.EventParam("fd", ethereum.Value.fromUnsignedBigInt(fd))
  )
  addCheckToWithdrawalEvent.parameters.push(
    new ethereum.EventParam("fpd", ethereum.Value.fromUnsignedBigInt(fpd))
  )

  return addCheckToWithdrawalEvent
}

export function createApprovalEvent(
  owner: Address,
  spender: Address,
  value: BigInt
): Approval {
  let approvalEvent = changetype<Approval>(newMockEvent())

  approvalEvent.parameters = new Array()

  approvalEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("spender", ethereum.Value.fromAddress(spender))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return approvalEvent
}

export function createAssetsEvacuatedEvent(
  amountIn: BigInt,
  amountOut: BigInt
): AssetsEvacuated {
  let assetsEvacuatedEvent = changetype<AssetsEvacuated>(newMockEvent())

  assetsEvacuatedEvent.parameters = new Array()

  assetsEvacuatedEvent.parameters.push(
    new ethereum.EventParam(
      "amountIn",
      ethereum.Value.fromUnsignedBigInt(amountIn)
    )
  )
  assetsEvacuatedEvent.parameters.push(
    new ethereum.EventParam(
      "amountOut",
      ethereum.Value.fromUnsignedBigInt(amountOut)
    )
  )

  return assetsEvacuatedEvent
}

export function createDonationEvent(
  account: Address,
  amount: BigInt
): Donation {
  let donationEvent = changetype<Donation>(newMockEvent())

  donationEvent.parameters = new Array()

  donationEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  donationEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return donationEvent
}

export function createEIP712DomainChangedEvent(): EIP712DomainChanged {
  let eip712DomainChangedEvent = changetype<EIP712DomainChanged>(newMockEvent())

  eip712DomainChangedEvent.parameters = new Array()

  return eip712DomainChangedEvent
}

export function createEthConvertedEvent(
  ethAmount: BigInt,
  protectedAssetAmount: BigInt
): EthConverted {
  let ethConvertedEvent = changetype<EthConverted>(newMockEvent())

  ethConvertedEvent.parameters = new Array()

  ethConvertedEvent.parameters.push(
    new ethereum.EventParam(
      "ethAmount",
      ethereum.Value.fromUnsignedBigInt(ethAmount)
    )
  )
  ethConvertedEvent.parameters.push(
    new ethereum.EventParam(
      "protectedAssetAmount",
      ethereum.Value.fromUnsignedBigInt(protectedAssetAmount)
    )
  )

  return ethConvertedEvent
}

export function createHelpEvent(accountTo: Address, amount: BigInt): Help {
  let helpEvent = changetype<Help>(newMockEvent())

  helpEvent.parameters = new Array()

  helpEvent.parameters.push(
    new ethereum.EventParam("accountTo", ethereum.Value.fromAddress(accountTo))
  )
  helpEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return helpEvent
}

export function createInitializedEvent(version: BigInt): Initialized {
  let initializedEvent = changetype<Initialized>(newMockEvent())

  initializedEvent.parameters = new Array()

  initializedEvent.parameters.push(
    new ethereum.EventParam(
      "version",
      ethereum.Value.fromUnsignedBigInt(version)
    )
  )

  return initializedEvent
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent =
    changetype<OwnershipTransferred>(newMockEvent())

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createProtectedAssetRotatedEvent(
  oldProtectedAsset: Address,
  newProtectedAsset: Address
): ProtectedAssetRotated {
  let protectedAssetRotatedEvent =
    changetype<ProtectedAssetRotated>(newMockEvent())

  protectedAssetRotatedEvent.parameters = new Array()

  protectedAssetRotatedEvent.parameters.push(
    new ethereum.EventParam(
      "oldProtectedAsset",
      ethereum.Value.fromAddress(oldProtectedAsset)
    )
  )
  protectedAssetRotatedEvent.parameters.push(
    new ethereum.EventParam(
      "newProtectedAsset",
      ethereum.Value.fromAddress(newProtectedAsset)
    )
  )

  return protectedAssetRotatedEvent
}

export function createSafeAssetChangedEvent(
  newSafeAsset: Address
): SafeAssetChanged {
  let safeAssetChangedEvent = changetype<SafeAssetChanged>(newMockEvent())

  safeAssetChangedEvent.parameters = new Array()

  safeAssetChangedEvent.parameters.push(
    new ethereum.EventParam(
      "newSafeAsset",
      ethereum.Value.fromAddress(newSafeAsset)
    )
  )

  return safeAssetChangedEvent
}

export function createTransferEvent(
  from: Address,
  to: Address,
  value: BigInt
): Transfer {
  let transferEvent = changetype<Transfer>(newMockEvent())

  transferEvent.parameters = new Array()

  transferEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return transferEvent
}

export function createUpgradedEvent(implementation: Address): Upgraded {
  let upgradedEvent = changetype<Upgraded>(newMockEvent())

  upgradedEvent.parameters = new Array()

  upgradedEvent.parameters.push(
    new ethereum.EventParam(
      "implementation",
      ethereum.Value.fromAddress(implementation)
    )
  )

  return upgradedEvent
}

export function createWithdrawalConfirmedEvent(
  operationId: BigInt
): WithdrawalConfirmed {
  let withdrawalConfirmedEvent = changetype<WithdrawalConfirmed>(newMockEvent())

  withdrawalConfirmedEvent.parameters = new Array()

  withdrawalConfirmedEvent.parameters.push(
    new ethereum.EventParam(
      "operationId",
      ethereum.Value.fromUnsignedBigInt(operationId)
    )
  )

  return withdrawalConfirmedEvent
}

export function createWithdrawalProtectedAssetEvent(
  operationId: BigInt,
  amount: BigInt,
  token: Address,
  recipient: Address,
  offchain: boolean,
  decription: string
): WithdrawalProtectedAsset {
  let withdrawalProtectedAssetEvent =
    changetype<WithdrawalProtectedAsset>(newMockEvent())

  withdrawalProtectedAssetEvent.parameters = new Array()

  withdrawalProtectedAssetEvent.parameters.push(
    new ethereum.EventParam(
      "operationId",
      ethereum.Value.fromUnsignedBigInt(operationId)
    )
  )
  withdrawalProtectedAssetEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )
  withdrawalProtectedAssetEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  withdrawalProtectedAssetEvent.parameters.push(
    new ethereum.EventParam("recipient", ethereum.Value.fromAddress(recipient))
  )
  withdrawalProtectedAssetEvent.parameters.push(
    new ethereum.EventParam("offchain", ethereum.Value.fromBoolean(offchain))
  )
  withdrawalProtectedAssetEvent.parameters.push(
    new ethereum.EventParam("decription", ethereum.Value.fromString(decription))
  )

  return withdrawalProtectedAssetEvent
}

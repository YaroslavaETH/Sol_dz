import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
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
  TrustedForwarderChanged,
  Upgraded
} from "../generated/WeValue/WeValue"

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

export function createTrustedForwarderChangedEvent(
  newTrustedForwarder: Address
): TrustedForwarderChanged {
  let trustedForwarderChangedEvent =
    changetype<TrustedForwarderChanged>(newMockEvent())

  trustedForwarderChangedEvent.parameters = new Array()

  trustedForwarderChangedEvent.parameters.push(
    new ethereum.EventParam(
      "newTrustedForwarder",
      ethereum.Value.fromAddress(newTrustedForwarder)
    )
  )

  return trustedForwarderChangedEvent
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

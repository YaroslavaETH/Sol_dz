import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { BigInt, Address } from "@graphprotocol/graph-ts"
import { AddCheckToWithdrawal } from "../generated/schema"
import { AddCheckToWithdrawal as AddCheckToWithdrawalEvent } from "../generated/WeV/WeV"
import { handleAddCheckToWithdrawal } from "../src/we-v"
import { createAddCheckToWithdrawalEvent } from "./we-v-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#tests-structure

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let operationId = BigInt.fromI32(234)
    let date = BigInt.fromI32(234)
    let fn = BigInt.fromI32(234)
    let fd = BigInt.fromI32(234)
    let fpd = BigInt.fromI32(234)
    let newAddCheckToWithdrawalEvent = createAddCheckToWithdrawalEvent(
      operationId,
      date,
      fn,
      fd,
      fpd
    )
    handleAddCheckToWithdrawal(newAddCheckToWithdrawalEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#write-a-unit-test

  test("AddCheckToWithdrawal created and stored", () => {
    assert.entityCount("AddCheckToWithdrawal", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "AddCheckToWithdrawal",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "operationId",
      "234"
    )
    assert.fieldEquals(
      "AddCheckToWithdrawal",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "date",
      "234"
    )
    assert.fieldEquals(
      "AddCheckToWithdrawal",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "fn",
      "234"
    )
    assert.fieldEquals(
      "AddCheckToWithdrawal",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "fd",
      "234"
    )
    assert.fieldEquals(
      "AddCheckToWithdrawal",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "fpd",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#asserts
  })
})

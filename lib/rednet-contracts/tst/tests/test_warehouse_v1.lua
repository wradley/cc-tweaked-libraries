---@diagnostic disable: need-check-nil
local lu = require("deps.luaunit")
local env = require("cc.cc_test_env")

local M = {}

local function freshContracts()
  package.loaded.rednet_contracts = nil
  package.loaded["rednet_contracts.init"] = nil
  package.loaded["rednet_contracts.discovery_v1"] = nil
  package.loaded["rednet_contracts.errors"] = nil
  package.loaded["rednet_contracts.schema_validation"] = nil
  package.loaded["rednet_contracts.mrpc_v1"] = nil
  package.loaded["rednet_contracts.services.warehouse_v1"] = nil
  package.loaded["rednet_contracts.services.global_inventory_v1"] = nil
  return require("rednet_contracts")
end

function M.setUp()
  env.install({ epoch = 100 })
end

function M.tearDown()
  env.restore()
end

function M.testAssignTransferRequestUsesNewShape()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-2",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      transfer_request_id = "tr-1",
      assignment_count = 1,
      item_count = 32,
      accepted = true,
      sent_at = 101,
    },
    sent_at = 101,
  }, "rc.mrpc_v1")

  local result, err = warehouse.assignTransferRequest(77, {
    coordinator_id = "coordinator-1",
    transfer_request_id = "tr-1",
    sent_at = 100,
    warehouse_id = "wh-1",
    assignments = {
      {
        assignment_id = "as-1",
        source = "global_inventory",
        destination = "crate-a",
        destination_address = "east",
        reason = "rebalance",
        status = "queued",
        items = {
          {
            name = "minecraft:iron_ingot",
            count = 32,
          },
        },
        total_items = 32,
        line_count = 1,
      },
    },
    total_assignments = 1,
    total_items = 32,
  }, {
    request_id = "req-2",
  })

  lu.assertNil(err)
  lu.assertTrue(result.accepted)
  lu.assertEquals(env.getRednetSends()[1].message.method, "assign_transfer_request")
  lu.assertNil(env.getRednetSends()[1].message.params.assignments[1].items[1].transfer_id)
end

function M.testGetOwnerCallsMrpcAndAllowsNilOwner()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-owner-1",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      owner = nil,
      observed_at = 101,
    },
    sent_at = 101,
  }, "rc.mrpc_v1")

  local result, err = warehouse.getOwner(77, {
    request_id = "req-owner-1",
  })

  lu.assertNil(err)
  lu.assertEquals(result.warehouse_id, "wh-1")
  lu.assertNil(result.owner)
  lu.assertEquals(env.getRednetSends()[1].message.method, warehouse.METHODS.GET_OWNER)
  lu.assertEquals(env.getRednetSends()[1].message.params, {})
end

function M.testSetOwnerSendsOwnerClaimAndReturnsValidatedResult()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-owner-2",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      accepted = true,
      owner = {
        coordinator_id = "coord-1",
        coordinator_address = "global-sync",
        claimed_at = 100,
      },
      sent_at = 101,
    },
    sent_at = 101,
  }, "rc.mrpc_v1")

  local result, err = warehouse.setOwner(77, {
    coordinator_id = "coord-1",
    coordinator_address = "global-sync",
    claimed_at = 100,
  }, {
    request_id = "req-owner-2",
  })

  lu.assertNil(err)
  lu.assertTrue(result.accepted)
  lu.assertEquals(result.owner.coordinator_id, "coord-1")
  lu.assertEquals(env.getRednetSends()[1].message.method, warehouse.METHODS.SET_OWNER)
  lu.assertEquals(env.getRednetSends()[1].message.params.coordinator_address, "global-sync")
end

function M.testGetSnapshotCallsMrpcAndReturnsValidatedResult()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-1",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      observed_at = 101,
      inventory = {
        ["minecraft:iron_ingot"] = 10,
      },
      capacity = {
        slot_capacity_total = 20,
        slot_capacity_used = 5,
      },
    },
    sent_at = 102,
  }, "rc.mrpc_v1")

  local result, err = warehouse.getSnapshot(77, {
    request_id = "req-1",
  })

  lu.assertNil(err)
  lu.assertEquals(result.warehouse_id, "wh-1")
  lu.assertEquals(env.getRednetSends()[1].protocol, "rc.mrpc_v1")
  lu.assertEquals(env.getRednetSends()[1].message.method, "get_snapshot")
  lu.assertEquals(env.getRednetSends()[1].message.params, {})
end

function M.testGetOverviewRejectsInvalidResponseShape()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-3",
    ok = true,
    result = {
      warehouse_id = "wh-1",
    },
    sent_at = 102,
  }, "rc.mrpc_v1")

  local result, err = warehouse.getOverview(77, {
    request_id = "req-3",
  })

  lu.assertNil(result)
  lu.assertEquals(err.details.path, "result.warehouse_address")
end

function M.testGetTransferRequestStatusReturnsValidatedPackageEvidence()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-status-1",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      transfer_request_id = "tr-1",
      status = "queued",
      executed_at = 101,
      total_assignments = 1,
      total_items_requested = 32,
      total_items_queued = 32,
      assignments = {
        {
          assignment_id = "as-1",
          destination = "west",
          destination_address = "WH_WEST",
          line_count = 1,
          requested_items = 32,
          queued_items = 32,
          status = "queued",
        },
      },
      packages = {
        ["in"] = {
          "123-1-1",
        },
        ["out"] = {
          "456-1-1",
          "456-1-2",
        },
      },
      sent_at = 102,
    },
    sent_at = 102,
  }, "rc.mrpc_v1")

  local result, err = warehouse.getTransferRequestStatus(77, {
    transfer_request_id = "tr-1",
  }, {
    request_id = "req-status-1",
  })

  lu.assertNil(err)
  lu.assertEquals(result.transfer_request_id, "tr-1")
  lu.assertEquals(result.packages["in"][1], "123-1-1")
  lu.assertEquals(result.packages["out"][2], "456-1-2")
  lu.assertEquals(env.getRednetSends()[1].message.method, warehouse.METHODS.GET_TRANSFER_REQUEST_STATUS)
end

function M.testGetTransferRequestStatusRejectsMissingPackages()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-status-2",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      transfer_request_id = "tr-1",
      status = "queued",
      executed_at = 101,
      total_assignments = 1,
      total_items_requested = 32,
      total_items_queued = 32,
      assignments = {},
      sent_at = 102,
    },
    sent_at = 102,
  }, "rc.mrpc_v1")

  local result, err = warehouse.getTransferRequestStatus(77, {
    transfer_request_id = "tr-1",
  }, {
    request_id = "req-status-2",
  })

  lu.assertNil(result)
  lu.assertEquals(err.details.path, "result.packages")
end

function M.testReceiveRequestAutoRepliesOnMalformedParams()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(88, {
    type = "request",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-bad",
    method = "get_snapshot",
    params = {
      coordinator_id = "unexpected",
    },
    sent_at = 100,
  }, "rc.mrpc_v1")

  local senderId, request, method, err = warehouse.receiveRequest()

  lu.assertEquals(senderId, 88)
  lu.assertNil(request)
  lu.assertNil(method)
  lu.assertEquals(err.details.path, "params")
  lu.assertEquals(env.getRednetSends()[1].message.ok, false)
  lu.assertEquals(env.getRednetSends()[1].message.error.code, "invalid_value")
end

function M.testReceiveRequestAutoRepliesOnMalformedSetOwnerParams()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  env.queueRednetReceive(88, {
    type = "request",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-bad-owner",
    method = warehouse.METHODS.SET_OWNER,
    params = {
      coordinator_id = "coord-1",
      claimed_at = 100,
    },
    sent_at = 100,
  }, "rc.mrpc_v1")

  local senderId, request, method, err = warehouse.receiveRequest()

  lu.assertEquals(senderId, 88)
  lu.assertNil(request)
  lu.assertNil(method)
  lu.assertEquals(err.details.path, "params.coordinator_address")
  lu.assertEquals(env.getRednetSends()[1].message.ok, false)
  lu.assertEquals(env.getRednetSends()[1].message.error.code, "invalid_type")
end

function M.testConfigProvidesStickyDefaults()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  warehouse.config({
    rednet_protocol = "custom.warehouse",
    timeout = 3,
  })

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-4",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      observed_at = 101,
      inventory = {
        ["minecraft:iron_ingot"] = 10,
      },
      capacity = {
        slot_capacity_total = 20,
        slot_capacity_used = 5,
      },
    },
    sent_at = 102,
  }, "custom.warehouse")

  local result, err = warehouse.getSnapshot(77, {
    request_id = "req-4",
  })

  lu.assertNil(err)
  lu.assertEquals(result.warehouse_id, "wh-1")
  lu.assertEquals(env.getRednetSends()[1].protocol, "custom.warehouse")
end

function M.testPerCallOptionsOverrideConfiguredDefaults()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  warehouse.config({
    rednet_protocol = "default.warehouse",
    timeout = 3,
  })

  env.queueRednetReceive(77, {
    type = "response",
    protocol = {
      name = "warehouse",
      version = 1,
    },
    request_id = "req-5",
    ok = true,
    result = {
      warehouse_id = "wh-1",
      warehouse_address = "east",
      observed_at = 101,
      inventory = {
        ["minecraft:iron_ingot"] = 10,
      },
      capacity = {
        slot_capacity_total = 20,
        slot_capacity_used = 5,
      },
    },
    sent_at = 102,
  }, "override.warehouse")

  local result, err = warehouse.getSnapshot(77, {
    request_id = "req-5",
    rednet_protocol = "override.warehouse",
  })

  lu.assertNil(err)
  lu.assertEquals(result.warehouse_id, "wh-1")
  lu.assertEquals(env.getRednetSends()[1].protocol, "override.warehouse")
end

function M.testMethodsExposeOwnerOperations()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  lu.assertEquals(warehouse.METHODS.GET_OWNER, "get_owner")
  lu.assertEquals(warehouse.METHODS.SET_OWNER, "set_owner")
end

return M

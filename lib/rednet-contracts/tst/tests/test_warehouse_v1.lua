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

function M.testGetSnapshotRequestRequiresEmptyParams()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  lu.assertTrue(select(1, warehouse.validateGetSnapshotParams({})))

  local ok, err = warehouse.validateGetSnapshotParams({
    coordinator_id = "coordinator-1",
  })

  lu.assertFalse(ok)
  lu.assertEquals(err.code, "invalid_value")
  lu.assertEquals(err.details.path, "params")
end

function M.testAssignTransferRequestBuildRequestUsesNewShape()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  local request = warehouse.buildRequest("req-2", "assign_transfer_request", {
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
  }, 101)

  lu.assertEquals(request.method, "assign_transfer_request")
  lu.assertNil(request.params.assignments[1].items[1].transfer_id)
  lu.assertTrue(select(1, warehouse.validateRequest(request)))
end

function M.testGetOverviewResponseAcceptsContractShape()
  local contracts = freshContracts()
  local warehouse = contracts.warehouse_v1

  local response = warehouse.buildResponse("req-3", "get_overview", {
    warehouse_id = "wh-1",
    warehouse_address = "east",
    observed_at = 1000,
    status = {
      online = true,
      storage_online = 4,
      storage_total = 5,
      slot_capacity_used = 10,
      slot_capacity_total = 20,
      storages_with_unknown_capacity = 1,
    },
    active_transfer_request = {
      id = "tr-1",
      received_at = 900,
    },
    last_ack = {
      transfer_request_id = "tr-1",
      sent_at = 950,
    },
    last_execution = {
      transfer_request_id = "tr-1",
      status = "partial",
      executed_at = 990,
      assignments = {
        [0] = {
          destination = "crate-a",
          item_count = 16,
        },
      },
      total_items_requested = 32,
      total_items_queued = 16,
    },
    recent_issues = {},
  }, 1001)

  lu.assertTrue(select(1, warehouse.validateResponseForMethod("get_overview", response)))
end

function M.testGetSnapshotCallsRpcAndReturnsValidatedResult()
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

  local result, err = warehouse.getSnapshot(77, {}, {
    request_id = "req-1",
  })

  lu.assertNil(err)
  lu.assertEquals(result.warehouse_id, "wh-1")
  lu.assertEquals(env.getRednetSends()[1].protocol, "rc.mrpc_v1")
  lu.assertEquals(env.getRednetSends()[1].message.method, "get_snapshot")
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

return M

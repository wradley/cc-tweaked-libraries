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

function M.testOverviewRequiresTransferCycleField()
  local contracts = freshContracts()
  local protocol = contracts.global_inventory_v1

  local ok, err = protocol.validateGetOverviewResult({
    coordinator_id = "coordinator-1",
    observed_at = 100,
    schedule = {
      paused = false,
      sync_interval_seconds = 30,
      next_sync_due_at = 130,
    },
    cycle = {
      active = false,
      kind = nil,
      started_at = nil,
      completed_warehouses = 0,
      total_warehouses = 3,
    },
    warehouses = {},
    inventory_summary = {
      total_item_types = 5,
      total_item_count = 100,
      slot_capacity_used = 10,
      slot_capacity_total = 20,
    },
    recent_issues = {},
  })

  lu.assertFalse(ok)
  lu.assertEquals(err.details.path, "result.transfer_cycle")
end

function M.testOverviewResponseUsesTransferCycleShape()
  local contracts = freshContracts()
  local protocol = contracts.global_inventory_v1

  local response = protocol.buildResponse("req-4", "get_overview", {
    coordinator_id = "coordinator-1",
    observed_at = 100,
    schedule = {
      paused = false,
      sync_interval_seconds = 30,
      next_sync_due_at = 130,
    },
    transfer_cycle = {
      active = true,
      kind = "rebalance",
      started_at = 80,
      completed_warehouses = 1,
      total_warehouses = 3,
    },
    warehouses = {
      {
        warehouse_id = "wh-1",
        warehouse_address = "east",
        state = "accepted",
        online = true,
        last_heartbeat_at = 95,
        last_snapshot_at = 96,
        last_transfer_request_id = "tr-1",
        last_transfer_request_status = "queued",
      },
    },
    inventory_summary = {
      total_item_types = 5,
      total_item_count = 100,
      slot_capacity_used = 10,
      slot_capacity_total = 20,
    },
    recent_issues = {},
  }, 101)

  lu.assertTrue(select(1, protocol.validateResponseForMethod("get_overview", response)))
end

function M.testPauseSyncCallsServiceWrapper()
  local contracts = freshContracts()
  local protocol = contracts.global_inventory_v1

  env.queueRednetReceive(44, {
    type = "response",
    protocol = {
      name = "global_inventory",
      version = 1,
    },
    request_id = "req-2",
    ok = true,
    result = {
      coordinator_id = "coordinator-1",
      paused = true,
      changed = true,
      sent_at = 101,
    },
    sent_at = 101,
  }, "rc.mrpc_v1")

  local result, err = protocol.pauseSync(44, {}, {
    request_id = "req-2",
  })

  lu.assertNil(err)
  lu.assertTrue(result.paused)
  lu.assertEquals(env.getRednetSends()[1].message.method, "pause_sync")
end

return M

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
  env.install({ epoch = 10 })
end

function M.tearDown()
  env.restore()
end

function M.testBuildHeartbeatAddsTypeAndValidatesShape()
  local contracts = freshContracts()

  local heartbeat = contracts.discovery_v1.buildHeartbeat({
    device_id = "warehouse-east",
    device_type = "warehouse_controller",
    sent_at = 10,
    protocols = {
      { name = "warehouse", version = 1, role = "server" },
    },
  })

  lu.assertEquals(heartbeat.type, "device_discovery_heartbeat")
  lu.assertEquals(heartbeat.discovery_version, contracts.discovery_v1.DISCOVERY_VERSION)
  lu.assertTrue(select(1, contracts.discovery_v1.validateHeartbeat(heartbeat)))
end

function M.testHeartbeatRejectsInvalidProtocolRole()
  local contracts = freshContracts()

  local ok, err = contracts.discovery_v1.validateHeartbeat({
    type = "device_discovery_heartbeat",
    discovery_version = contracts.discovery_v1.DISCOVERY_VERSION,
    device_id = "warehouse-east",
    device_type = "warehouse_controller",
    sent_at = 10,
    protocols = {
      { name = "warehouse", version = 1, role = "peer" },
    },
  })

  lu.assertFalse(ok)
  lu.assertEquals(err.code, "invalid_value")
  lu.assertEquals(err.details.path, "message.protocols[1].role")
end

function M.testBroadcastUsesDefaultRednetProtocol()
  local contracts = freshContracts()

  contracts.discovery_v1.broadcast({
    device_id = "warehouse-east",
    device_type = "warehouse_controller",
    sent_at = 10,
    protocols = {
      { name = "warehouse", version = 1, role = "server" },
    },
  })

  lu.assertEquals(env.getRednetBroadcasts()[1].protocol, "rc.discovery_v1")
end

return M

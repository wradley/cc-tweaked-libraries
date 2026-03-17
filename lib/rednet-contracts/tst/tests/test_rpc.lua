local lu = require("deps.luaunit")
local env = require("cc.cc_test_env")

local M = {}

local function freshMrpc()
  package.loaded["rednet_contracts.errors"] = nil
  package.loaded["rednet_contracts.schema_validation"] = nil
  package.loaded["rednet_contracts.mrpc_v1"] = nil
  return require("rednet_contracts.mrpc_v1")
end

function M.setUp()
  env.install({ epoch = 25 })
end

function M.tearDown()
  env.restore()
end

function M.testBuildRequestAndResponseRoundTrip()
  local mrpc = freshMrpc()

  local request = mrpc.buildRequest(
    { name = "warehouse", version = 1 },
    "req-1",
    "get_snapshot",
    {},
    25
  )
  local response = mrpc.buildResponse(
    { name = "warehouse", version = 1 },
    "req-1",
    { warehouse_id = "wh-1" },
    30
  )

  lu.assertTrue(select(1, mrpc.validateRequest(request)))
  lu.assertTrue(select(1, mrpc.validateResponse(response)))
end

function M.testBuildErrorResponseCarriesStructuredError()
  local mrpc = freshMrpc()

  local response = mrpc.buildErrorResponse(
    { name = "warehouse", version = 1 },
    "req-1",
    "unknown_method",
    "unknown method",
    31,
    { path = "message.method" }
  )

  lu.assertFalse(response.ok)
  lu.assertEquals(response.error.code, "unknown_method")
  lu.assertTrue(select(1, mrpc.validateResponse(response)))
end

function M.testNewRequestIdUsesPrefixAndComputerIdWhenAvailable()
  local mrpc = freshMrpc()
  local originalGetComputerID = os.getComputerID
  os.getComputerID = function()
    return 42
  end

  local requestId = mrpc.newRequestId("warehouse-")
  os.getComputerID = originalGetComputerID

  lu.assertStrContains(requestId, "warehouse-")
  lu.assertStrContains(requestId, "c42-")
end

return M

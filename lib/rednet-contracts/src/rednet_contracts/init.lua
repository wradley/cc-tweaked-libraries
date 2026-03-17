---Shared discovery and message-RPC contract helpers for rednet-based services.
---@class RednetContracts
---@field VERSION string
---@field errors RednetContractsErrors
---@field discovery_v1 RednetContractsDiscoveryV1
---@field warehouse_v1 RednetContractsWarehouseV1
---@field global_inventory_v1 RednetContractsGlobalInventoryV1
local M = {
  VERSION = "0.1.0",
}

M.errors = require("rednet_contracts.errors")
M.discovery_v1 = require("rednet_contracts.discovery_v1")
M.warehouse_v1 = require("rednet_contracts.services.warehouse_v1")
M.global_inventory_v1 = require("rednet_contracts.services.global_inventory_v1")

return M

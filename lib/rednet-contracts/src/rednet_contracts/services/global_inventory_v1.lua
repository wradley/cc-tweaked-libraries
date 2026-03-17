local errors = require("rednet_contracts.errors")
local mrpc = require("rednet_contracts.mrpc_v1")
local schema = require("rednet_contracts.schema_validation")

---@class GlobalInventoryGetOverviewRequestParams

---@class GlobalInventoryPauseSyncRequestParams

---@class GlobalInventoryResumeSyncRequestParams

---@class GlobalInventorySyncNowRequestParams

---@class GlobalInventoryServiceCallOptions
---@field rednet_protocol string|nil
---@field timeout number|nil
---@field request_id string|nil
---@field auto_reply_errors boolean|nil
---@field details table|nil

---`global_inventory_v1` service helpers layered on top of `mrpc_v1`.
---@class RednetContractsGlobalInventoryV1
local M = {
  NAME = "global_inventory",
  VERSION = 1,
  GET_OVERVIEW = "get_overview",
  PAUSE_SYNC = "pause_sync",
  RESUME_SYNC = "resume_sync",
  SYNC_NOW = "sync_now",
}

M.SERVICE = {
  name = M.NAME,
  version = M.VERSION,
}

local function ensureMethod(method)
  if method == M.GET_OVERVIEW
    or method == M.PAUSE_SYNC
    or method == M.RESUME_SYNC
    or method == M.SYNC_NOW
  then
    return true
  end

  return schema.fail("unknown_method", "message.method", "unknown global_inventory_v1 method: " .. tostring(method))
end

local function validateIssueList(value, path)
  return schema.requireTable(value, path)
end

---Validate `global_inventory_v1.get_overview()` request params.
---@param params table
---@return boolean, table|nil
function M.validateGetOverviewParams(params)
  return schema.requireEmptyTable(params, "params")
end

local function validateSchedule(value, path)
  local ok, err = schema.requireTable(value, path)
  if not ok then
    return false, err
  end

  ok, err = schema.requireBoolean(value.paused, path .. ".paused")
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(value.sync_interval_seconds, path .. ".sync_interval_seconds")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalInteger(value.next_sync_due_at, path .. ".next_sync_due_at")
  if not ok then
    return false, err
  end

  return true
end

local function validateTransferCycle(value, path)
  local ok, err = schema.requireTable(value, path)
  if not ok then
    return false, err
  end

  ok, err = schema.requireBoolean(value.active, path .. ".active")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalString(value.kind, path .. ".kind")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalInteger(value.started_at, path .. ".started_at")
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(value.completed_warehouses, path .. ".completed_warehouses")
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(value.total_warehouses, path .. ".total_warehouses")
  if not ok then
    return false, err
  end

  return true
end

local function validateWarehouseOverview(entry, path)
  local ok, err = schema.requireTable(entry, path)
  if not ok then
    return false, err
  end

  for _, field in ipairs({ "warehouse_id", "warehouse_address" }) do
    ok, err = schema.requireString(entry[field], path .. "." .. field)
    if not ok then
      return false, err
    end
  end

  ok, err = schema.requireOneOf(entry.state, path .. ".state", {
    accepted = true,
    pending = true,
  })
  if not ok then
    return false, err
  end

  ok, err = schema.requireBoolean(entry.online, path .. ".online")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalInteger(entry.last_heartbeat_at, path .. ".last_heartbeat_at")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalInteger(entry.last_snapshot_at, path .. ".last_snapshot_at")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalString(entry.last_transfer_request_id, path .. ".last_transfer_request_id")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalString(entry.last_transfer_request_status, path .. ".last_transfer_request_status")
  if not ok then
    return false, err
  end

  return true
end

local function validateInventorySummary(value, path)
  local ok, err = schema.requireTable(value, path)
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(value.total_item_types, path .. ".total_item_types")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalInteger(value.total_item_count, path .. ".total_item_count")
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(value.slot_capacity_used, path .. ".slot_capacity_used")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalInteger(value.slot_capacity_total, path .. ".slot_capacity_total")
  if not ok then
    return false, err
  end

  return true
end

---Validate `global_inventory_v1.get_overview()` response result.
---@param result table
---@return boolean, table|nil
function M.validateGetOverviewResult(result)
  local ok, err = schema.requireTable(result, "result")
  if not ok then
    return false, err
  end

  ok, err = schema.requireString(result.coordinator_id, "result.coordinator_id")
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(result.observed_at, "result.observed_at")
  if not ok then
    return false, err
  end

  ok, err = validateSchedule(result.schedule, "result.schedule")
  if not ok then
    return false, err
  end

  ok, err = validateTransferCycle(result.transfer_cycle, "result.transfer_cycle")
  if not ok then
    return false, err
  end

  ok, err = schema.requireArrayItems(result.warehouses, "result.warehouses", validateWarehouseOverview)
  if not ok then
    return false, err
  end

  ok, err = validateInventorySummary(result.inventory_summary, "result.inventory_summary")
  if not ok then
    return false, err
  end

  ok, err = validateIssueList(result.recent_issues, "result.recent_issues")
  if not ok then
    return false, err
  end

  return true
end

---Validate `global_inventory_v1.pause_sync()` request params.
---@param params table
---@return boolean, table|nil
function M.validatePauseSyncParams(params)
  return schema.requireEmptyTable(params, "params")
end

---Validate `global_inventory_v1.resume_sync()` request params.
---@param params table
---@return boolean, table|nil
function M.validateResumeSyncParams(params)
  return schema.requireEmptyTable(params, "params")
end

---Validate `global_inventory_v1.sync_now()` request params.
---@param params table
---@return boolean, table|nil
function M.validateSyncNowParams(params)
  return schema.requireEmptyTable(params, "params")
end

local function validatePausedResult(result, expectedPaused)
  local ok, err = schema.requireTable(result, "result")
  if not ok then
    return false, err
  end

  ok, err = schema.requireString(result.coordinator_id, "result.coordinator_id")
  if not ok then
    return false, err
  end

  ok, err = schema.requireBoolean(result.paused, "result.paused")
  if not ok then
    return false, err
  end

  if result.paused ~= expectedPaused then
    return schema.fail("invalid_value", "result.paused", "result.paused does not match the method contract")
  end

  ok, err = schema.requireBoolean(result.changed, "result.changed")
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(result.sent_at, "result.sent_at")
  if not ok then
    return false, err
  end

  return true
end

---Validate `global_inventory_v1.pause_sync()` response result.
---@param result table
---@return boolean, table|nil
function M.validatePauseSyncResult(result)
  return validatePausedResult(result, true)
end

---Validate `global_inventory_v1.resume_sync()` response result.
---@param result table
---@return boolean, table|nil
function M.validateResumeSyncResult(result)
  return validatePausedResult(result, false)
end

---Validate `global_inventory_v1.sync_now()` response result.
---@param result table
---@return boolean, table|nil
function M.validateSyncNowResult(result)
  local ok, err = schema.requireTable(result, "result")
  if not ok then
    return false, err
  end

  ok, err = schema.requireString(result.coordinator_id, "result.coordinator_id")
  if not ok then
    return false, err
  end

  ok, err = schema.requireBoolean(result.accepted, "result.accepted")
  if not ok then
    return false, err
  end

  ok, err = schema.optionalString(result.reason, "result.reason")
  if not ok then
    return false, err
  end

  ok, err = schema.requireInteger(result.sent_at, "result.sent_at")
  if not ok then
    return false, err
  end

  return true
end

local VALIDATORS = {
  get_overview = {
    params = M.validateGetOverviewParams,
    result = M.validateGetOverviewResult,
  },
  pause_sync = {
    params = M.validatePauseSyncParams,
    result = M.validatePauseSyncResult,
  },
  resume_sync = {
    params = M.validateResumeSyncParams,
    result = M.validateResumeSyncResult,
  },
  sync_now = {
    params = M.validateSyncNowParams,
    result = M.validateSyncNowResult,
  },
}

---Validate a full `global_inventory_v1` RPC request.
---@param message table
---@return boolean, string|nil, table|nil
function M.validateRequest(message)
  local ok, err = mrpc.validateRequest(message)
  if not ok then
    return false, nil, err
  end

  if message.protocol.name ~= M.NAME or message.protocol.version ~= M.VERSION then
    return false, nil, errors.new("protocol_mismatch", "message.protocol does not match global_inventory_v1", {
      path = "message.protocol",
    })
  end

  ok, err = ensureMethod(message.method)
  if not ok then
    return false, nil, err
  end

  ok, err = VALIDATORS[message.method].params(message.params)
  if not ok then
    return false, nil, err
  end

  return true, message.method, nil
end

---Validate a `global_inventory_v1` RPC response for one method.
---@param method string
---@param message table
---@return boolean, table|nil
function M.validateResponseForMethod(method, message)
  local ok, err = ensureMethod(method)
  if not ok then
    return false, err
  end

  ok, err = mrpc.validateResponse(message)
  if not ok then
    return false, err
  end

  if message.protocol.name ~= M.NAME or message.protocol.version ~= M.VERSION then
    return false, errors.new("protocol_mismatch", "message.protocol does not match global_inventory_v1", {
      path = "message.protocol",
    })
  end

  if not message.ok then
    return true, nil
  end

  return VALIDATORS[method].result(message.result)
end

local function callMethod(rednetId, method, params, opts)
  local response, err = mrpc.call(rednetId, M.SERVICE, method, params or {}, opts)
  if not response then
    return nil, err
  end

  local ok, validationErr = M.validateResponseForMethod(method, response)
  if not ok then
    return nil, validationErr
  end

  if not response.ok then
    return nil, response.error
  end

  return response.result, nil
end

---Call `global_inventory_v1.get_overview()`.
---@param rednetId integer
---@param params GlobalInventoryGetOverviewRequestParams|nil
---@param opts GlobalInventoryServiceCallOptions|nil
---@return table|nil, table|nil
function M.getOverview(rednetId, params, opts)
  return callMethod(rednetId, M.GET_OVERVIEW, params or {}, opts)
end

---Call `global_inventory_v1.pause_sync()`.
---@param rednetId integer
---@param params GlobalInventoryPauseSyncRequestParams|nil
---@param opts GlobalInventoryServiceCallOptions|nil
---@return table|nil, table|nil
function M.pauseSync(rednetId, params, opts)
  return callMethod(rednetId, M.PAUSE_SYNC, params or {}, opts)
end

---Call `global_inventory_v1.resume_sync()`.
---@param rednetId integer
---@param params GlobalInventoryResumeSyncRequestParams|nil
---@param opts GlobalInventoryServiceCallOptions|nil
---@return table|nil, table|nil
function M.resumeSync(rednetId, params, opts)
  return callMethod(rednetId, M.RESUME_SYNC, params or {}, opts)
end

---Call `global_inventory_v1.sync_now()`.
---@param rednetId integer
---@param params GlobalInventorySyncNowRequestParams|nil
---@param opts GlobalInventoryServiceCallOptions|nil
---@return table|nil, table|nil
function M.syncNow(rednetId, params, opts)
  return callMethod(rednetId, M.SYNC_NOW, params or {}, opts)
end

---Receive and validate one `global_inventory_v1` request.
---@param opts GlobalInventoryServiceCallOptions|nil
---@return integer|nil, table|nil, string|nil, table|nil
function M.receiveRequest(opts)
  local senderId, request, err = mrpc.receiveRequest(opts)
  if not request then
    return senderId, nil, nil, err
  end

  local ok, method, validationErr = M.validateRequest(request)
  if ok then
    return senderId, request, method, nil
  end

  if (opts == nil or opts.auto_reply_errors ~= false) and senderId ~= nil and request.request_id ~= nil then
    mrpc.replyError(senderId, request, validationErr.code, validationErr.message, {
      rednet_protocol = opts and opts.rednet_protocol or nil,
      details = validationErr.details,
    })
  end

  return senderId, nil, nil, validationErr
end

---Reply to a validated `global_inventory_v1` request with a successful result.
---@param rednetId integer
---@param request MrpcRequestEnvelope
---@param method string
---@param result table
---@param opts GlobalInventoryServiceCallOptions|nil
---@return table
function M.replySuccess(rednetId, request, method, result, opts)
  local ok, err = VALIDATORS[method].result(result or {})
  if not ok then
    errors.raise(err, 1)
  end

  return mrpc.replySuccess(rednetId, request, result or {}, opts)
end

---Reply to a validated `global_inventory_v1` request with a structured error.
---@param rednetId integer
---@param request MrpcRequestEnvelope
---@param code string
---@param messageText string
---@param opts GlobalInventoryServiceCallOptions|nil
---@return table
function M.replyError(rednetId, request, code, messageText, opts)
  return mrpc.replyError(rednetId, request, code, messageText, opts)
end

return M

local fmt = require("ui.fmt")
local summaryModel = require("ui.summary_model")

---Summary screen renderer for the coordinator UI.
---@class SummaryView
local M = {}

---Write one warehouse summary line in the overview list.
---@param state CoordinatorState
---@param warehouseId string
---@param warehouseState WarehouseState
---@param globalUsedTotal integer|nil
---@return nil
local function writeStatusLine(state, warehouseId, warehouseState, globalUsedTotal)
  local snapshot = warehouseState.snapshot
  local shareText = "? of global"

  if warehouseState.state == "accepted" and snapshot and globalUsedTotal and globalUsedTotal > 0 then
    local used = snapshot.capacity.slot_capacity_used or 0
    if used <= 0 then
      shareText = "0% of global"
    else
      local shareTenths = math.floor((used * 1000) / globalUsedTotal + 0.5)
      if shareTenths > 0 and shareTenths < 10 then
        shareText = "<1% of global"
      else
        local whole = math.floor(shareTenths / 10)
        local tenth = shareTenths % 10
        if tenth == 0 then
          shareText = tostring(whole) .. "% of global"
        else
          shareText = tostring(whole) .. "." .. tostring(tenth) .. "% of global"
        end
      end
    end
  end

  term.write(warehouseId .. " [")

  local originalColor
  local color = fmt.statusColor(state, warehouseState)
  if color and term.getTextColor then
    originalColor = term.getTextColor()
    term.setTextColor(color)
  end

  term.write(fmt.stateLabel(state, warehouseState))

  if originalColor and term.setTextColor then
    term.setTextColor(originalColor)
  end

  term.write("]: ")
  term.write(shareText)

  local _, y = term.getCursorPos()
  term.setCursorPos(1, y + 1)
end

---Draw the summary/overview screen.
---@param state CoordinatorState
---@return nil
function M.draw(state)
  local summary = summaryModel.buildGlobalSummary(state)
  local cycle = state.execution_cycle
  local schedule = state.schedule
  local now = os.epoch("utc")
  local remainingSeconds = schedule and schedule:remainingSeconds(now)
  local remainingText = remainingSeconds and fmt.formatElapsed(remainingSeconds) or "unknown"

  term.clear()
  term.setCursorPos(1, 1)
  print(state.config.coordinator.display_name or state.config.coordinator.id)
  print("Warehouses: " .. tostring(summary.online_warehouses) .. "/" .. tostring(summary.accepted_warehouses) .. " online")
  print("Pending warehouses: " .. tostring(summary.pending_warehouses))
  print("Global item types: " .. tostring(summary.global_item_types))
  print("Global used: " .. (summary.global_used_percent and (tostring(summary.global_used_percent) .. "%") or "unknown"))
  print("Last msg: " .. (state.last_message_at and (tostring(math.floor((os.epoch("utc") - state.last_message_at) / 1000)) .. "s ago") or "never"))
  print("Last plan: " .. (state.last_plan_refresh_at and (tostring(math.floor((os.epoch("utc") - state.last_plan_refresh_at) / 1000)) .. "s ago") or "never"))
  if schedule and schedule.paused then
    print("Schedule: paused")
  else
    print("Schedule: every " .. tostring(schedule and schedule.interval_seconds or "?") .. "s, next in " .. remainingText)
  end
  if cycle and cycle.active then
    print("Cycle: active " .. tostring(cycle.completed_warehouses or 0) .. "/" .. tostring(cycle.total_warehouses or 0))
    print("[x] blocked  [p] pause/resume  [c] clear cycle")
  else
    print("Cycle: idle")
    print("[x] sync now  [p] pause/resume  [c] clear cycle")
  end
  print("")
  print("Press 1-9 for details")
  print("")

  local warehouseIds = state.warehouse_registry:listedIds()
  local lineCount = 8
  for index, warehouseId in ipairs(warehouseIds) do
    if lineCount > 18 or index > 9 then
      break
    end

    local warehouseState = state.warehouses[warehouseId]
    term.write(tostring(index) .. ". ")
    writeStatusLine(state, warehouseId, warehouseState, summary.global_slot_capacity_used)
    lineCount = lineCount + 1
  end
end

return M

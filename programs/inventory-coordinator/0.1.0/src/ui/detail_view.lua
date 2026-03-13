local fmt = require("ui.fmt")

---Warehouse detail screen renderer for the coordinator UI.
---@class DetailView
local M = {}

---Draw the detail screen for one warehouse, or fall back to summary if missing.
---@param state CoordinatorState
---@param warehouseId string
---@return boolean drawn True when the requested warehouse existed.
function M.draw(state, warehouseId)
  local warehouseState = state.warehouses[warehouseId]
  if not warehouseState then
    return false
  end

  local heartbeatAge = state.warehouse_registry:heartbeatAgeSeconds(warehouseState)
  local snapshotAge = state.warehouse_registry:snapshotAgeSeconds(warehouseState)
  local assignmentAckAge = state.warehouse_registry:assignmentAckAgeSeconds(warehouseState)
  local assignmentExecutionAge = state.warehouse_registry:assignmentExecutionAgeSeconds(warehouseState)
  local trainDepartureAge = state.warehouse_registry:trainDepartureAgeSeconds(warehouseState)
  local snapshot = warehouseState.snapshot
  local warehousePlan = state.latest_plan and state.latest_plan.warehouses and state.latest_plan.warehouses[warehouseId]
  local warehouseQueue = state.latest_transfer_queue and state.latest_transfer_queue.by_warehouse and state.latest_transfer_queue.by_warehouse[warehouseId]
  local cycleEntry = state.execution_cycle and state.execution_cycle.warehouses and state.execution_cycle.warehouses[warehouseId]

  term.clear()
  term.setCursorPos(1, 1)
  print("Warehouse Detail")
  print(warehouseId .. " (" .. fmt.stateLabel(state, warehouseState) .. ")")
  print("")
  print("Addr: " .. tostring(warehouseState.warehouse_address))
  print("Computer ID: " .. tostring(warehouseState.sender_id))
  print("Heartbeat: " .. (heartbeatAge and (tostring(heartbeatAge) .. "s ago") or "never"))
  print("Snapshot: " .. (snapshotAge and (tostring(snapshotAge) .. "s ago") or "never"))
  print("Assign ack: " .. (assignmentAckAge and (tostring(assignmentAckAge) .. "s ago") or "never"))
  print("Assign exec: " .. (assignmentExecutionAge and (tostring(assignmentExecutionAge) .. "s ago") or "never"))
  print("Train dep: " .. (trainDepartureAge and (tostring(trainDepartureAge) .. "s ago") or "never"))
  print("")

  if snapshot then
    local itemTypes = 0
    for _ in pairs(snapshot.inventory or {}) do
      itemTypes = itemTypes + 1
    end
    print("Item types: " .. tostring(itemTypes))
    print("Slots: " .. fmt.formatSlotsLine(snapshot))
    print("Observed: " .. tostring(snapshot.observed_at))
  else
    print("No snapshot available")
  end

  print("")
  if warehousePlan then
    print("Target share: " .. tostring(warehousePlan.target_share_percent) .. "%")
    print("Plan receive: " .. tostring(warehousePlan.planned_receive_count))
    print("Plan send: " .. tostring(warehousePlan.planned_send_count))

    local firstDeficit = warehousePlan.deficit_items[1]
    local firstSurplus = warehousePlan.surplus_items[1]
    if firstDeficit then
      print("Top receive: +" .. tostring(firstDeficit.count) .. " " .. fmt.shortItemName(firstDeficit.name))
    end
    if firstSurplus then
      print("Top send: -" .. tostring(firstSurplus.count) .. " " .. fmt.shortItemName(firstSurplus.name))
    end
  else
    print("Target share: unavailable")
    print("Planning: unavailable")
  end

  print("")
  if warehouseQueue then
    print("Planned in: " .. tostring(warehouseQueue.incoming_transfers) .. " tx / " .. tostring(warehouseQueue.incoming_items) .. " items")
    print("Planned out: " .. tostring(warehouseQueue.outgoing_transfers) .. " tx / " .. tostring(warehouseQueue.outgoing_items) .. " items")
    print("Last batch out: " .. tostring(warehouseState.last_assignment_count or 0) .. " tx / " .. tostring(warehouseState.last_assignment_item_count or 0) .. " items")
  else
    print("Queue: unavailable")
  end

  local execution = warehouseState.last_assignment_execution
  if execution then
    print("")
    print("Exec status: " .. tostring(execution.status))
    print("Exec queued: " .. tostring(execution.total_items_queued or 0) .. "/" .. tostring(execution.total_items_requested or 0))
  end

  if cycleEntry then
    print("")
    print("Cycle dep: " .. tostring(cycleEntry.departures_seen or 0) .. "/" .. tostring(cycleEntry.required_departures or 0))
    print("Cycle done: " .. tostring(cycleEntry.completed))
    if cycleEntry.last_train_name then
      print("Last train: " .. tostring(cycleEntry.last_train_name))
    end
  end

  print("")
  if warehouseState.state == "pending" then
    print("[a] accept  [r] remove  [b] back")
  elseif warehouseState.state == "accepted" then
    print("[r] remove  [b] back")
  else
    print("[b] back")
  end

  return true
end

return M

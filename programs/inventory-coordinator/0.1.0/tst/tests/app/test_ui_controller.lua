local lu = require("deps.luaunit")

local M = {}

local originalDetailView
local originalSummaryView
local originalModule

local summaryDraws
local detailDrawResult
local detailDrawCalls

local function resetModule(name)
  if package and package.loaded then
    package.loaded[name] = nil
  end
end

function M:setUp()
  summaryDraws = 0
  detailDrawResult = true
  detailDrawCalls = {}

  originalDetailView = package.loaded["ui.detail_view"]
  originalSummaryView = package.loaded["ui.summary_view"]
  originalModule = package.loaded["ui.controller"]

  package.loaded["ui.detail_view"] = {
    draw = function(state, warehouseId)
      detailDrawCalls[#detailDrawCalls + 1] = {
        state = state,
        warehouse_id = warehouseId,
      }
      return detailDrawResult
    end,
  }
  package.loaded["ui.summary_view"] = {
    draw = function()
      summaryDraws = summaryDraws + 1
    end,
  }

  resetModule("ui.controller")
end

function M:tearDown()
  package.loaded["ui.detail_view"] = originalDetailView
  package.loaded["ui.summary_view"] = originalSummaryView
  package.loaded["ui.controller"] = originalModule
end

function M:testSummaryInputRequestsManualReleaseWhenIdle()
  local controller = require("ui.controller")
  local state = {
    execution_cycle = { active = false },
    ui = {
      view = "summary",
      release_requested = nil,
    },
  }

  controller.handleInput(state, {}, "x")

  lu.assertEquals(state.ui.release_requested, "manual")
end

function M:testSummaryInputTogglesPauseAndMarksStateDirty()
  local controller = require("ui.controller")
  local resumedAt
  local state = {
    execution_cycle = { active = false },
    schedule = {
      paused = true,
      resumeFromNow = function(_, now)
        resumedAt = now
      end,
      pause = function()
        error("pause should not be called while already paused")
      end,
    },
    state_dirty = false,
    ui = {
      view = "summary",
    },
  }

  local oldOs = _G.os
  _G.os = setmetatable({
    epoch = function()
      return 1234
    end,
  }, {
    __index = oldOs,
  })

  controller.handleInput(state, {}, "p")

  _G.os = oldOs

  lu.assertEquals(resumedAt, 1234)
  lu.assertTrue(state.state_dirty)
end

function M:testDetailInputRemoveReturnsToSummary()
  local controller = require("ui.controller")
  local removedWarehouseId
  local state = {
    ui = {
      view = "detail",
      selected_warehouse_id = "alpha",
    },
  }
  local stateLib = {
    removeWarehouse = function(_, warehouseId)
      removedWarehouseId = warehouseId
    end,
  }

  controller.handleInput(state, stateLib, "r")

  lu.assertEquals(removedWarehouseId, "alpha")
  lu.assertEquals(state.ui.view, "summary")
  lu.assertNil(state.ui.selected_warehouse_id)
end

function M:testDrawFallsBackToSummaryWhenDetailWarehouseMissing()
  local controller = require("ui.controller")
  local state = {
    ui = {
      view = "detail",
      selected_warehouse_id = "missing",
    },
  }
  detailDrawResult = false

  controller.draw(state)

  lu.assertEquals(#detailDrawCalls, 1)
  lu.assertEquals(detailDrawCalls[1].warehouse_id, "missing")
  lu.assertEquals(summaryDraws, 1)
  lu.assertEquals(state.ui.view, "summary")
  lu.assertNil(state.ui.selected_warehouse_id)
end

return M

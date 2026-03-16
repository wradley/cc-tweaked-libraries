local lu = require("deps.luaunit")
local env = require("cc.cc_test_env")

local M = {}

local function freshLog()
  package.loaded.log = nil
  return require("log")
end

function M.setUp()
  env.install({ epoch = 0 })
end

function M.tearDown()
  package.loaded.log = nil
  env.restore()
end

function M.testDefaultConfigReturned()
  local log = freshLog()

  lu.assertEquals(log.config(), {
    output = {
      file = "var/log.txt",
      level = "info",
      mirror_to_term = false,
      timestamp = "utc",
    },
    retention = {
      mode = "none",
      max_lines = 1000,
    },
  })
end

function M.testInfoWritesExpectedLine()
  local log = freshLog()
  env.setEpoch(0)

  local message = log.info("started %s", "job-1")

  lu.assertEquals(message, "started job-1")
  lu.assertEquals(
    env.readFile("var/log.txt"),
    "[1970-01-01 00:00:00 UTC] [INFO] started job-1\n"
  )
end

function M.testLevelFilteringSkipsLowerSeverityWrites()
  local log = freshLog()
  log.config({
    output = {
      level = "warn",
    },
  })

  local message = log.info("skip me")

  lu.assertEquals(message, "skip me")
  lu.assertNil(env.readFile("var/log.txt"))
end

function M.testMirrorToTermPrintsWrittenLine()
  local log = freshLog()
  env.setEpoch(1234)
  log.config({
    output = {
      mirror_to_term = true,
      timestamp = "epoch",
    },
  })

  log.warn("watch %s", "station")

  lu.assertEquals(env.getPrintedLines(), {
    "[1234] [WARN] watch station",
  })
end

function M.testTruncateRetentionKeepsNewestLines()
  local log = freshLog()
  log.config({
    retention = {
      mode = "truncate",
      max_lines = 2,
    },
    output = {
      timestamp = "epoch",
    },
  })

  env.setEpoch(1)
  log.info("one")
  env.setEpoch(2)
  log.info("two")
  env.setEpoch(3)
  log.info("three")

  lu.assertEquals(
    env.readFile("var/log.txt"),
    "[2] [INFO] two\n[3] [INFO] three\n"
  )
end

function M.testPanicWritesThenRaises()
  local log = freshLog()
  env.setEpoch(5)

  local ok, err = pcall(function()
    log.panic("bad %s", "news")
  end)

  lu.assertFalse(ok)
  lu.assertStrContains(err, "bad news")
  lu.assertEquals(
    env.readFile("var/log.txt"),
    "[1970-01-01 00:00:00 UTC] [PANIC] bad news\n"
  )
end

function M.testInvalidConfigFailsLoudly()
  local log = freshLog()

  local ok, err = pcall(function()
    log.config({
      output = {
        mirror_to_term = "yes",
      },
    })
  end)

  lu.assertFalse(ok)
  lu.assertStrContains(err, "log.config output.mirror_to_term must be a boolean")
end

return M

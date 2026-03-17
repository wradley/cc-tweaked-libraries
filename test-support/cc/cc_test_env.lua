local M = {}

local original = {}
local currentEpoch = 0
local printedLines = {}
local rednetSends = {}
local rednetBroadcasts = {}
local rednetReceives = {}

-- Fake filesystem state used by tests for writes and assertions.
local fileContents = {}
local madeDirs = {}

local function copyArray(values)
  local copy = {}
  for index, value in ipairs(values) do
    copy[index] = value
  end
  return copy
end

local function normalize(path)
  path = tostring(path or "")
  path = path:gsub("\\", "/")
  path = path:gsub("/+", "/")
  if path ~= "/" then
    path = path:gsub("/$", "")
  end
  return path
end

local function splitLines(contents)
  local lines = {}
  contents = contents or ""
  contents = contents:gsub("\r\n", "\n")

  if contents == "" then
    return lines
  end

  for line in (contents .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end

  if lines[#lines] == "" then
    lines[#lines] = nil
  end

  return lines
end

local function joinLines(lines)
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

local function getDir(path)
  path = normalize(path)
  if path == "" or path == "/" then
    return ""
  end

  local parent = path:match("^(.*)/[^/]+$")
  if not parent or parent == "/" then
    return parent or ""
  end
  return parent
end

local function combine(base, child)
  base = normalize(base)
  child = normalize(child)

  if base == "" then
    return child
  end
  if child == "" then
    return base
  end
  if child:sub(1, 1) == "/" then
    return child
  end
  return normalize(base .. "/" .. child)
end

local function exists(path)
  path = normalize(path)
  if fileContents[path] ~= nil or madeDirs[path] then
    return true
  end

  local prefix = path == "" and "" or path .. "/"
  for filePath in pairs(fileContents) do
    if filePath:sub(1, #prefix) == prefix then
      return true
    end
  end
  for dirPath in pairs(madeDirs) do
    if dirPath:sub(1, #prefix) == prefix then
      return true
    end
  end

  -- Fall back to the real filesystem so `require(...)` can still load source
  -- files that live on disk outside the in-memory fake test outputs.
  if original.fs and original.fs.exists then
    return original.fs.exists(path)
  end

  return false
end

local function isDir(path)
  path = normalize(path)
  if madeDirs[path] then
    return true
  end
  if fileContents[path] ~= nil then
    return false
  end

  local prefix = path == "" and "" or path .. "/"
  for filePath in pairs(fileContents) do
    if filePath:sub(1, #prefix) == prefix then
      return true
    end
  end
  for dirPath in pairs(madeDirs) do
    if dirPath:sub(1, #prefix) == prefix then
      return true
    end
  end

  if original.fs and original.fs.isDir then
    return original.fs.isDir(path)
  end

  return false
end

local function open(path, mode)
  path = normalize(path)
  if mode == "a" then
    -- Append and write mode stay fully in-memory so tests never touch disk.
    local buffer = splitLines(fileContents[path] or "")
    return {
      writeLine = function(line)
        buffer[#buffer + 1] = tostring(line)
      end,
      close = function()
        fileContents[path] = joinLines(buffer)
      end,
    }
  end

  if mode == "w" then
    local buffer = {}
    return {
      writeLine = function(line)
        buffer[#buffer + 1] = tostring(line)
      end,
      close = function()
        fileContents[path] = joinLines(buffer)
      end,
    }
  end

  if mode == "r" then
    if fileContents[path] == nil then
      -- Reads fall back to the real filesystem when the file was not created by
      -- the test, which keeps module loading working under the fake `fs`.
      if original.fs and original.fs.open then
        return original.fs.open(path, mode)
      end
      return nil
    end
    local contents = fileContents[path]
    return {
      readAll = function()
        return contents
      end,
      close = function() end,
    }
  end

  error("unsupported fs.open mode in test env: " .. tostring(mode), 0)
end

function M.install(opts)
  currentEpoch = opts and opts.epoch or 0
  printedLines = {}
  fileContents = {}
  madeDirs = {}
  rednetSends = {}
  rednetBroadcasts = {}
  rednetReceives = {}

  original.fs = _G.fs
  original.os = _G.os
  original.print = _G.print
  original.rednet = _G.rednet

  _G.fs = {
    open = open,
    exists = exists,
    isDir = isDir,
    makeDir = function(path)
      path = normalize(path)
      while path ~= "" and path ~= "/" do
        madeDirs[path] = true
        path = getDir(path)
      end
    end,
    getDir = getDir,
    combine = combine,
  }

  _G.os = setmetatable({
    epoch = function()
      return currentEpoch
    end,
  }, {
    __index = original.os,
  })

  _G.print = function(...)
    local values = {}
    for index = 1, select("#", ...) do
      values[index] = tostring(select(index, ...))
    end
    printedLines[#printedLines + 1] = table.concat(values, "\t")
  end

  _G.rednet = {
    send = function(targetId, message, protocol)
      rednetSends[#rednetSends + 1] = {
        target_id = targetId,
        message = message,
        protocol = protocol,
      }
      return true
    end,
    broadcast = function(message, protocol)
      rednetBroadcasts[#rednetBroadcasts + 1] = {
        message = message,
        protocol = protocol,
      }
      return true
    end,
    receive = function(protocolFilter, timeout)
      local _ = timeout
      for index, entry in ipairs(rednetReceives) do
        if protocolFilter == nil or entry.protocol == protocolFilter then
          table.remove(rednetReceives, index)
          return entry.sender_id, entry.message, entry.protocol
        end
      end

      return nil
    end,
  }
end

function M.restore()
  _G.fs = original.fs
  _G.os = original.os
  _G.print = original.print
  _G.rednet = original.rednet
end

function M.setEpoch(epoch)
  currentEpoch = epoch
end

function M.readFile(path)
  return fileContents[normalize(path)]
end

function M.getPrintedLines()
  return copyArray(printedLines)
end

function M.queueRednetReceive(senderId, message, protocol)
  rednetReceives[#rednetReceives + 1] = {
    sender_id = senderId,
    message = message,
    protocol = protocol,
  }
end

function M.getRednetSends()
  return copyArray(rednetSends)
end

function M.getRednetBroadcasts()
  return copyArray(rednetBroadcasts)
end

return M

# `log.lua`

Minimal file-backed logger for ComputerCraft programs.

Source lives at `src/log.lua`.
Tests live under `tst/` and run through `tst/run.lua`.

## Version

- `0.1.0`

## Public API

- `log.config(options?)`
  - With no argument, returns the current config table.
  - With a config table, updates the logger config and returns the resulting config.
- `log.info(fmt, ...)`
  - Writes an `INFO` log entry if the configured level allows it.
- `log.warn(fmt, ...)`
  - Writes a `WARN` log entry if the configured level allows it.
- `log.error(fmt, ...)`
  - Writes an `ERROR` log entry if the configured level allows it.
- `log.panic(fmt, ...)`
  - Writes a `PANIC` log entry, then raises an error with the formatted message.

All log functions accept either:

- a plain value such as `log.info("started")`
- a `string.format` style call such as `log.info("started %s", jobId)`

## Default Config

```lua
{
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
}
```

## Config Options

### `output`

- `file`
  - Log file path relative to the current computer root.
- `level`
  - One of: `"info"`, `"warn"`, `"error"`, `"panic"`.
- `mirror_to_term`
  - `true` to also print written log lines to the terminal.
- `timestamp`
  - `"utc"` for human-readable UTC timestamps.
  - `"epoch"` for raw `os.epoch("utc")` millisecond timestamps.

### `retention`

- `mode`
  - `"none"`: do not trim the log file automatically.
  - `"truncate"`: keep only the newest `max_lines` lines.
- `max_lines`
  - Positive integer used when `mode = "truncate"`.

## Example

```lua
local log = require("log")

log.config({
  output = {
    file = "var/app.log",
    level = "warn",
    mirror_to_term = false,
    timestamp = "utc",
  },
  retention = {
    mode = "truncate",
    max_lines = 500,
  },
})

log.info("This will be skipped")
log.warn("Station %s is stale", "WH_EAST")
log.error("Failed to assign %s", "minecraft:iron_ingot")
```

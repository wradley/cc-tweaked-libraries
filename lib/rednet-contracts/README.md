# `rednet_contracts`

Shared rednet discovery and RPC contract helpers for ComputerCraft programs.

Source lives at `src/rednet_contracts/`.
Tests live under `tst/` and run through `tst/run.lua`.

## Version

- `0.1.0`

## Scope

This library implements the initial contract surface from `AGENTS/specs/07-rednet-contracts.md`:

- generic discovery heartbeat validation/building and rednet helpers
- common RPC request/response envelope validation/building and rednet helpers
- structured error helpers for non-success RPC responses
- service-specific validation/building for:
  - `warehouse_v1`
  - `global_inventory_v1`

## Public API

- `require("rednet_contracts")`
  - Returns the package table with:
    - `VERSION`
    - `errors`
    - `discovery_v1`
    - `warehouse_v1`
    - `global_inventory_v1`

Service modules expose:

- `config(options?)`
- high-level request helpers such as `getOwner(...)`, `setOwner(...)`, `getSnapshot(...)`, and `pauseSync(...)`
- `receiveRequest(...)`
- `replySuccess(...)`
- `replyError(...)`

`receiveRequest(...)` returns a service-level request object with `request_id`,
`method`, and `params`, rather than exposing the raw MRPC envelope.

### Validation style

Validators return:

```lua
true
```

on success, or:

```lua
false, {
  code = "...",
  message = "...",
  details = {
    path = "...",
  },
}
```

on failure.

Builder and rednet transport helpers validate inputs and raise an error if the payload is invalid.

Internal modules such as `rednet_contracts.mrpc_v1` and `rednet_contracts.schema_validation`
still exist for library internals and focused tests, but the intended application-facing API is
the root package plus the service modules it exposes.

## Example

```lua
local contracts = require("rednet_contracts")

contracts.discovery_v1.broadcast({
  device_id = "warehouse-east",
  device_type = "warehouse_controller",
  sent_at = os.epoch("utc"),
  protocols = {
    { name = "warehouse", version = 1, role = "server" },
  },
})

contracts.warehouse_v1.config({
  timeout = 2,
})

local snapshot, err = contracts.warehouse_v1.getSnapshot(17)

if not snapshot then
  error(contracts.errors.format(err), 0)
end
```

# `rednet_contracts`

Shared rednet discovery and RPC contract helpers for ComputerCraft programs.

Source lives at `src/rednet_contracts/`.
Tests live under `tst/` and run through `tst/run.lua`.

## Version

- `0.1.1`

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

High-level call helpers now use named LuaDoc result types such as:

- `WarehouseGetOwnerResult`
- `WarehouseGetOverviewResult`
- `WarehouseGetSnapshotResult`
- `WarehouseSetOwnerResult`
- `WarehouseAssignTransferRequestResult`
- `WarehouseGetTransferRequestStatusResult`

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

## Examples

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

### `warehouse_v1.get_owner()`

Request:

```lua
{}
```

Success result:

```lua
{
  warehouse_id = "west",
  warehouse_address = "WH_WEST",
  owner = {
    coordinator_id = "central",
    coordinator_address = "central",
    claimed_at = 1742430000000,
  },
  observed_at = 1742430005000,
}
```

### `warehouse_v1.get_transfer_request_status()`

Request:

```lua
{
  transfer_request_id = "west:2:64:123456",
}
```

Success result:

```lua
{
  warehouse_id = "west",
  warehouse_address = "WH_WEST",
  transfer_request_id = "west:2:64:123456",
  status = "queued",
  executed_at = 1742430010000,
  total_assignments = 2,
  total_items_requested = 64,
  total_items_queued = 64,
  assignments = {
    {
      assignment_id = "assign-1",
      destination = "east",
      destination_address = "WH_EAST",
      line_count = 2,
      requested_items = 32,
      queued_items = 32,
      status = "queued",
    },
  },
  packages = {
    ["in"] = {},
    ["out"] = {
      "123-1-1",
      "123-1-2",
    },
  },
  sent_at = 1742430012000,
}
```

Package ids are expected to use Create order data in the form
`orderId-linkIndex-index` when order data is present on the package object.

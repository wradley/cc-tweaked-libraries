# Warehouse Notes

This computer is a warehouse controller in the coordinator sync system.

Its job is to:

1. publish heartbeats
2. answer targeted snapshot requests
3. receive and execute assignment batches
4. report assignment execution and train departures

## Filesystem layout

- `startup.lua`: root entrypoint used by the ComputerCraft computer
- `src/app/`: controller orchestration, snapshot building, and execution flow
- `src/model/`: validated warehouse config
- `src/infra/`: persistence, network, and peripheral-boundary code
- `src/ui/`: terminal UI
- `src/util/`: small shared helpers
- `src/deps/`: vendored runtime dependencies such as logging
- `install/`: installer, manifest, and config template for this program
- `/etc/wh-controller/config.lua`: machine-local warehouse config when installed
- `/var/wh-controller/`: persisted batch/execution state and warehouse log output when installed
- `tst/`: warehouse tests and test-only dependencies

## Network flow

```text
computer/0 coordinator                        computer/2 warehouse
----------------------                        --------------------

heartbeat <---------------------------------- heartbeat broadcast

get_snapshot --------------------------------> reconcile local batch state
                                             -> rebuild local snapshot
snapshot <----------------------------------- targeted snapshot reply

(on release only)
assignment_batch ----------------------------> persist batch
                                             -> execute batch
assignment_ack <----------------------------- acknowledge receipt
assignment_execution <----------------------- report queued work

train_departure_notice <--------------------- report post-execution departures
```

`get_snapshot` is the ongoing reconciliation path.

If the coordinator includes no active batch, or a different active batch id,
the warehouse clears stale persisted local assignment state before replying.

## Current behavior

- batches execute automatically when an `assignment_batch` arrives
- the UI may show `(persisted)` on restored batch or execution state after boot
- the next `get_snapshot` can clear that restored state if the coordinator says no active batch exists
- train departures are reported back to the coordinator only for the configured export station
- when installed through the versioned launcher flow, config loads from `/etc/wh-controller/config.lua`
- persisted assignment state and logs are written under `/var/wh-controller/`
- startup fails loudly if `/etc/wh-controller/config.lua` is missing

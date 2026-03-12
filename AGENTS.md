# AGENTS.md

This directory is a `computercraft` save folder for a local Minecraft world using CC:Tweaked.

## What this directory contains

- `computer/<id>/` holds the filesystem for each in-game computer.
- `ids.json` tracks the next assigned IDs for ComputerCraft object types.
- `_docs/` contains local reference documentation for CC:Tweaked and Create integration on Minecraft 1.21.x.
- Files inside a given `computer/<id>/` directory are the programs and data stored on that specific in-game computer.

Current observed layout:

- `computer/0/test.lua`
- `ids.json` currently shows `"computer": 0`
- `_docs/CC-Tweaked/` includes local CC:Tweaked docs, guides, events, references, and Lua stubs.
- `_docs/Create-cc-tweaked-integration/` includes local Create integration peripheral and train/logistics docs.

## How to work here

- Do not assume which computer to edit.
- Wait for the user to specify a target computer ID under `./computer/`.
- Once the user picks an ID, treat `./computer/<id>/` as that machine's root filesystem.
- Keep edits scoped to the selected computer unless the user explicitly asks for broader world-level changes.
- Before implementing CC:Tweaked or Create integration code, load the relevant files from `_docs/` into working context.

## Conventions

- Prefer preserving normal ComputerCraft conventions such as `startup.lua`, small Lua utilities, and plain-text data files when appropriate.
- Be careful with relative paths: code running on one in-game computer only sees that computer's own filesystem, not sibling `computer/<other-id>/` directories.
- Avoid changing `ids.json` unless the task is specifically about world/save metadata.
- Prefer local docs in `_docs/` over memory when answering API questions or writing integration code for this world.
- For Create train/logistics automation, check the specific peripheral page first, such as `train/train-station.md` or the relevant logistics page.
- If a task depends on exact peripheral methods, events, or schedule formats, cite or consult the matching local markdown doc before editing code.
- For required peripherals, required config, and required API methods, prefer loud failures over silent fallbacks so errors surface directly in-game.
- Avoid wrapping required library or peripheral calls in `pcall` just to keep the program limping along; reserve `pcall` for genuinely expected failures such as probing out-of-range slots.

## Spec Organization

- Prefer a spec directory such as `./_SPEC/` over a single top-level spec file when planning has more than one active or future phase.
- Use numbered markdown files to keep planning ordered and easy to prune.
- The default layout is:
  - `00-overview.md` for current scope, boundaries, and design principles.
  - `01-*.md`, `02-*.md`, and so on for active or upcoming phases.
  - `99-tbd.md` for deferred ideas and future possibilities.
- Keep a short status marker for each phase file in `00-overview.md`, such as `[in progress]`, `[not started]`, or `[done]`.
- Keep spec files short, current, and decision-oriented.
- Treat spec docs as active planning artifacts, not historical records.

## Spec Maintenance

- Periodically clean up spec content as work progresses.
- Remove completed phase files once they are no longer useful for active planning.
- Delete obsolete, superseded, or already-implemented information instead of letting it accumulate.
- Fold still-relevant details forward into the current overview or next active phase rather than keeping stale notes around.
- Do not let spec files turn into changelogs, exhaustive implementation trackers, or archives of abandoned ideas.

## Collaboration note

If the user says "work on computer 12", that means files should be created or edited under `./computer/12/`.

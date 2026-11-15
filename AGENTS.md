# Agent notes

## Versioning

- **Bump `VERSION` whenever you change the mod** (Papyrus, ESP, or SKSE UI). Every build that may go into the game gets a new version; `TrainingDummyUI.log` and the menu status line show it.
- The format is `<major>.<feature>.<patch>`:
  - **major** only for breaking changes, and only when the user asks.
  - **feature** for a genuinely new feature; reset patch to 0.
  - **patch** for fixes and tweaks to existing behavior.
- `VERSION` is the only place the version lives. The SKSE DLL embeds it via CMake.

## Building

- **Install with `make live`** (plain `make` does the same). It builds the SKSE DLL, compiles Papyrus, regenerates the ESP, and copies into the game's `Data` folder.
- Skyrim locks `TrainingDummyUI.dll` (and the ESP) while it runs. `make live` exits with a quit message if the DLL is locked — ask the user to quit to desktop, then retry.
- Needs `VCPKG_ROOT` (same as Magic Tattoos UI). Optional `build.local.sh` for path overrides.
- The C++ build tree lives on `G:/CursorBuilds/skyrim-training-dummy-ui/` (M: is often full). Override with `TDUI_BUILD_DIR` if needed.
- Keep the mod disabled in Vortex while using `live`, or a Vortex deploy overwrites the live files.

## Layout

- Papyrus + Mutagen ESP: repo root (`Scripts/`, `tools/PluginGen/`)
- SKSE Menu Framework UI: `skse/` → `TrainingDummyUI.dll`
- FormIDs are stable (`0x800` quest, `0x801`/`0x802` NPCs, `0x808`/`0x80A`/`0x80C` spells). Never move them.

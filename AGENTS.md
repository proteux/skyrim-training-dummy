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
- `make package` writes the Nexus zip under `dist/` (includes `LICENSE.txt` / `README.txt` under `SKSE/Plugins/TrainingDummyUI`).
- Skyrim locks `TrainingDummyUI.dll` (and the ESP) while it runs. `make live` exits with a quit message if the DLL is locked — ask the user to quit to desktop, then retry.
- Needs `VCPKG_ROOT` (same as Magic Tattoos UI). Optional `build.local.sh` for path overrides.
- The C++ build tree lives on `G:/CursorBuilds/skyrim-training-dummy-ui/` (M: is often full). Override with `TDUI_BUILD_DIR` if needed.
- Keep the mod disabled in Vortex while using `live`, or a Vortex deploy overwrites the live files.

## Layout

- Papyrus + Mutagen ESP: repo root (`Scripts/`, `tools/PluginGen/`)
- SKSE Menu Framework UI: `skse/` → `TrainingDummyUI.dll`
- FormIDs are stable (`0x800` quest; male NPCs `0x801`/`0x805`/`0x806`; female NPCs `0x802`/`0x80D`/`0x80E`; `0x803` hostile faction, `0x804` Acquaintance safe/crime-immune faction, `0x80F` hostile pack Ally faction, `0x810` Friend+ Ally-to-player faction, `0x811` Friend+ pack Ally faction, `0x808`/`0x80A`/`0x80C` spells). Never move them. Hostile+Pack and Friend+FriendPack are Enemy to each other (Cast an aura same-side filter). One ActorBase per slot so outfits (Dress Up Lover’s, etc.) stay independent. Quest aliases 0–2 are male slots, 3–5 female (cap 3 per gender); hit log tags are M1–M3 / F1–F3.

# Training Dummy

Personal test dummy for Magic Tattoos (Hex damage, hit logging, tattoos). Immortal (Essential + bleedout heal), non-hostile, configurable level and health. Male base is Alvor; female is EncBandit Nord. Both use RaceMenu FaceGen heads and spawn in bandit gear. One of each can be out at the same time.

## Requirements

- Skyrim SE/AE with SKSE
- [SKSE Menu Framework](https://www.nexusmods.com/skyrimspecialedition/mods/96817) (for the UI)

## Install

```
cd "/m/Repositories/personal (github)/skyrim-training-dummy"
make live
```

Needs `VCPKG_ROOT` set (same toolchain as Magic Tattoos UI). Enable `PTX_TrainingDummy.esp` in Vortex (F5 if it is not listed). Restart Skyrim. The quest adds the three spells on first load; the DLL registers under **Mod Control Panel → Training Dummy**.

## Use

### Spells

- **Summon Male / Female Training Dummy** — places the dummy in front of you. Replacing summons only that gender.
- **Dismiss Training Dummy** — removes both.

### SKSE UI

Open the Mod Control Panel (default hotkey from Menu Framework) → **Training Dummy**, or open the standalone window from the section.

- Summon / dismiss / add or remove spells / heal now
- **Match player level** (default on), or set a fixed level
- **Health per level** (default **50**): max HP = level × this
- **vs player** relationship (default Lover): set **Enemy** or **Archnemesis** so harmful Spell auras hit them (`IsHostileToActor` via a custom faction that’s only enemy to the player). Hitting or hexing a dummy does not report as assault, so town guards stay out of it; dummies stay Unaggressive.
- Rolling combat log with 5s / 10s DPS
- Mute hit notifications (default on; hits still go to the log)

Settings: `Data/SKSE/Plugins/TrainingDummyUI/settings.json`. Changing **Pause game while window open** needs a Skyrim restart (registration-time flag).

Each hit is also appended to:

`Documents/My Games/Skyrim Special Edition/Logs/Script/User/TrainingDummy.log`

SKSE plugin log:

`Documents/My Games/Skyrim Special Edition/SKSE/TrainingDummyUI.log`

The dummy keeps AI on but cannot walk (`SetDontMove`), so RaceMenu / MTF tattoo overlays can redraw. Bandit gear is in their inventory (not an outfit). With **Enemy** or **Archnemesis**, harmful MTF Spell auras that check `IsHostileToActor` hit them; other ranks stay friendly for blessing-style tests.

## Faces

RaceMenu Sculpt → Export Head as `Male_Dummy` / `Female_Dummy` into `Data/SKSE/Plugins/CharGen/`.

`make live` runs `tools/sync_facegen.py`, which copies into FaceGen FormIDs `00000801` (male) and `00000802` (female).

## Build notes

- Mutagen `tools/PluginGen`, Papyrus under `Scripts/Source`, SKSE UI under `skse/`
- `make live` installs into `SKYRIM_DIR` (default Steam SSE path)
- Override with `SKYRIM_DIR`, `PAPYRUS_COMPILER`, `PLUGINS_TXT`, or `VCPKG_ROOT`

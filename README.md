# Training Dummy

Personal test dummy for Magic Tattoos (Hex damage, hit logging, tattoos). Optionally immortal (Essential + bleedout) or mortal (die + Resurrect), non-hostile, configurable level and health. Both male and female use EncBandit Nord bases — one ActorBase per slot (three of each gender) so outfit changers like Dress Up Lover’s can give each dummy its own gear that persists across dismiss/summon. Female uses a RaceMenu FaceGen head (same export copied to all three female FormIDs for now); male keeps the EncBandit default head. Bases keep the template outfit / keywords so SPID and outfit distributors can dress them.

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

- **Summon Male / Female Training Dummy** — places another dummy in front of you (up to 3 per gender; when full, replaces the next slot, preferring dead ones).
- **Dismiss Training Dummy** — removes all live dummies.

### SKSE UI

Open the Mod Control Panel (default hotkey from Menu Framework) → **Training Dummy**, or open the standalone window from the section.

- Summon / dismiss / heal now (add or remove spells from the Mod Control Panel section)
- **Match player level** (default on), or set a fixed level — under **Summon settings** in the standalone window
- **Health per level** (default **50**): max HP = level × this
- **Start at % HP** (default **100**): current HP on summon / when settings reapply; use a lower value to test healing auras. Out-of-combat HealRate (~0.7% max/s) is stripped from poll ticks so that value sticks; OnHit and Cast an aura / CastAs heals keep the rest. Use Ally/Friend rank for auras on the player (helpful or harmful — both hit the wearer's side; MTF Plugin - Skyrim 0.3.7+). **Heal now** still fills to 100%
- **Immortal** (default on): Essential kneel + heal; off = die and Resurrect after the down timer
- **Down time** (default **10** s): seconds down after bleedout / death before full recovery (0 = stay down until **Heal now**)
- **vs player** relationship (default Lover): two separate packs. Friend+ are Ally to each other and to you. Rival / Enemy / Archnemesis are Ally to each other and Enemy to you — and Enemy to Friend+ dummies (so a harmful Cast an aura hex on Rival+ only burns that pack, not Lover dummies). **Acquaintance** is in neither pack. Hitting or hexing a dummy does not report as assault, so town guards stay out of it; dummies stay Unaggressive. Cast an aura damage is logged even without a weapon/spell OnHit (`hit target=M1 dmg=…`).
- Rolling combat log with 5s / 10s DPS and HPS graphs (aura heals included), clear, and copy to clipboard
- Hit notifications stay muted by default (hits still go to the log; change `muteNotifications` in settings.json if needed)

Settings: `Data/SKSE/Plugins/TrainingDummyUI/settings.json`. Changing **Pause game while window open** needs a Skyrim restart (registration-time flag).

Each hit is also appended to:

`Documents/My Games/Skyrim Special Edition/Logs/Script/User/TrainingDummy.log`

SKSE plugin log:

`Documents/My Games/Skyrim Special Edition/SKSE/TrainingDummyUI.log`

The dummy keeps AI on but cannot walk (`SetDontMove`), so RaceMenu / MTF tattoo overlays can redraw. Gear comes from each slot’s NPC `DefaultOutfit` plus whatever SPID / outfit distributors match; factions stay script-controlled so guards stay out. Rival+ get Hostile+Pack (Ally within that pack; crime-immune flags on those factions). Friend+ get Friend+FriendPack (Ally within that pack and to you). The two packs are Enemy to each other. **Acquaintance** gets SafeFaction only.

## Faces

Female: RaceMenu Sculpt → Export Head as `Female_Dummy` into `Data/SKSE/Plugins/CharGen/`.
`make live` runs `tools/sync_facegen.py`, which copies that head to FaceGen FormIDs `00000802`, `0000080D`, and `0000080E` (all three female slots).

Male: no FaceGen override — uses the EncBandit Nord default head.

## Build notes

- Mutagen `tools/PluginGen`, Papyrus under `Scripts/Source`, SKSE UI under `skse/`
- `make live` installs into `SKYRIM_DIR` (default Steam SSE path)
- `make package` writes `dist/PTX_TrainingDummy-<version>.zip` for Nexus
- Override with `SKYRIM_DIR`, `PAPYRUS_COMPILER`, `PLUGINS_TXT`, or `VCPKG_ROOT`

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [`LICENSE`](LICENSE) for the full text of the GPL-3.0.

The release zip includes the license and this notice as `SKSE/Plugins/TrainingDummyUI/LICENSE.txt` and `README.txt`.

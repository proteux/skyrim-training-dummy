# Training Dummy

Personal test dummy for Magic Tattoos (Hex damage, hit logging, tattoos). Immortal (Essential + bleedout heal), non-hostile, configurable level and health. Both male and female use EncBandit Nord bases. Female uses a RaceMenu FaceGen head; male keeps the EncBandit default head (skin matches the body). Both keep the template outfit / keywords so SPID and outfit distributors can dress them. Up to three of each gender can be out at the same time.

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

- **Summon Male / Female Training Dummy** — places another dummy in front of you (up to 3 per gender; refuses when full).
- **Dismiss Training Dummy** — removes all live dummies.

### SKSE UI

Open the Mod Control Panel (default hotkey from Menu Framework) → **Training Dummy**, or open the standalone window from the section.

- Summon / dismiss / heal now (add or remove spells from the Mod Control Panel section)
- **Match player level** (default on), or set a fixed level — under **Summon settings** in the standalone window
- **Health per level** (default **50**): max HP = level × this
- **Start at % HP** (default **100**): current HP on summon / when settings reapply; use a lower value to test healing auras. Out-of-combat HealRate (~0.7% max/s) is stripped from poll ticks so that value sticks; OnHit and Cast an aura / CastAs heals keep the rest. Use Ally/Friend rank for auras on the player (helpful or harmful — both hit the wearer's side; MTF Plugin - Skyrim 0.3.7+). **Heal now** and bleedout still fill to 100%
- **vs player** relationship (default Lover): Ally/Friend dummies share your side, so a Flames or Healing aura on you hits them. Use **Enemy** or **Archnemesis** as hex targets (and park another Enemy nearby) to test a harmful hex aura burning the wearer's friends. Hitting or hexing a dummy does not report as assault, so town guards stay out of it; dummies stay Unaggressive. Cast an aura damage is logged even without a weapon/spell OnHit.
- Rolling combat log with 5s / 10s DPS and HPS graphs (aura heals included), clear, and copy to clipboard
- Hit notifications stay muted by default (hits still go to the log; change `muteNotifications` in settings.json if needed)

Settings: `Data/SKSE/Plugins/TrainingDummyUI/settings.json`. Changing **Pause game while window open** needs a Skyrim restart (registration-time flag).

Each hit is also appended to:

`Documents/My Games/Skyrim Special Edition/Logs/Script/User/TrainingDummy.log`

SKSE plugin log:

`Documents/My Games/Skyrim Special Edition/SKSE/TrainingDummyUI.log`

The dummy keeps AI on but cannot walk (`SetDontMove`), so RaceMenu / MTF tattoo overlays can redraw. Gear comes from the NPC `DefaultOutfit` plus whatever SPID / outfit distributors match; factions stay script-controlled so guards stay out. Ally/Friend ranks share the player's side for Cast an aura worn by you; Enemy/Archnemesis are for hex targets and same-side neighbour checks between dummies.

## Faces

Female: RaceMenu Sculpt → Export Head as `Female_Dummy` into `Data/SKSE/Plugins/CharGen/`.
`make live` runs `tools/sync_facegen.py`, which copies into FaceGen FormID `00000802`.

Male: no FaceGen override — uses the EncBandit Nord default head.

## Build notes

- Mutagen `tools/PluginGen`, Papyrus under `Scripts/Source`, SKSE UI under `skse/`
- `make live` installs into `SKYRIM_DIR` (default Steam SSE path)
- Override with `SKYRIM_DIR`, `PAPYRUS_COMPILER`, `PLUGINS_TXT`, or `VCPKG_ROOT`

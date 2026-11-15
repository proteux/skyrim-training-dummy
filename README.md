# Training Dummy

Personal test dummy for Magic Tattoos (Hex damage, hit logging). Immortal, non-hostile, matches the player level. Male and female bandit looks. At most one in the world.

## Requirements

- Skyrim SE/AE with SKSE

## Install

```
cd "G:/Skyrim Tools/training-dummy"
make live
```

Enable `PTX_TrainingDummy.esp` in Vortex (F5 if it is not listed). Restart Skyrim. The quest adds all three spells on first load.

## Use

- **Summon Male Training Dummy** — cast on yourself; places the dummy in front of you. Replaces any existing dummy.
- **Summon Female Training Dummy** — same, female bandit.
- **Dismiss Training Dummy** — removes the current dummy.

Each hit is appended to a user log (also a short on-screen notification):

`Documents/My Games/Skyrim Special Edition/Logs/Script/User/TrainingDummy.log`

Lines look like `hit dmg=47 source=Firebolt aggressor=...`, with `--- summon level=N ---` / `--- dismiss ---` markers. Paste that file (or a slice of it) when comparing Firebolt vs Hex.

Harmful MTF spell auras that require hostility will not hit this dummy; use a real enemy bandit for those.

## Build notes

Same layout as the Sanguine's Trade converter: Mutagen `tools/PluginGen`, Papyrus under `Scripts/Source`, `make live` installs into `SKYRIM_DIR` (default Steam SSE path). Override with `SKYRIM_DIR`, `PAPYRUS_COMPILER`, or `PLUGINS_TXT`. PluginGen reads `Skyrim.esm` to clone the bandit templates.

# Training Dummy

Personal test dummy for Magic Tattoos (Hex damage, hit logging, tattoos). Immortal, non-hostile, matches the player level. Male and female bandit looks. At most one in the world.

## Requirements

- Skyrim SE/AE with SKSE

## Install

```
cd "/m/Repositories/personal (github)/skyrim-training-dummy"
make live
```

Enable `PTX_TrainingDummy.esp` in Vortex (F5 if it is not listed). Restart Skyrim. The quest adds all three spells on first load.

## Use

- **Summon Male Training Dummy** — cast on yourself; places the dummy in front of you, facing you. Replaces any existing dummy.
- **Summon Female Training Dummy** — same, female bandit.
- **Dismiss Training Dummy** — removes the current dummy.

The dummy keeps AI on but cannot walk (`SetDontMove`), so RaceMenu / MTF tattoo overlays can redraw. Bandit gear is in their inventory (not an outfit), so you can pickpocket it off or reverse-pickpocket new clothes on. Undress the chest to see body tattoos. Keywords are cleared so outfit distributors (e.g. SPID) do not force unpickable armor onto them.

Each hit is appended to a user log (also a short on-screen notification):

`Documents/My Games/Skyrim Special Edition/Logs/Script/User/TrainingDummy.log`

Lines look like `hit dmg=47 source=Firebolt aggressor=...`, with `--- summon level=N ---` / `--- dismiss ---` markers. Paste that file (or a slice of it) when comparing Firebolt vs Hex.

Harmful MTF spell auras that require hostility will not hit this dummy; use a real enemy bandit for those.

## Face (female)

RaceMenu CharGen export lives in the repo as FaceGen for `PTX_TrainingDummyFemale` (`0x802`):

- `Data/meshes/actors/character/FaceGenData/FaceGeom/PTX_TrainingDummy.esp/00000802.nif`
- `Data/textures/actors/character/FaceGenData/FaceTint/PTX_TrainingDummy.esp/00000802.dds`

`make live` copies those into the game Data folder. Source export was `Data/SKSE/Plugins/CharGen/Female_Dummy.*`. If the face is dark or wrong in game, a CK Ctrl+F4 + NPC Nif Merge pass is the usual fix; without CK this is a direct CharGen install.

## Build notes

Mutagen `tools/PluginGen`, Papyrus under `Scripts/Source`, `make live` installs into `SKYRIM_DIR` (default Steam SSE path). Override with `SKYRIM_DIR`, `PAPYRUS_COMPILER`, or `PLUGINS_TXT`. PluginGen reads `Skyrim.esm` to clone the bandit templates.

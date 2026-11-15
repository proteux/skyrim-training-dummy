# Training Dummy

Personal test dummy for Magic Tattoos (Hex damage, hit logging, tattoos). Immortal, non-hostile, matches the player level. Male base is Alvor; female is EncBandit Nord (Ysolda clones blacked out the undressed CBBE body). Both use RaceMenu FaceGen heads and spawn in bandit gear. One of each can be out at the same time; summoning again replaces only that gender.

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
- **Summon Female Training Dummy** — same, female.
- **Dismiss Training Dummy** — removes both dummies.

The dummy keeps AI on but cannot walk (`SetDontMove`), so RaceMenu / MTF tattoo overlays can redraw. Bandit gear is in their inventory (not an outfit), so you can pickpocket it off or reverse-pickpocket new clothes on. Undress the chest to see body tattoos. Keywords are cleared so outfit distributors (e.g. SPID) do not force unpickable armor onto them.

Each hit is appended to a user log (also a short on-screen notification):

`Documents/My Games/Skyrim Special Edition/Logs/Script/User/TrainingDummy.log`

Lines look like `hit dmg=47 source=Firebolt aggressor=...`, with `--- summon level=N ---` / `--- dismiss ---` markers. Paste that file (or a slice of it) when comparing Firebolt vs Hex.

Harmful MTF spell auras that require hostility will not hit this dummy; use a real enemy bandit for those.

## Faces

RaceMenu Sculpt → Export Head as `Male_Dummy` / `Female_Dummy` into `Data/SKSE/Plugins/CharGen/`.

`make live` runs `tools/sync_facegen.py`, which:

- copies the `.nif`/`.dds` into FaceGen FormIDs `00000801` (male) and `00000802` (female)
- also writes `CharGen/<name>.nif.dds` (the tint path embedded in RaceMenu nifs)

Starting gear omits the bandit helmet so KS hair from the export stays visible.

## Build notes

Mutagen `tools/PluginGen`, Papyrus under `Scripts/Source`, `make live` installs into `SKYRIM_DIR` (default Steam SSE path). Override with `SKYRIM_DIR`, `PAPYRUS_COMPILER`, or `PLUGINS_TXT`. PluginGen clones Alvor / EncBandit01Melee1HNordF from `Skyrim.esm`, then clears factions, tint layers, and outfits.

// Generates PTX_TrainingDummy.esp (light plugin):
// quest+alias, male/female EncBandit Nord NPCs, self-cast summon/dismiss spells.
// FormIDs 0x800 up. Masters: Skyrim.esm only.
//
// Usage: PluginGen --out <path/To/PTX_TrainingDummy.esp>
// Optional: --skyrim-data <Skyrim Data folder> (default Steam SSE path / SKYRIM_DIR/Data)
using Mutagen.Bethesda;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Plugins.Binary.Parameters;
using Mutagen.Bethesda.Plugins.Records;
using Mutagen.Bethesda.Skyrim;

var options = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
for (var i = 0; i + 1 < args.Length; i += 2)
{
    if (!args[i].StartsWith("--"))
        throw new ArgumentException($"Unexpected argument '{args[i]}'.");
    options[args[i][2..]] = args[i + 1];
}
if (!options.TryGetValue("out", out var outputPath) || string.IsNullOrWhiteSpace(outputPath))
    throw new ArgumentException("Missing --out <path>.");
outputPath = Path.GetFullPath(outputPath);

var skyrimData = options.GetValueOrDefault("skyrim-data");
if (string.IsNullOrWhiteSpace(skyrimData))
{
    var skyrimDir = Environment.GetEnvironmentVariable("SKYRIM_DIR");
    skyrimData = string.IsNullOrWhiteSpace(skyrimDir)
        ? @"C:\Program Files (x86)\Steam\steamapps\common\Skyrim Special Edition\Data"
        : Path.Combine(skyrimDir, "Data");
}
var skyrimEsmPath = Path.Combine(skyrimData, "Skyrim.esm");
if (!File.Exists(skyrimEsmPath))
    throw new FileNotFoundException($"Skyrim.esm not found at {skyrimEsmPath}. Pass --skyrim-data.");

var modKey = ModKey.FromFileName(Path.GetFileName(outputPath));
var mod = new SkyrimMod(modKey, SkyrimRelease.SkyrimSE);
var skyrim = ModKey.FromFileName("Skyrim.esm");
var eitherHand = new FormKey(skyrim, 0x13F44);

FormKey F(uint id) => new(modKey, id);

using var skyrimMod = SkyrimMod.CreateFromBinaryOverlay(skyrimEsmPath, SkyrimRelease.SkyrimSE);

Npc MakeDummy(string templateEditorId, FormKey formKey, string editorId)
{
    var src = skyrimMod.Npcs.FirstOrDefault(n => n.EditorID == templateEditorId)
        ?? throw new InvalidOperationException($"Missing template NPC {templateEditorId} in Skyrim.esm");
    var npc = src.Duplicate(formKey);
    npc.EditorID = editorId;
    // Fallback only — summon sets a per-slot spelling via TrainingDummyUI.SetDisplayName.
    npc.Name = "Training Dummy";
    npc.Template.Clear();
    npc.Configuration.TemplateFlags = 0;
    npc.Configuration.Flags &= ~(NpcConfiguration.Flag.Respawn
        | NpcConfiguration.Flag.Invulnerable
        | NpcConfiguration.Flag.IsGhost
        | NpcConfiguration.Flag.Summonable);
    // One live instance per base (slot). Not Unique — PlaceActorAtMe + Delete.
    npc.Configuration.Flags |= NpcConfiguration.Flag.Essential
        | NpcConfiguration.Flag.DoesntAffectStealthMeter;
    // EncBandit templates are lv1 — keep all bases equal before runtime level.
    // Runtime TrainingDummyUI.SetActorLevel overwrites this to the UI level.
    npc.Configuration.Level = new NpcLevel { Level = 1 };
    npc.Configuration.CalcMinLevel = 0;
    npc.Configuration.CalcMaxLevel = 0;
    // Factions stay empty: runtime SafeFaction / HostileFaction only (guards stay out).
    npc.Factions.Clear();
    npc.Packages.Clear();
    // Keep template keywords + DefaultOutfit so SPID / outfit distributors can dress
    // them from the load order. Class is left as-duplicated for Class filters.
    KeepSkinToneTintsOnly(npc);
    // Match typical RaceMenu export weight so FaceGen necks line up better.
    npc.Weight = 100f;
    // Outfit on the base; clear loose Items so they don't stack with the outfit.
    npc.Items?.Clear();
    return npc;
}

// Drop dirt / warpaint / makeup; keep race SkinTone so the EncBandit head
// still matches other bandits (and our body) instead of going untinted.
void KeepSkinToneTintsOnly(Npc npc)
{
    if (npc.TintLayers is not { Count: > 0 } layers)
        return;

    var race = skyrimMod.Races.FirstOrDefault(r => r.FormKey == npc.Race.FormKey)
        ?? throw new InvalidOperationException($"Missing race {npc.Race.FormKey} for tint filter.");
    var female = npc.Configuration.Flags.HasFlag(NpcConfiguration.Flag.Female);
    var head = female ? race.HeadData?.Female : race.HeadData?.Male;
    if (head is null)
        return;

    var skinIndexes = head.TintMasks
        .Where(m => m.MaskType == TintAssets.TintMaskType.SkinTone && m.Index is not null)
        .Select(m => m.Index!.Value)
        .ToHashSet();
    var before = layers.Count;
    layers.RemoveAll(l => l.Index is not { } idx || !skinIndexes.Contains(idx));
    Console.WriteLine($"  tint filter {npc.EditorID}: {before} -> {layers.Count} (kept SkinTone only)");
}

Npc TuneAi(Npc npc)
{
    npc.AIData ??= new AIData();
    npc.AIData.Aggression = Aggression.Unaggressive;
    npc.AIData.Confidence = Confidence.Average;
    npc.AIData.Assistance = Assistance.HelpsNobody;
    npc.AIData.Mood = Mood.Neutral;
    return npc;
}

// --- Quest 0x800 (aliases 0-2 male, 3-5 female; up to 3 of each) ---
var quest = new Quest(F(0x800), SkyrimRelease.SkyrimSE)
{
    EditorID = "PTX_TrainingDummyQuest",
    Name = "Training Dummy",
    Flags = Quest.Flag.StartGameEnabled,
    NextAliasID = 6,
};
for (uint i = 0; i < 3; ++i)
{
    quest.Aliases.Add(new QuestAlias
    {
        ID = i,
        Name = $"MaleDummy{i}",
        Flags = QuestAlias.Flag.Optional | QuestAlias.Flag.AllowReuseInQuest,
    });
}
for (uint i = 0; i < 3; ++i)
{
    quest.Aliases.Add(new QuestAlias
    {
        ID = 3 + i,
        Name = $"FemaleDummy{i}",
        Flags = QuestAlias.Flag.Optional | QuestAlias.Flag.AllowReuseInQuest,
    });
}

var questAdapter = new QuestAdapter { Version = 5, ObjectFormat = 2 };
var questScript = new ScriptEntry
{
    Name = "PTX_TrainingDummyQuest",
    Flags = ScriptEntry.Flag.Local,
};
void AddAliasProp(string name, int aliasId)
{
    questScript.Properties.Add(new ScriptObjectProperty
    {
        Name = name,
        Flags = ScriptProperty.Flag.Edited,
        Object = new FormLink<ISkyrimMajorRecordGetter>(quest.FormKey),
        Alias = (short)aliasId,
    });
}
AddAliasProp("MaleAlias0", 0);
AddAliasProp("MaleAlias1", 1);
AddAliasProp("MaleAlias2", 2);
AddAliasProp("FemaleAlias0", 3);
AddAliasProp("FemaleAlias1", 4);
AddAliasProp("FemaleAlias2", 5);
questAdapter.Scripts.Add(questScript);

QuestFragmentAlias MakeAliasFrag(int aliasId)
{
    var frag = new QuestFragmentAlias
    {
        Property = new ScriptObjectProperty
        {
            Name = "",
            Object = new FormLink<ISkyrimMajorRecordGetter>(quest.FormKey),
            Alias = (short)aliasId,
        },
    };
    var script = new ScriptEntry
    {
        Name = "PTX_TrainingDummyAlias",
        Flags = ScriptEntry.Flag.Local,
    };
    script.Properties.Add(new ScriptObjectProperty
    {
        Name = "DummyQuest",
        Flags = ScriptProperty.Flag.Edited,
        Object = new FormLink<ISkyrimMajorRecordGetter>(quest.FormKey),
    });
    frag.Scripts.Add(script);
    return frag;
}
for (int i = 0; i < 6; ++i)
{
    questAdapter.Aliases.Add(MakeAliasFrag(i));
}
quest.VirtualMachineAdapter = questAdapter;
mod.Quests.Add(quest);

// --- Factions 0x803 / 0x804 ---
// Crime-ignore flags: hexing / hitting a dummy must not become town assault
// (that turns guards hostile, then a harmful Cast an aura starts hitting them).
var dummyCrimeFlags = Faction.FactionFlag.HiddenFromPC
    | Faction.FactionFlag.IgnoreAssault
    | Faction.FactionFlag.IgnoreMurder
    | Faction.FactionFlag.IgnoreStealing
    | Faction.FactionFlag.IgnoreTrespass
    | Faction.FactionFlag.IgnorePickpocket
    | Faction.FactionFlag.DoNotReportCrimesAgainstMembers;

// 0x803: Enemy rank only — enemy to PlayerFaction so IsHostileToActor works;
// not related to guard/town factions, so guards don't attack the dummy.
var hostileFaction = new Faction(F(0x803), SkyrimRelease.SkyrimSE)
{
    EditorID = "PTX_TrainingDummyHostileFaction",
    Name = "Training Dummy Hostile",
    Flags = dummyCrimeFlags,
};
var playerEnemy = new Relation { Reaction = CombatReaction.Enemy };
playerEnemy.Target.SetTo(new FormKey(skyrim, 0xDB1)); // PlayerFaction
hostileFaction.Relations.Add(playerEnemy);
mod.Factions.Add(hostileFaction);

// 0x804: every dummy, every rank — crime-immune even when not "Enemy".
var safeFaction = new Faction(F(0x804), SkyrimRelease.SkyrimSE)
{
    EditorID = "PTX_TrainingDummyFaction",
    Name = "Training Dummy",
    Flags = dummyCrimeFlags,
};
mod.Factions.Add(safeFaction);

// 0x80F: second pack faction. GetFactionReaction returns Neutral for two actors who
// only share one faction; Ally/Friend need a cross-faction relation. Every dummy is
// in Safe + Pack with Ally both ways, so packmates read as Ally (not town Neutral).
var packFaction = new Faction(F(0x80F), SkyrimRelease.SkyrimSE)
{
    EditorID = "PTX_TrainingDummyPackFaction",
    Name = "Training Dummy Pack",
    Flags = dummyCrimeFlags,
};
var safeAllyPack = new Relation { Reaction = CombatReaction.Ally };
safeAllyPack.Target.SetTo(packFaction.FormKey);
safeFaction.Relations.Add(safeAllyPack);
var packAllySafe = new Relation { Reaction = CombatReaction.Ally };
packAllySafe.Target.SetTo(safeFaction.FormKey);
packFaction.Relations.Add(packAllySafe);
mod.Factions.Add(packFaction);

questScript.Properties.Add(new ScriptObjectProperty
{
    Name = "HostileFaction",
    Flags = ScriptProperty.Flag.Edited,
    Object = new FormLink<ISkyrimMajorRecordGetter>(hostileFaction.FormKey),
});
questScript.Properties.Add(new ScriptObjectProperty
{
    Name = "SafeFaction",
    Flags = ScriptProperty.Flag.Edited,
    Object = new FormLink<ISkyrimMajorRecordGetter>(safeFaction.FormKey),
});
questScript.Properties.Add(new ScriptObjectProperty
{
    Name = "PackFaction",
    Flags = ScriptProperty.Flag.Edited,
    Object = new FormLink<ISkyrimMajorRecordGetter>(packFaction.FormKey),
});

// --- NPCs: one ActorBase per slot (outfit / Dress Up Lover's key off base) ---
// Males 0x801 / 0x805 / 0x806; females 0x802 / 0x80D / 0x80E. Keep 0x801/0x802.
// EncBandit Nord — generic leveled bases so naked/body morph paths work
// (unique named clones like Alvor/Ysolda went solid black when undressed).
// Female FaceGen from CharGen Female_Dummy (copied to all three); male EncBandit head.
Npc[] maleNpcs = [
    TuneAi(MakeDummy("EncBandit01Melee1HNordM", F(0x801), "PTX_TrainingDummyMale0")),
    TuneAi(MakeDummy("EncBandit01Melee1HNordM", F(0x805), "PTX_TrainingDummyMale1")),
    TuneAi(MakeDummy("EncBandit01Melee1HNordM", F(0x806), "PTX_TrainingDummyMale2")),
];
Npc[] femaleNpcs = [
    TuneAi(MakeDummy("EncBandit01Melee1HNordF", F(0x802), "PTX_TrainingDummyFemale0")),
    TuneAi(MakeDummy("EncBandit01Melee1HNordF", F(0x80D), "PTX_TrainingDummyFemale1")),
    TuneAi(MakeDummy("EncBandit01Melee1HNordF", F(0x80E), "PTX_TrainingDummyFemale2")),
];
foreach (var npc in maleNpcs)
    mod.Npcs.Add(npc);
foreach (var npc in femaleNpcs)
    mod.Npcs.Add(npc);

// Self-cast Script effects (Transmute pattern). TargetLocation+explosion never
// fired Papyrus for us; cast-on-self is reliable for a personal tool.
(MagicEffect mgef, Spell spell) MakeSummon(
    FormKey mgefKey, FormKey spellKey, string genderLabel, bool isFemale)
{
    var mgef = new MagicEffect(mgefKey, SkyrimRelease.SkyrimSE)
    {
        EditorID = $"PTX_TrainingDummySummon{genderLabel}MGEF",
        Name = $"Summon {genderLabel} Training Dummy",
        Flags = MagicEffect.Flag.NoMagnitude
            | MagicEffect.Flag.NoArea
            | MagicEffect.Flag.HideInUI
            | MagicEffect.Flag.NoHitEffect,
        MenuDisplayObject = new FormLinkNullable<IStaticGetter>(new FormKey(skyrim, 0x43DF4)),
        MagicSkill = ActorValue.Conjuration,
        CastType = CastType.FireAndForget,
        TargetType = TargetType.Self,
        CastingSoundLevel = SoundLevel.Normal,
        DualCastScale = 1f,
        Archetype = new MagicEffectArchetype
        {
            Type = MagicEffectArchetype.TypeEnum.Script,
            ActorValue = ActorValue.None,
        },
    };
    var adapter = new VirtualMachineAdapter { Version = 5, ObjectFormat = 2 };
    var script = new ScriptEntry
    {
        Name = "PTX_TrainingDummySummon",
        Flags = ScriptEntry.Flag.Local,
    };
    script.Properties.Add(new ScriptObjectProperty
    {
        Name = "DummyQuest",
        Flags = ScriptProperty.Flag.Edited,
        Object = new FormLink<ISkyrimMajorRecordGetter>(quest.FormKey),
    });
    script.Properties.Add(new ScriptBoolProperty
    {
        Name = "IsFemale",
        Flags = ScriptProperty.Flag.Edited,
        Data = isFemale,
    });
    adapter.Scripts.Add(script);
    mgef.VirtualMachineAdapter = adapter;

    var spell = new Spell(spellKey, SkyrimRelease.SkyrimSE)
    {
        EditorID = $"PTX_TrainingDummySummon{genderLabel}",
        Name = $"Summon {genderLabel} Training Dummy",
        Description = $"Places an immortal {genderLabel.ToLowerInvariant()} training dummy in front of you (up to 3; each has its own outfit base).",
        Type = SpellType.Spell,
        CastType = CastType.FireAndForget,
        TargetType = TargetType.Self,
        BaseCost = 0,
        ChargeTime = 0.5f,
        Flags = SpellDataFlag.ManualCostCalc | SpellDataFlag.NoAbsorbOrReflect,
    };
    spell.EquipmentType.SetTo(eitherHand);
    var effect = new Effect
    {
        Data = new EffectData { Magnitude = 0, Area = 0, Duration = 1 },
    };
    effect.BaseEffect.SetTo(mgef.FormKey);
    spell.Effects.Add(effect);
    return (mgef, spell);
}

// Keep spell FormIDs stable from 0.2.x (0x808 / 0x80A / 0x80C).
var (summonMaleMgef, summonMaleSpell) = MakeSummon(F(0x807), F(0x808), "Male", false);
var (summonFemaleMgef, summonFemaleSpell) = MakeSummon(F(0x809), F(0x80A), "Female", true);
mod.MagicEffects.Add(summonMaleMgef);
mod.MagicEffects.Add(summonFemaleMgef);
mod.Spells.Add(summonMaleSpell);
mod.Spells.Add(summonFemaleSpell);

var dismissMgef = new MagicEffect(F(0x80B), SkyrimRelease.SkyrimSE)
{
    EditorID = "PTX_TrainingDummyDismissMGEF",
    Name = "Dismiss Training Dummy",
    Flags = MagicEffect.Flag.NoMagnitude
        | MagicEffect.Flag.NoArea
        | MagicEffect.Flag.HideInUI
        | MagicEffect.Flag.NoHitEffect,
    MagicSkill = ActorValue.Alteration,
    CastType = CastType.FireAndForget,
    TargetType = TargetType.Self,
    CastingSoundLevel = SoundLevel.Silent,
    DualCastScale = 1f,
    Archetype = new MagicEffectArchetype
    {
        Type = MagicEffectArchetype.TypeEnum.Script,
        ActorValue = ActorValue.None,
    },
};
var dismissAdapter = new VirtualMachineAdapter { Version = 5, ObjectFormat = 2 };
var dismissScript = new ScriptEntry
{
    Name = "PTX_TrainingDummyDismiss",
    Flags = ScriptEntry.Flag.Local,
};
dismissScript.Properties.Add(new ScriptObjectProperty
{
    Name = "DummyQuest",
    Flags = ScriptProperty.Flag.Edited,
    Object = new FormLink<ISkyrimMajorRecordGetter>(quest.FormKey),
});
dismissAdapter.Scripts.Add(dismissScript);
dismissMgef.VirtualMachineAdapter = dismissAdapter;
mod.MagicEffects.Add(dismissMgef);

var dismissSpell = new Spell(F(0x80C), SkyrimRelease.SkyrimSE)
{
    EditorID = "PTX_TrainingDummyDismiss",
    Name = "Dismiss Training Dummy",
    Description = "Removes the current training dummy.",
    Type = SpellType.Spell,
    CastType = CastType.FireAndForget,
    TargetType = TargetType.Self,
    BaseCost = 0,
    ChargeTime = 0.5f,
    Flags = SpellDataFlag.ManualCostCalc | SpellDataFlag.NoAbsorbOrReflect,
};
dismissSpell.EquipmentType.SetTo(eitherHand);
var dismissEffect = new Effect
{
    Data = new EffectData { Magnitude = 0, Area = 0, Duration = 1 },
};
dismissEffect.BaseEffect.SetTo(dismissMgef.FormKey);
dismissSpell.Effects.Add(dismissEffect);
mod.Spells.Add(dismissSpell);

questScript.Properties.Add(new ScriptObjectProperty
{
    Name = "SummonMaleSpell",
    Flags = ScriptProperty.Flag.Edited,
    Object = new FormLink<ISkyrimMajorRecordGetter>(summonMaleSpell.FormKey),
});
questScript.Properties.Add(new ScriptObjectProperty
{
    Name = "SummonFemaleSpell",
    Flags = ScriptProperty.Flag.Edited,
    Object = new FormLink<ISkyrimMajorRecordGetter>(summonFemaleSpell.FormKey),
});
questScript.Properties.Add(new ScriptObjectProperty
{
    Name = "DismissSpell",
    Flags = ScriptProperty.Flag.Edited,
    Object = new FormLink<ISkyrimMajorRecordGetter>(dismissSpell.FormKey),
});

mod.ModHeader.Author = "proteux";
mod.ModHeader.Description = "Personal immortal training dummies (one EncBandit Nord base per slot; female RaceMenu FaceGen).";
mod.ModHeader.MasterReferences.Clear();
mod.ModHeader.MasterReferences.Add(new MasterReference { Master = skyrim });
mod.IsSmallMaster = true;

var outputDir = Path.GetDirectoryName(outputPath)!;
Directory.CreateDirectory(outputDir);
mod.WriteToBinary(outputPath, new BinaryWriteParameters
{
    MastersListContent = MastersListContentOption.NoCheck,
});
Console.WriteLine($"Wrote {outputPath}");

var seqDir = Path.Combine(outputDir, "Seq");
Directory.CreateDirectory(seqDir);
var seqPath = Path.Combine(seqDir, Path.GetFileNameWithoutExtension(outputPath) + ".seq");
var seqFormId = ((uint)mod.ModHeader.MasterReferences.Count << 24) | quest.FormKey.ID;
using (var seq = File.Create(seqPath))
using (var writer = new BinaryWriter(seq))
{
    writer.Write(seqFormId);
}
Console.WriteLine($"Wrote {seqPath} ({seqFormId:X8})");

using var check = SkyrimMod.CreateFromBinaryOverlay(outputPath, SkyrimRelease.SkyrimSE);
Console.WriteLine($"Light {check.IsSmallMaster}, masters: " + string.Join(", ", check.ModHeader.MasterReferences.Select(m => m.Master.ToString())));
Console.WriteLine($"Quests {check.Quests.Count}, Npcs {check.Npcs.Count}, Factions {check.Factions.Count}, Spells {check.Spells.Count}, MGEFs {check.MagicEffects.Count}, Activators {check.Activators.Count}, Explosions {check.Explosions.Count}");
foreach (var f in check.Factions)
    Console.WriteLine($"  FACT {f.EditorID} flags={f.Flags} relations={f.Relations.Count} reaction0={f.Relations.FirstOrDefault()?.Reaction}");
foreach (var n in check.Npcs)
    Console.WriteLine($"  NPC {n.EditorID} female={n.Configuration.Flags.HasFlag(NpcConfiguration.Flag.Female)} essential={n.Configuration.Flags.HasFlag(NpcConfiguration.Flag.Essential)} factions={n.Factions.Count} aggression={n.AIData?.Aggression}");
foreach (var s in check.Spells)
    Console.WriteLine($"  SPEL {s.EditorID} target={s.TargetType} cast={s.CastType}");
foreach (var m in check.MagicEffects)
    Console.WriteLine($"  MGEF {m.EditorID} arch={m.Archetype?.Type} target={m.TargetType} scripts={m.VirtualMachineAdapter?.Scripts.Count ?? 0}");

ScriptName PTX_TrainingDummyQuest extends Quest
{Holds live male and female dummy aliases (both can exist at once).}

ReferenceAlias Property MaleAlias Auto
ReferenceAlias Property FemaleAlias Auto
Spell Property SummonMaleSpell Auto
Spell Property SummonFemaleSpell Auto
Spell Property DismissSpell Auto

Float Property SpawnDistance = 150.0 Auto
Float Property SideOffset = 40.0 Auto

; UI / settings — health max = EffectiveLevel() * HealthPerLevel
Bool Property MatchPlayerLevel = True Auto
Int Property DummyLevel = 1 Auto
Float Property HealthPerLevel = 50.0 Auto
Bool Property MuteNotifications = True Auto
; Toward the player: -4 Archnemesis … 3 Lover. Enemy (-3) / Archnemesis also join
; HostileFaction (enemy only to PlayerFaction) so IsHostileToActor(player) is true
; for harmful Spell auras without making town guards attack them. SafeFaction is
; always applied so hitting / hexing a dummy does not report as town assault.
Int Property RelationshipRank = 3 Auto
Faction Property HostileFaction Auto
Faction Property SafeFaction Auto

Event OnInit()
	RegisterForSingleUpdate(2.0)
EndEvent

Event OnUpdate()
	EnsurePlayerKit()
EndEvent

Int Function EffectiveLevel()
	If MatchPlayerLevel
		Actor player = Game.GetPlayer()
		If player
			Return player.GetLevel()
		EndIf
		Return 1
	EndIf
	If DummyLevel < 1
		Return 1
	EndIf
	Return DummyLevel
EndFunction

Float Function EffectiveMaxHealth()
	Float per = HealthPerLevel
	If per < 1.0
		per = 1.0
	EndIf
	Return (EffectiveLevel() as Float) * per
EndFunction

Function ApplyUiSettings(Bool abMatchPlayer, Int aiLevel, Float afHealthPerLevel, Bool abMuteNotifications, Int aiRelationshipRank)
	MatchPlayerLevel = abMatchPlayer
	If aiLevel < 1
		aiLevel = 1
	EndIf
	DummyLevel = aiLevel
	If afHealthPerLevel < 1.0
		afHealthPerLevel = 1.0
	EndIf
	HealthPerLevel = afHealthPerLevel
	MuteNotifications = abMuteNotifications
	If aiRelationshipRank < -4
		aiRelationshipRank = -4
	ElseIf aiRelationshipRank > 3
		aiRelationshipRank = 3
	EndIf
	RelationshipRank = aiRelationshipRank
	ReassertLiveDummy()
EndFunction

; Spells once per character. Safe to call again after a load.
Function EnsurePlayerKit()
	Actor player = Game.GetPlayer()
	If !player || !SummonMaleSpell
		Return
	EndIf
	If player.HasSpell(SummonMaleSpell)
		Return
	EndIf
	GivePlayerSpells()
EndFunction

Function GivePlayerSpells()
	Actor player = Game.GetPlayer()
	If !player
		Return
	EndIf
	If SummonMaleSpell
		player.AddSpell(SummonMaleSpell, False)
	EndIf
	If SummonFemaleSpell
		player.AddSpell(SummonFemaleSpell, False)
	EndIf
	If DismissSpell
		player.AddSpell(DismissSpell, False)
	EndIf
	Notify("Training Dummy spells added.")
	TrainingDummyUI.LogLine("--- spells added ---")
EndFunction

Function RemovePlayerSpells()
	Actor player = Game.GetPlayer()
	If !player
		Return
	EndIf
	If SummonMaleSpell
		player.RemoveSpell(SummonMaleSpell)
	EndIf
	If SummonFemaleSpell
		player.RemoveSpell(SummonFemaleSpell)
	EndIf
	If DismissSpell
		player.RemoveSpell(DismissSpell)
	EndIf
	Notify("Training Dummy spells removed.")
	TrainingDummyUI.LogLine("--- spells removed ---")
EndFunction

Bool Function PlayerHasSpells()
	Actor player = Game.GetPlayer()
	If !player || !SummonMaleSpell
		Return False
	EndIf
	Return player.HasSpell(SummonMaleSpell)
EndFunction

Function SummonMale()
	ActorBase base = Game.GetFormFromFile(0x801, "PTX_TrainingDummy.esp") as ActorBase
	Actor player = Game.GetPlayer()
	If player && base
		SpawnInFrontOf(player, base)
	EndIf
EndFunction

Function SummonFemale()
	ActorBase base = Game.GetFormFromFile(0x802, "PTX_TrainingDummy.esp") as ActorBase
	Actor player = Game.GetPlayer()
	If player && base
		SpawnInFrontOf(player, base)
	EndIf
EndFunction

Function SpawnInFrontOf(Actor akCaster, ActorBase akBase)
	If !akCaster || !akBase
		Return
	EndIf

	ReferenceAlias slot = AliasForBase(akBase)
	If !slot
		Notify("Training Dummy: no alias for that base.")
		Return
	EndIf
	ClearAlias(slot)

	Actor dummy = akCaster.PlaceActorAtMe(akBase)
	If !dummy
		Notify("Training Dummy: PlaceActorAtMe failed.")
		Return
	EndIf

	; Offset in front of the caster; male left / female right so both fit.
	Float az = akCaster.GetAngleZ()
	Float side = SideOffset
	If akBase.GetSex() == 0
		side = -SideOffset
	EndIf
	Float x = SpawnDistance * Math.Sin(az) + side * Math.Cos(az)
	Float y = SpawnDistance * Math.Cos(az) - side * Math.Sin(az)
	dummy.MoveTo(akCaster, x, y, 0.0, True)
	dummy.SetAngle(0.0, 0.0, az + 180.0)

	ConfigureDummy(dummy)
	slot.ForceRefTo(dummy)
	ResetAliasHealthTracking(slot)
	StartAliasPinWatch(slot, dummy)
	; Gear comes from the NPC DefaultOutfit and any SPID / outfit distributors
	; that match the template keywords — no script UnequipAll / forced bandit set.

	Int level = EffectiveLevel()
	Float maxHp = EffectiveMaxHealth()
	Debug.OpenUserLog("TrainingDummy")
	String line = "--- summon want=" + level + " get=" + dummy.GetLevel() + " hp=" + (maxHp as Int) + " base=" + akBase.GetName() + " ---"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogLine(line)
	Notify("Training Dummy summoned.")
EndFunction

Function ClearDummy()
	ClearAlias(MaleAlias)
	ClearAlias(FemaleAlias)
	Debug.TraceUser("TrainingDummy", "--- dismiss ---")
	TrainingDummyUI.LogLine("--- dismiss ---")
EndFunction

Function ClearAlias(ReferenceAlias slot)
	If !slot
		Return
	EndIf
	PTX_TrainingDummyAlias typed = slot as PTX_TrainingDummyAlias
	If typed
		typed.StopPinWatch()
	EndIf
	Actor dummy = slot.GetActorReference()
	If dummy
		dummy.Disable()
		dummy.Delete()
	EndIf
	slot.Clear()
EndFunction

ReferenceAlias Function AliasForBase(ActorBase akBase)
	If !akBase
		Return None
	EndIf
	If akBase.GetSex() == 1
		Return FemaleAlias
	EndIf
	Return MaleAlias
EndFunction

; Alias OnLoad: reassert both slots that are filled.
Function ReassertLiveDummy()
	Actor male = None
	Actor female = None
	If MaleAlias
		male = MaleAlias.GetActorReference()
	EndIf
	If FemaleAlias
		female = FemaleAlias.GetActorReference()
	EndIf
	If male
		ConfigureDummy(male)
		ResetAliasHealthTracking(MaleAlias)
		StartAliasPinWatch(MaleAlias, male)
	EndIf
	If female
		ConfigureDummy(female)
		ResetAliasHealthTracking(FemaleAlias)
		StartAliasPinWatch(FemaleAlias, female)
	EndIf
EndFunction

Function ResetAliasHealthTracking(ReferenceAlias slot)
	PTX_TrainingDummyAlias typed = slot as PTX_TrainingDummyAlias
	If typed
		typed.SyncFromQuest()
	EndIf
EndFunction

Function StartAliasPinWatch(ReferenceAlias slot, Actor dummy)
	PTX_TrainingDummyAlias typed = slot as PTX_TrainingDummyAlias
	If typed
		typed.RememberAnchor(dummy)
		typed.EnsurePinWatch(dummy)
	EndIf
EndFunction

Function HealLiveDummies()
	Float maxHp = EffectiveMaxHealth()
	If MaleAlias
		Actor male = MaleAlias.GetActorReference()
		If male
			male.SetActorValue("Health", maxHp)
			male.RestoreActorValue("Health", maxHp)
			ResetAliasHealthTracking(MaleAlias)
		EndIf
	EndIf
	If FemaleAlias
		Actor female = FemaleAlias.GetActorReference()
		If female
			female.SetActorValue("Health", maxHp)
			female.RestoreActorValue("Health", maxHp)
			ResetAliasHealthTracking(FemaleAlias)
		EndIf
	EndIf
	String line = "--- heal now hp=" + (maxHp as Int) + " ---"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogLine(line)
	Notify("Training Dummy healed.")
EndFunction

Int Function GetMaleFormID()
	If !MaleAlias
		Return 0
	EndIf
	Actor dummy = MaleAlias.GetActorReference()
	If dummy
		Return dummy.GetFormID()
	EndIf
	Return 0
EndFunction

Int Function GetFemaleFormID()
	If !FemaleAlias
		Return 0
	EndIf
	Actor dummy = FemaleAlias.GetActorReference()
	If dummy
		Return dummy.GetFormID()
	EndIf
	Return 0
EndFunction

Faction Function ResolveHostileFaction()
	If HostileFaction
		Return HostileFaction
	EndIf
	; PTX_TrainingDummyHostileFaction (0x803) — enemy only to PlayerFaction.
	HostileFaction = Game.GetFormFromFile(0x803, "PTX_TrainingDummy.esp") as Faction
	Return HostileFaction
EndFunction

Faction Function ResolveSafeFaction()
	If SafeFaction
		Return SafeFaction
	EndIf
	; PTX_TrainingDummyFaction (0x804) — crime-immune at every rank.
	SafeFaction = Game.GetFormFromFile(0x804, "PTX_TrainingDummy.esp") as Faction
	Return SafeFaction
EndFunction

Function SetFactionMembership(Actor dummy, Faction akFaction, Bool wantIn)
	If !dummy || !akFaction
		Return
	EndIf
	Bool inFaction = dummy.IsInFaction(akFaction)
	If wantIn && !inFaction
		dummy.AddToFaction(akFaction)
	ElseIf !wantIn && inFaction
		dummy.RemoveFromFaction(akFaction)
	EndIf
EndFunction

Function ConfigureDummy(Actor dummy)
	If !dummy
		Return
	EndIf
	Int level = EffectiveLevel()
	Float maxHp = EffectiveMaxHealth()
	dummy.SetGhost(False)
	dummy.StopCombat()
	dummy.EnableAI(True)
	dummy.SetDontMove(True)
	dummy.SetRestrained(True)
	TrainingDummyUI.SetActorLevel(dummy, level)
	dummy.SetActorValue("Health", maxHp)
	dummy.RestoreActorValue("Health", maxHp)
	; No town crime faction — assault on a dummy must not bounty the player.
	dummy.SetCrimeFaction(None)
	Actor player = Game.GetPlayer()
	Int rank = RelationshipRank
	If rank < -4
		rank = -4
	ElseIf rank > 3
		rank = 3
	EndIf
	If player
		dummy.SetRelationshipRank(player, rank)
	EndIf
	; Drop BanditFaction from 0.3.4 if still attached (guards attacked those).
	Faction bandit = Game.GetFormFromFile(0x1BCC0, "Skyrim.esm") as Faction
	If bandit && dummy.IsInFaction(bandit)
		dummy.RemoveFromFaction(bandit)
	EndIf
	; Always crime-immune. Enemy / Archnemesis also get the player-hostile faction
	; so harmful Spell auras pass IsHostileToActor without involving guards.
	SetFactionMembership(dummy, ResolveSafeFaction(), True)
	SetFactionMembership(dummy, ResolveHostileFaction(), rank <= -3)
EndFunction

Function Notify(String asText)
	If MuteNotifications
		Return
	EndIf
	Debug.Notification(asText)
EndFunction

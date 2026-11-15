ScriptName PTX_TrainingDummyQuest extends Quest
{Holds up to three male and three female dummy aliases.}

ReferenceAlias Property MaleAlias0 Auto
ReferenceAlias Property MaleAlias1 Auto
ReferenceAlias Property MaleAlias2 Auto
ReferenceAlias Property FemaleAlias0 Auto
ReferenceAlias Property FemaleAlias1 Auto
ReferenceAlias Property FemaleAlias2 Auto
Spell Property SummonMaleSpell Auto
Spell Property SummonFemaleSpell Auto
Spell Property DismissSpell Auto

Float Property SpawnDistance = 150.0 Auto
Float Property SideOffset = 40.0 Auto
Int Property MaxPerGender = 3 Auto

; UI / settings — health max = EffectiveLevel() * HealthPerLevel
Bool Property MatchPlayerLevel = True Auto
Int Property DummyLevel = 1 Auto
Float Property HealthPerLevel = 50.0 Auto
; Current HP as % of max on summon / settings reassert (1–100). Heal now fills to 100%.
Float Property HealthStartPercent = 100.0 Auto
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

Float Function EffectiveStartHealth()
	Float pct = HealthStartPercent
	If pct < 1.0
		pct = 1.0
	ElseIf pct > 100.0
		pct = 100.0
	EndIf
	Float startHp = EffectiveMaxHealth() * (pct / 100.0)
	If startHp < 1.0
		startHp = 1.0
	EndIf
	Return startHp
EndFunction

; Sets max HP, then current HP to afCurrent (clamped to max).
Function ApplyHealth(Actor dummy, Float afMaxHp, Float afCurrent)
	If !dummy
		Return
	EndIf
	If afMaxHp < 1.0
		afMaxHp = 1.0
	EndIf
	If afCurrent < 1.0
		afCurrent = 1.0
	ElseIf afCurrent > afMaxHp
		afCurrent = afMaxHp
	EndIf
	dummy.SetActorValue("Health", afMaxHp)
	dummy.RestoreActorValue("Health", afMaxHp)
	If afCurrent < afMaxHp
		dummy.DamageActorValue("Health", afMaxHp - afCurrent)
	EndIf
EndFunction

Function ApplyUiSettings(Bool abMatchPlayer, Int aiLevel, Float afHealthPerLevel, Float afHealthStartPercent, Bool abMuteNotifications, Int aiRelationshipRank)
	MatchPlayerLevel = abMatchPlayer
	If aiLevel < 1
		aiLevel = 1
	EndIf
	DummyLevel = aiLevel
	If afHealthPerLevel < 1.0
		afHealthPerLevel = 1.0
	EndIf
	HealthPerLevel = afHealthPerLevel
	If afHealthStartPercent < 1.0
		afHealthStartPercent = 1.0
	ElseIf afHealthStartPercent > 100.0
		afHealthStartPercent = 100.0
	EndIf
	HealthStartPercent = afHealthStartPercent
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

	Bool female = akBase.GetSex() == 1
	Int slotIndex = FindFreeSlot(female)
	If slotIndex < 0
		Notify("Training Dummy: already have " + MaxPerGender + " of that type.")
		Return
	EndIf

	ReferenceAlias slot = SlotAt(female, slotIndex)
	If !slot
		Notify("Training Dummy: no alias for that slot.")
		Return
	EndIf

	Actor dummy = akCaster.PlaceActorAtMe(akBase)
	If !dummy
		Notify("Training Dummy: PlaceActorAtMe failed.")
		Return
	EndIf

	; Fan left (male) / right (female); later slots step farther out and slightly forward.
	Float az = akCaster.GetAngleZ()
	Float sideSign = 1.0
	If !female
		sideSign = -1.0
	EndIf
	Float side = sideSign * SideOffset * (1.0 + (slotIndex as Float) * 2.0)
	Float dist = SpawnDistance + (slotIndex as Float) * 40.0
	Float x = dist * Math.Sin(az) + side * Math.Cos(az)
	Float y = dist * Math.Cos(az) - side * Math.Sin(az)
	dummy.MoveTo(akCaster, x, y, 0.0, True)
	dummy.SetAngle(0.0, 0.0, az + 180.0)

	ConfigureDummy(dummy)
	slot.ForceRefTo(dummy)
	ResetAliasHealthTracking(slot)
	StartAliasPinWatch(slot, dummy)

	Int level = EffectiveLevel()
	Float maxHp = EffectiveMaxHealth()
	Float startHp = EffectiveStartHealth()
	Debug.OpenUserLog("TrainingDummy")
	String line = "--- summon want=" + level + " get=" + dummy.GetLevel() + " hp=" + (startHp as Int) + "/" + (maxHp as Int) + " base=" + akBase.GetName() + " slot=" + slotIndex + " ---"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogLine(line)
	Notify("Training Dummy summoned.")
EndFunction

Function ClearDummy()
	Int i = 0
	While i < MaxPerGender
		ClearAlias(SlotAt(False, i))
		ClearAlias(SlotAt(True, i))
		i += 1
	EndWhile
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

ReferenceAlias Function SlotAt(Bool abFemale, Int aiIndex)
	If aiIndex < 0 || aiIndex >= MaxPerGender
		Return None
	EndIf
	If abFemale
		If aiIndex == 0
			Return FemaleAlias0
		ElseIf aiIndex == 1
			Return FemaleAlias1
		EndIf
		Return FemaleAlias2
	EndIf
	If aiIndex == 0
		Return MaleAlias0
	ElseIf aiIndex == 1
		Return MaleAlias1
	EndIf
	Return MaleAlias2
EndFunction

Int Function FindFreeSlot(Bool abFemale)
	Int i = 0
	While i < MaxPerGender
		ReferenceAlias slot = SlotAt(abFemale, i)
		If slot && !slot.GetActorReference()
			Return i
		EndIf
		i += 1
	EndWhile
	Return -1
EndFunction

; Alias OnLoad: reassert every filled slot.
Function ReassertLiveDummy()
	Int i = 0
	While i < MaxPerGender
		ReassertSlot(SlotAt(False, i))
		ReassertSlot(SlotAt(True, i))
		i += 1
	EndWhile
EndFunction

Function ReassertSlot(ReferenceAlias slot)
	If !slot
		Return
	EndIf
	Actor dummy = slot.GetActorReference()
	If !dummy
		Return
	EndIf
	ConfigureDummy(dummy)
	ResetAliasHealthTracking(slot)
	StartAliasPinWatch(slot, dummy)
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
	Int i = 0
	While i < MaxPerGender
		HealSlot(SlotAt(False, i), maxHp)
		HealSlot(SlotAt(True, i), maxHp)
		i += 1
	EndWhile
	String line = "--- heal now hp=" + (maxHp as Int) + " ---"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogLine(line)
	Notify("Training Dummy healed.")
EndFunction

Function HealSlot(ReferenceAlias slot, Float afMaxHp)
	If !slot
		Return
	EndIf
	Actor dummy = slot.GetActorReference()
	If !dummy
		Return
	EndIf
	ApplyHealth(dummy, afMaxHp, afMaxHp)
	ResetAliasHealthTracking(slot)
EndFunction

; UI: aiIndex 0..2 for that gender's slots.
Int Function GetMaleFormID(Int aiIndex)
	Return FormIDAt(False, aiIndex)
EndFunction

Int Function GetFemaleFormID(Int aiIndex)
	Return FormIDAt(True, aiIndex)
EndFunction

Int Function FormIDAt(Bool abFemale, Int aiIndex)
	ReferenceAlias slot = SlotAt(abFemale, aiIndex)
	If !slot
		Return 0
	EndIf
	Actor dummy = slot.GetActorReference()
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
	Float startHp = EffectiveStartHealth()
	dummy.SetGhost(False)
	dummy.StopCombat()
	dummy.EnableAI(True)
	dummy.SetDontMove(True)
	dummy.SetRestrained(True)
	TrainingDummyUI.SetActorLevel(dummy, level)
	ApplyHealth(dummy, maxHp, startHp)
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

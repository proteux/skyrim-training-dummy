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
; Claimed during PlaceActorAtMe so rapid summons cannot pick the same free slot.
Bool MaleReserving0 = False
Bool MaleReserving1 = False
Bool MaleReserving2 = False
Bool FemaleReserving0 = False
Bool FemaleReserving1 = False
Bool FemaleReserving2 = False
; When all slots are filled, the next summon replaces this index (then advances).
Int MaleNextReplace = 0
Int FemaleNextReplace = 0

; UI / settings — health max = EffectiveLevel() * HealthPerLevel
Bool Property MatchPlayerLevel = True Auto
Int Property DummyLevel = 1 Auto
Float Property HealthPerLevel = 50.0 Auto
; Current HP as % of max on summon / settings reassert (1–100). Heal now fills to 100%.
Float Property HealthStartPercent = 100.0 Auto
; Essential + bleedout when True; die + Resurrect when False.
Bool Property Immortal = True Auto
; Real seconds down after bleedout / death before full recovery (0 = stay down until Heal now).
Float Property DownSeconds = 10.0 Auto
Bool Property MuteNotifications = True Auto
; Toward the player: -4 Archnemesis … 3 Lover. Two separate packs:
; Rival+ → HostileFaction + PackFaction (Ally to each other, Enemy to you).
; Friend+ → FriendFaction + FriendPackFaction (Ally to each other and to you).
; Acquaintance → SafeFaction only. SafeFaction is always on for crime-immunity.
Int Property RelationshipRank = 3 Auto
Faction Property HostileFaction Auto
Faction Property SafeFaction Auto
; Hostile pack partner (Ally with HostileFaction). Rival+ only.
Faction Property PackFaction Auto
; Friend+ — Ally to PlayerFaction.
Faction Property FriendFaction Auto
; Friend pack partner (Ally with FriendFaction). Friend+ only.
Faction Property FriendPackFaction Auto

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
; Engine OOC regen is undone on the alias poll path (ForceAV HealRate is ineffective).
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

; abReassert: True when the user changed settings (snap live dummies). False when
; only priming properties before a summon so damaged dummies are left alone.
Function ApplyUiSettings(Bool abMatchPlayer, Int aiLevel, Float afHealthPerLevel, Float afHealthStartPercent, Bool abImmortal, Float afDownSeconds, Bool abMuteNotifications, Int aiRelationshipRank, Bool abReassert = True)
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
	Immortal = abImmortal
	If afDownSeconds < 0.0
		afDownSeconds = 0.0
	ElseIf afDownSeconds > 300.0
		afDownSeconds = 300.0
	EndIf
	DownSeconds = afDownSeconds
	MuteNotifications = abMuteNotifications
	If aiRelationshipRank < -4
		aiRelationshipRank = -4
	ElseIf aiRelationshipRank > 3
		aiRelationshipRank = 3
	EndIf
	RelationshipRank = aiRelationshipRank
	If abReassert
		ReassertLiveDummy()
	EndIf
EndFunction

; Essential is per ActorBase — each slot has its own base.
Function ApplyImmortality(Actor dummy)
	If !dummy
		Return
	EndIf
	ActorBase base = dummy.GetActorBase()
	If base
		base.SetEssential(Immortal)
	EndIf
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

; Slot 0/1/2 → distinct spellings (also set on each base's FULL as fallback).
String Function NameForSlot(Bool abFemale, Int aiIndex)
	If abFemale
		If aiIndex == 0
			Return "Megan"
		ElseIf aiIndex == 1
			Return "Meghan"
		EndIf
		Return "Meagan"
	EndIf
	If aiIndex == 0
		Return "Sean"
	ElseIf aiIndex == 1
		Return "Shawn"
	EndIf
	Return "Shaun"
EndFunction

; Males 0x801/0x805/0x806; females 0x802/0x80D/0x80E — one base per slot.
ActorBase Function BaseForSlot(Bool abFemale, Int aiIndex)
	Int formId = 0
	If abFemale
		If aiIndex == 0
			formId = 0x802
		ElseIf aiIndex == 1
			formId = 0x80D
		ElseIf aiIndex == 2
			formId = 0x80E
		EndIf
	Else
		If aiIndex == 0
			formId = 0x801
		ElseIf aiIndex == 1
			formId = 0x805
		ElseIf aiIndex == 2
			formId = 0x806
		EndIf
	EndIf
	If formId == 0
		Return None
	EndIf
	Return Game.GetFormFromFile(formId, "PTX_TrainingDummy.esp") as ActorBase
EndFunction

Function SummonMale()
	Actor player = Game.GetPlayer()
	If player
		SpawnInFrontOf(player, False)
	EndIf
EndFunction

Function SummonFemale()
	Actor player = Game.GetPlayer()
	If player
		SpawnInFrontOf(player, True)
	EndIf
EndFunction

Function SpawnInFrontOf(Actor akCaster, Bool abFemale)
	If !akCaster
		Return
	EndIf

	; Empty slot first; if full (alive or dead), clear and reuse the next replace slot.
	Int slotIndex = ClaimSummonSlot(abFemale)
	If slotIndex < 0
		Notify("Training Dummy: no free slot (busy).")
		Return
	EndIf

	ActorBase akBase = BaseForSlot(abFemale, slotIndex)
	If !akBase
		SetSlotReserved(abFemale, slotIndex, False)
		Notify("Training Dummy: missing ActorBase for slot.")
		Return
	EndIf

	ReferenceAlias slot = SlotAt(abFemale, slotIndex)
	If !slot
		SetSlotReserved(abFemale, slotIndex, False)
		Notify("Training Dummy: no alias for that slot.")
		Return
	EndIf

	Actor dummy = akCaster.PlaceActorAtMe(akBase)
	If !dummy
		SetSlotReserved(abFemale, slotIndex, False)
		Notify("Training Dummy: PlaceActorAtMe failed.")
		Return
	EndIf

	; Reused FormIDs can keep leftover MTF overlays — scrub before use.
	ClearMagicTattoos(dummy)

	; Claim the alias before MoveTo / Configure so a parallel summon cannot reuse it,
	; and so pin/heal tracking attaches even if later steps hitch.
	slot.ForceRefTo(dummy)
	SetSlotReserved(abFemale, slotIndex, False)

	; Fan left (male) / right (female); later slots step farther out and slightly forward.
	Float az = akCaster.GetAngleZ()
	Float sideSign = 1.0
	If !abFemale
		sideSign = -1.0
	EndIf
	Float side = sideSign * SideOffset * (1.0 + (slotIndex as Float) * 2.0)
	Float dist = SpawnDistance + (slotIndex as Float) * 40.0
	Float x = dist * Math.Sin(az) + side * Math.Cos(az)
	Float y = dist * Math.Cos(az) - side * Math.Sin(az)
	dummy.MoveTo(akCaster, x, y, 0.0, True)
	dummy.SetAngle(0.0, 0.0, az + 180.0)

	TrainingDummyUI.SetDisplayName(dummy, NameForSlot(abFemale, slotIndex))
	ConfigureDummy(dummy)
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
		ClearMagicTattoos(dummy)
		dummy.Disable()
		dummy.Delete()
	EndIf
	slot.Clear()
EndFunction

; Soft dep on Magic Tattoos Framework — drop presets, overlays, and tracking so the
; next PlaceActorAtMe of that slot's base is blank.
Function ClearMagicTattoos(Actor akDummy)
	If !akDummy
		Return
	EndIf
	MTF_MainQuest mtf = Game.GetFormFromFile(0x803, "MagicTattoosFramework.esp") as MTF_MainQuest
	If mtf
		mtf.RemoveTrackedActor(akDummy)
	EndIf
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

Bool Function IsSlotReserved(Bool abFemale, Int aiIndex)
	If abFemale
		If aiIndex == 0
			Return FemaleReserving0
		ElseIf aiIndex == 1
			Return FemaleReserving1
		ElseIf aiIndex == 2
			Return FemaleReserving2
		EndIf
		Return False
	EndIf
	If aiIndex == 0
		Return MaleReserving0
	ElseIf aiIndex == 1
		Return MaleReserving1
	ElseIf aiIndex == 2
		Return MaleReserving2
	EndIf
	Return False
EndFunction

Function SetSlotReserved(Bool abFemale, Int aiIndex, Bool abBusy)
	If abFemale
		If aiIndex == 0
			FemaleReserving0 = abBusy
		ElseIf aiIndex == 1
			FemaleReserving1 = abBusy
		ElseIf aiIndex == 2
			FemaleReserving2 = abBusy
		EndIf
		Return
	EndIf
	If aiIndex == 0
		MaleReserving0 = abBusy
	ElseIf aiIndex == 1
		MaleReserving1 = abBusy
	ElseIf aiIndex == 2
		MaleReserving2 = abBusy
	EndIf
EndFunction

Int Function FindFreeSlot(Bool abFemale)
	Int i = 0
	While i < MaxPerGender
		ReferenceAlias slot = SlotAt(abFemale, i)
		If slot && !slot.GetActorReference() && !IsSlotReserved(abFemale, i)
			SetSlotReserved(abFemale, i, True)
			Return i
		EndIf
		i += 1
	EndWhile
	Return -1
EndFunction

Int Function NextReplaceIndex(Bool abFemale)
	If abFemale
		Return FemaleNextReplace
	EndIf
	Return MaleNextReplace
EndFunction

Function SetNextReplaceIndex(Bool abFemale, Int aiIndex)
	If aiIndex < 0
		aiIndex = 0
	ElseIf aiIndex >= MaxPerGender
		aiIndex = 0
	EndIf
	If abFemale
		FemaleNextReplace = aiIndex
	Else
		MaleNextReplace = aiIndex
	EndIf
EndFunction

; Prefer an empty alias; otherwise replace the next filled slot (dead preferred, then round-robin).
Int Function ClaimSummonSlot(Bool abFemale)
	Int free = FindFreeSlot(abFemale)
	If free >= 0
		Return free
	EndIf

	Int start = NextReplaceIndex(abFemale)
	If start < 0 || start >= MaxPerGender
		start = 0
	EndIf

	; From the replace cursor, prefer a dead occupant so corpses get recycled first.
	Int deadIndex = -1
	Int i = 0
	While i < MaxPerGender
		Int cand = start + i
		If cand >= MaxPerGender
			cand -= MaxPerGender
		EndIf
		If !IsSlotReserved(abFemale, cand)
			ReferenceAlias slot = SlotAt(abFemale, cand)
			Actor existing = None
			If slot
				existing = slot.GetActorReference()
			EndIf
			If existing && existing.IsDead()
				deadIndex = cand
				i = MaxPerGender
			EndIf
		EndIf
		i += 1
	EndWhile

	Int index = deadIndex
	If index < 0
		; No dead slot — take the first non-reserved from the cursor.
		i = 0
		While i < MaxPerGender && index < 0
			Int cand = start + i
			If cand >= MaxPerGender
				cand -= MaxPerGender
			EndIf
			If !IsSlotReserved(abFemale, cand)
				index = cand
			EndIf
			i += 1
		EndWhile
	EndIf
	If index < 0
		Return -1
	EndIf

	ClearAlias(SlotAt(abFemale, index))
	SetSlotReserved(abFemale, index, True)
	Int nextIndex = index + 1
	If nextIndex >= MaxPerGender
		nextIndex = 0
	EndIf
	SetNextReplaceIndex(abFemale, nextIndex)
	Return index
EndFunction

; Settings / cell return: reassert every filled slot.
Function ReassertLiveDummy()
	Int i = 0
	While i < MaxPerGender
		ReassertSlot(SlotAt(False, i))
		ReassertSlot(SlotAt(True, i))
		i += 1
	EndWhile
EndFunction

; Alias OnLoad should only touch itself — reasserting every slot mid-summon races.
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
	; Alias path resurrects / ends bleedout wait, then fills HP.
	PTX_TrainingDummyAlias typed = slot as PTX_TrainingDummyAlias
	If typed
		typed.RecoverNow()
		Return
	EndIf
	If dummy.IsDead()
		dummy.Resurrect()
	EndIf
	ApplyImmortality(dummy)
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

Faction Function ResolvePackFaction()
	If PackFaction
		Return PackFaction
	EndIf
	; PTX_TrainingDummyPackFaction (0x80F) — Ally with HostileFaction; Rival+ pack.
	PackFaction = Game.GetFormFromFile(0x80F, "PTX_TrainingDummy.esp") as Faction
	Return PackFaction
EndFunction

Faction Function ResolveFriendFaction()
	If FriendFaction
		Return FriendFaction
	EndIf
	; PTX_TrainingDummyFriendFaction (0x810) — Ally to PlayerFaction for Friend+ ranks.
	FriendFaction = Game.GetFormFromFile(0x810, "PTX_TrainingDummy.esp") as Faction
	Return FriendFaction
EndFunction

Faction Function ResolveFriendPackFaction()
	If FriendPackFaction
		Return FriendPackFaction
	EndIf
	; PTX_TrainingDummyFriendPackFaction (0x811) — Ally with FriendFaction; Friend+ pack.
	FriendPackFaction = Game.GetFormFromFile(0x811, "PTX_TrainingDummy.esp") as Faction
	Return FriendPackFaction
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
	ApplyImmortality(dummy)
	If dummy.IsDead()
		dummy.Resurrect()
	EndIf
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
	; SafeFaction: crime-immune for every rank (no Ally links).
	; Rival+: hostile pack (Hostile + Pack). Friend+: friend pack (Friend + FriendPack).
	; Acquaintance: Safe only. Packs do not Ally across ranks.
	Bool hostile = rank <= -2
	Bool friendly = rank >= 0
	SetFactionMembership(dummy, ResolveSafeFaction(), True)
	SetFactionMembership(dummy, ResolveHostileFaction(), hostile)
	SetFactionMembership(dummy, ResolvePackFaction(), hostile)
	SetFactionMembership(dummy, ResolveFriendFaction(), friendly)
	SetFactionMembership(dummy, ResolveFriendPackFaction(), friendly)
EndFunction

Function Notify(String asText)
	If MuteNotifications
		Return
	EndIf
	Debug.Notification(asText)
EndFunction

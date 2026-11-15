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
; Toward the player: -4 Archnemesis … 3 Lover. Enemy (-3) for harmful Spell aura tests.
Int Property RelationshipRank = 3 Auto

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

	Utility.Wait(0.25)
	GiveStartingGear(dummy)

	Int level = EffectiveLevel()
	Float maxHp = EffectiveMaxHealth()
	Debug.OpenUserLog("TrainingDummy")
	String line = "--- summon level=" + level + " hp=" + (maxHp as Int) + " base=" + akBase.GetName() + " ---"
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
	EndIf
	If female
		ConfigureDummy(female)
		ResetAliasHealthTracking(FemaleAlias)
	EndIf
EndFunction

Function ResetAliasHealthTracking(ReferenceAlias slot)
	PTX_TrainingDummyAlias typed = slot as PTX_TrainingDummyAlias
	If typed
		typed.SyncFromQuest()
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
	dummy.SetLevel(level)
	dummy.SetActorValue("Health", maxHp)
	dummy.RestoreActorValue("Health", maxHp)
	Actor player = Game.GetPlayer()
	If player
		Int rank = RelationshipRank
		If rank < -4
			rank = -4
		ElseIf rank > 3
			rank = 3
		EndIf
		dummy.SetRelationshipRank(player, rank)
	EndIf
EndFunction

Function GiveStartingGear(Actor dummy)
	If !dummy
		Return
	EndIf
	dummy.UnequipAll()
	EquipFromFile(dummy, 0x06F393) ; ArmorBanditCuirass
	EquipFromFile(dummy, 0x06F398) ; ArmorBanditBoots
	EquipFromFile(dummy, 0x06F39B) ; ArmorBanditGauntlets
	; No helmet — RaceMenu/KS hair from FaceGen stays visible.
EndFunction

Function EquipFromFile(Actor dummy, Int formId)
	Form item = Game.GetFormFromFile(formId, "Skyrim.esm")
	If item
		dummy.AddItem(item, 1, True)
		dummy.EquipItem(item, False, True)
	EndIf
EndFunction

Function Notify(String asText)
	If MuteNotifications
		Return
	EndIf
	Debug.Notification(asText)
EndFunction

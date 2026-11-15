ScriptName PTX_TrainingDummyQuest extends Quest
{Holds live male and female dummy aliases (both can exist at once).}

ReferenceAlias Property MaleAlias Auto
ReferenceAlias Property FemaleAlias Auto
Spell Property SummonMaleSpell Auto
Spell Property SummonFemaleSpell Auto
Spell Property DismissSpell Auto

Float Property SpawnDistance = 150.0 Auto
Float Property SideOffset = 40.0 Auto

Event OnInit()
	RegisterForSingleUpdate(2.0)
EndEvent

Event OnUpdate()
	EnsurePlayerKit()
EndEvent

; Spells once per character. Safe to call again after a load.
Function EnsurePlayerKit()
	Actor player = Game.GetPlayer()
	If !player || !SummonMaleSpell
		Return
	EndIf
	If player.HasSpell(SummonMaleSpell)
		Return
	EndIf
	player.AddSpell(SummonMaleSpell, False)
	If SummonFemaleSpell
		player.AddSpell(SummonFemaleSpell, False)
	EndIf
	If DismissSpell
		player.AddSpell(DismissSpell, False)
	EndIf
	Debug.Notification("Training Dummy spells added.")
EndFunction

Function SpawnInFrontOf(Actor akCaster, ActorBase akBase)
	If !akCaster || !akBase
		Return
	EndIf

	ReferenceAlias slot = AliasForBase(akBase)
	If !slot
		Debug.Notification("Training Dummy: no alias for that base.")
		Return
	EndIf
	ClearAlias(slot)

	Actor dummy = akCaster.PlaceActorAtMe(akBase)
	If !dummy
		Debug.Notification("Training Dummy: PlaceActorAtMe failed.")
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

	Debug.OpenUserLog("TrainingDummy")
	Debug.TraceUser("TrainingDummy", "--- summon level=" + Game.GetPlayer().GetLevel() + " base=" + akBase.GetName() + " ---")
	Debug.Notification("Training Dummy summoned.")
EndFunction

Function ClearDummy()
	ClearAlias(MaleAlias)
	ClearAlias(FemaleAlias)
	Debug.TraceUser("TrainingDummy", "--- dismiss ---")
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
		typed.ResetHealthTracking()
	EndIf
EndFunction

Function ConfigureDummy(Actor dummy)
	If !dummy
		Return
	EndIf
	Int level = Game.GetPlayer().GetLevel()
	dummy.SetGhost(False)
	dummy.EnableAI(True)
	dummy.SetDontMove(True)
	dummy.SetLevel(level)
	dummy.SetActorValue("Health", 1000.0)
	dummy.RestoreActorValue("Health", 1000.0)
	Actor player = Game.GetPlayer()
	If player
		dummy.SetRelationshipRank(player, 3)
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

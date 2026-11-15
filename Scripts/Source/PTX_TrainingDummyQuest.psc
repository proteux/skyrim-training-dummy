ScriptName PTX_TrainingDummyQuest extends Quest
{Holds the live dummy alias and spawns/clears it.}

ReferenceAlias Property DummyAlias Auto
Spell Property SummonMaleSpell Auto
Spell Property SummonFemaleSpell Auto
Spell Property DismissSpell Auto

Float Property SpawnDistance = 150.0 Auto

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
	ClearDummy()

	Actor dummy = akCaster.PlaceActorAtMe(akBase)
	If !dummy
		Debug.Notification("Training Dummy: PlaceActorAtMe failed.")
		Return
	EndIf

	; Offset in front of the caster (Skyrim angles are degrees; 0 faces +Y).
	Float az = akCaster.GetAngleZ()
	Float x = SpawnDistance * Math.Sin(az)
	Float y = SpawnDistance * Math.Cos(az)
	dummy.MoveTo(akCaster, x, y, 0.0, True)
	; Face the player (MoveTo matched caster yaw).
	dummy.SetAngle(0.0, 0.0, az + 180.0)

	ConfigureDummy(dummy)
	DummyAlias.ForceRefTo(dummy)

	; Equip after a beat so 3D is ready; strip anything SPID/outfit forced on first.
	Utility.Wait(0.25)
	GiveStartingGear(dummy)

	Debug.OpenUserLog("TrainingDummy")
	Debug.TraceUser("TrainingDummy", "--- summon level=" + Game.GetPlayer().GetLevel() + " base=" + akBase.GetName() + " ---")
	Debug.Notification("Training Dummy summoned.")
EndFunction

Function ClearDummy()
	Actor dummy = DummyAlias.GetActorReference()
	If dummy
		Debug.TraceUser("TrainingDummy", "--- dismiss ---")
		dummy.Disable()
		dummy.Delete()
	EndIf
	DummyAlias.Clear()
EndFunction

; Alias OnLoad calls this so a reloaded dummy stays still and topped up.
Function ReassertLiveDummy()
	Actor dummy = DummyAlias.GetActorReference()
	If dummy
		ConfigureDummy(dummy)
	EndIf
EndFunction

Function ConfigureDummy(Actor dummy)
	If !dummy
		Return
	EndIf
	Int level = Game.GetPlayer().GetLevel()
	dummy.SetGhost(False)
	; Keep AI on so RaceMenu/MTF overlays redraw; hold in place instead.
	dummy.EnableAI(True)
	dummy.SetDontMove(True)
	dummy.SetLevel(level)
	dummy.SetActorValue("Health", 10000.0)
	dummy.RestoreActorValue("Health", 10000.0)
	Actor player = Game.GetPlayer()
	If player
		dummy.SetRelationshipRank(player, 3) ; Friend — pickpocket / reverse-pickpocket without a fight
	EndIf
EndFunction

; Inventory gear (not DefaultOutfit) so pickpocket can strip or dress them.
Function GiveStartingGear(Actor dummy)
	If !dummy
		Return
	EndIf
	dummy.UnequipAll()
	EquipFromFile(dummy, 0x06F393) ; ArmorBanditCuirass
	EquipFromFile(dummy, 0x06F398) ; ArmorBanditBoots
	EquipFromFile(dummy, 0x06F39B) ; ArmorBanditGauntlets
	EquipFromFile(dummy, 0x06F39E) ; ArmorBanditHelmet
EndFunction

Function EquipFromFile(Actor dummy, Int formId)
	Form item = Game.GetFormFromFile(formId, "Skyrim.esm")
	If item
		dummy.AddItem(item, 1, True)
		dummy.EquipItem(item, False, True)
	EndIf
EndFunction

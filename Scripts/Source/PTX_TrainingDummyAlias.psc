ScriptName PTX_TrainingDummyAlias extends ReferenceAlias
{Keeps the dummy still, at player level, and immortal via OnHit heal.}

PTX_TrainingDummyQuest Property DummyQuest Auto

Event OnLoad()
	If DummyQuest
		DummyQuest.ReassertLiveDummy()
	Else
		Configure()
	EndIf
EndEvent

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	; Health here is already reduced by the hit; restore and report how much was lost.
	Float remaining = dummy.GetActorValue("Health")
	Float damage = 10000.0 - remaining
	If damage < 0.0
		damage = 0.0
	EndIf
	dummy.RestoreActorValue("Health", 10000.0)

	String sourceName = "?"
	If akSource
		sourceName = akSource.GetName()
		If sourceName == ""
			sourceName = "form:" + akSource.GetFormID()
		EndIf
	EndIf
	String who = "?"
	If akAggressor
		who = akAggressor.GetDisplayName()
		If who == ""
			who = akAggressor.GetName()
		EndIf
		If who == ""
			who = "form:" + akAggressor.GetFormID()
		EndIf
	EndIf

	Int dmgInt = damage as Int
	String line = "hit dmg=" + dmgInt + " source=" + sourceName + " aggressor=" + who
	If abHitBlocked
		line += " blocked=1"
	EndIf
	Debug.TraceUser("TrainingDummy", line)
	Debug.Notification("Dummy hit: " + dmgInt + " dmg")
EndEvent

Function Configure()
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	dummy.SetGhost(False)
	dummy.EnableAI(False)
	dummy.SetLevel(Game.GetPlayer().GetLevel())
	dummy.SetActorValue("Health", 10000.0)
	dummy.RestoreActorValue("Health", 10000.0)
EndFunction

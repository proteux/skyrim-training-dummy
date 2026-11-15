ScriptName PTX_TrainingDummyAlias extends ReferenceAlias
{Keeps the dummy still, at player level, and immortal via Essential + bleedout heal.}

PTX_TrainingDummyQuest Property DummyQuest Auto

; Max health; also tracks HP before the latest OnHit for per-hit damage logging.
Float Property MaxHealth = 1000.0 Auto
Float LastHealth = 1000.0

Function ResetHealthTracking()
	LastHealth = MaxHealth
EndFunction

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
	; Health here is already reduced by the hit; report how much was lost this swing.
	Float remaining = dummy.GetActorValue("Health")
	Float damage = LastHealth - remaining
	If damage < 0.0
		damage = 0.0
	EndIf
	LastHealth = remaining

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

; Essential NPC — collapse, then stand back up at full health.
Event OnEnterBleedout()
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	dummy.RestoreActorValue("Health", MaxHealth)
	LastHealth = MaxHealth
	Debug.TraceUser("TrainingDummy", "--- bleedout heal ---")
	Debug.Notification("Dummy stood back up.")
EndEvent

Function Configure()
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	dummy.SetGhost(False)
	dummy.EnableAI(True)
	dummy.SetDontMove(True)
	dummy.SetLevel(Game.GetPlayer().GetLevel())
	dummy.SetActorValue("Health", MaxHealth)
	dummy.RestoreActorValue("Health", MaxHealth)
	LastHealth = MaxHealth
EndFunction

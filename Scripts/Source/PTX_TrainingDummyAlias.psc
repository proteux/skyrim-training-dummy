ScriptName PTX_TrainingDummyAlias extends ReferenceAlias
{Keeps the dummy still, at configured level/HP, and immortal via Essential + bleedout heal.}

PTX_TrainingDummyQuest Property DummyQuest Auto

; Max health; also tracks HP before the latest OnHit for per-hit damage logging.
Float Property MaxHealth = 50.0 Auto
Float LastHealth = 50.0
; Bleedout recovery clears DontMove / restrain; reassert for a few passes.
Int PosturePassesLeft = 0
; After damage, leave combat running until this many real seconds with no hits.
Float Property CombatIdleSeconds = 3.0 Auto
Float LastDamageRealTime = 0.0
Bool WatchingCombat = False

Function SyncFromQuest()
	If DummyQuest
		MaxHealth = DummyQuest.EffectiveMaxHealth()
	EndIf
	LastHealth = MaxHealth
	Actor dummy = GetActorReference()
	If dummy
		; Keep tracking in sync if HP was just set by the quest.
		Float remaining = dummy.GetActorValue("Health")
		If remaining > 0.0
			LastHealth = remaining
		EndIf
	EndIf
EndFunction

Function ResetHealthTracking()
	SyncFromQuest()
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
	TrainingDummyUI.LogHit(damage, line)
	If DummyQuest
		DummyQuest.Notify("Dummy hit: " + dmgInt + " dmg")
	Else
		Debug.Notification("Dummy hit: " + dmgInt + " dmg")
	EndIf

	PinInPlace(dummy)
	If damage > 0.0
		NoteDamage()
	EndIf
EndEvent

; Essential NPC — collapse, then stand back up at full health without chasing.
Event OnEnterBleedout()
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	If DummyQuest
		MaxHealth = DummyQuest.EffectiveMaxHealth()
	EndIf
	dummy.RestoreActorValue("Health", MaxHealth)
	LastHealth = MaxHealth
	PinInPlace(dummy)
	; Engine get-up packages clear pins; keep reasserting while calm timer runs.
	PosturePassesLeft = 5
	NoteDamage()
	String line = "--- bleedout heal hp=" + (MaxHealth as Int) + " ---"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogLine(line)
	If DummyQuest
		DummyQuest.Notify("Dummy stood back up.")
	Else
		Debug.Notification("Dummy stood back up.")
	EndIf
EndEvent

Event OnUpdate()
	Actor dummy = GetActorReference()
	If dummy
		PinInPlace(dummy)
	EndIf

	If WatchingCombat
		Float idleFor = Utility.GetCurrentRealTime() - LastDamageRealTime
		Float need = CombatIdleSeconds
		If need < 0.5
			need = 0.5
		EndIf
		If idleFor >= need
			If dummy
				dummy.StopCombat()
			EndIf
			WatchingCombat = False
			String line = "--- combat calm after " + (need as Int) + "s idle ---"
			Debug.TraceUser("TrainingDummy", line)
			TrainingDummyUI.LogLine(line)
		EndIf
	EndIf

	If PosturePassesLeft > 0
		PosturePassesLeft -= 1
	EndIf

	If WatchingCombat || PosturePassesLeft > 0
		RegisterForSingleUpdate(0.5)
	EndIf
EndEvent

; Pin without breaking combat — restrained stops the run-in-place.
Function PinInPlace(Actor dummy)
	If !dummy
		Return
	EndIf
	dummy.EnableAI(True)
	dummy.SetDontMove(True)
	dummy.SetRestrained(True)
EndFunction

Function NoteDamage()
	LastDamageRealTime = Utility.GetCurrentRealTime()
	WatchingCombat = True
	RegisterForSingleUpdate(0.5)
EndFunction

; Summon / reassert: pin and clear any leftover combat.
Function HoldStill(Actor dummy)
	If !dummy
		Return
	EndIf
	dummy.StopCombat()
	PinInPlace(dummy)
	WatchingCombat = False
	PosturePassesLeft = 0
EndFunction

Function Configure()
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	Int level = 1
	Float maxHp = 50.0
	If DummyQuest
		level = DummyQuest.EffectiveLevel()
		maxHp = DummyQuest.EffectiveMaxHealth()
	Else
		level = Game.GetPlayer().GetLevel()
		maxHp = (level as Float) * 50.0
	EndIf
	MaxHealth = maxHp
	dummy.SetGhost(False)
	HoldStill(dummy)
	dummy.SetLevel(level)
	dummy.SetActorValue("Health", maxHp)
	dummy.RestoreActorValue("Health", maxHp)
	LastHealth = maxHp
EndFunction

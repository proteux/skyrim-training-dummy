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
; Enemy-rank combat packages clear DontMove; keep pinning while the alias is filled.
Float Property PinInterval = 0.25 Auto
Float Property SnapDistance = 24.0 Auto
Bool PinWatchActive = False
Bool HasAnchor = False
Float AnchorX = 0.0
Float AnchorY = 0.0
Float AnchorZ = 0.0
Float AnchorAngleZ = 0.0

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
		EnsurePinWatch(dummy)
	EndIf
EndFunction

Function ResetHealthTracking()
	SyncFromQuest()
EndFunction

; Quest calls this after ForceRefTo / ConfigureDummy so the loop starts immediately.
Function EnsurePinWatch(Actor dummy = None)
	If !dummy
		dummy = GetActorReference()
	EndIf
	If !dummy
		StopPinWatch()
		Return
	EndIf
	If !HasAnchor
		RememberAnchor(dummy)
	EndIf
	PinInPlace(dummy)
	; Always (re)register — PinWatchActive can be true after a lost SingleUpdate.
	PinWatchActive = True
	Float interval = PinInterval
	If interval < 0.1
		interval = 0.1
	EndIf
	RegisterForSingleUpdate(interval)
EndFunction

Function StopPinWatch()
	PinWatchActive = False
	WatchingCombat = False
	PosturePassesLeft = 0
	HasAnchor = False
	UnregisterForUpdate()
EndFunction

Function RememberAnchor(Actor dummy)
	If !dummy
		Return
	EndIf
	AnchorX = dummy.GetPositionX()
	AnchorY = dummy.GetPositionY()
	AnchorZ = dummy.GetPositionZ()
	AnchorAngleZ = dummy.GetAngleZ()
	HasAnchor = True
EndFunction

Event OnLoad()
	; Only this alias — ReassertLiveDummy() during rapid summons stomped sibling pins.
	If DummyQuest
		DummyQuest.ReassertSlot(Self as ReferenceAlias)
	Else
		Configure()
	EndIf
EndEvent

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	; Health is already updated; delta > 0 = damage, delta < 0 = heal.
	Float remaining = dummy.GetActorValue("Health")
	Float delta = LastHealth - remaining
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

	If delta > 0.5
		Int dmgInt = delta as Int
		String line = "hit dmg=" + dmgInt + " source=" + sourceName + " aggressor=" + who
		If abHitBlocked
			line += " blocked=1"
		EndIf
		Debug.TraceUser("TrainingDummy", line)
		TrainingDummyUI.LogHit(delta, line)
		If DummyQuest
			DummyQuest.Notify("Dummy hit: " + dmgInt + " dmg")
		Else
			Debug.Notification("Dummy hit: " + dmgInt + " dmg")
		EndIf
		NoteDamage()
	ElseIf delta < -0.5
		Float heal = 0.0 - delta
		Int healInt = heal as Int
		String line = "heal amt=" + healInt + " source=" + sourceName + " aggressor=" + who
		Debug.TraceUser("TrainingDummy", line)
		TrainingDummyUI.LogHit(0.0 - heal, line)
		If DummyQuest
			DummyQuest.Notify("Dummy heal: " + healInt)
		Else
			Debug.Notification("Dummy heal: " + healInt)
		EndIf
	EndIf

	PinInPlace(dummy)
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
	If !dummy
		StopPinWatch()
		Return
	EndIf

	PinInPlace(dummy)
	; CastAs / Spell aura apply effects without OnHit — catch HP drops here.
	; Small poll heals are engine OOC regen (clamped); larger pulses stay for aura tests.
	ReportHealthDrop(dummy, "aura/poll")

	If WatchingCombat
		Float idleFor = Utility.GetCurrentRealTime() - LastDamageRealTime
		Float need = CombatIdleSeconds
		If need < 0.5
			need = 0.5
		EndIf
		If idleFor >= need
			dummy.StopCombat()
			WatchingCombat = False
			String line = "--- combat calm after " + (need as Int) + "s idle ---"
			Debug.TraceUser("TrainingDummy", line)
			TrainingDummyUI.LogLine(line)
		EndIf
	EndIf

	If PosturePassesLeft > 0
		PosturePassesLeft -= 1
	EndIf

	If PinWatchActive || WatchingCombat || PosturePassesLeft > 0
		Float interval = PinInterval
		If interval < 0.1
			interval = 0.1
		EndIf
		RegisterForSingleUpdate(interval)
	EndIf
EndEvent

; Logs damage or healing when HP changes without an OnHit (Spell aura CastAs path).
Function ReportHealthDrop(Actor dummy, String sourceName)
	If !dummy
		Return
	EndIf
	Float remaining = dummy.GetActorValue("Health")
	Float delta = LastHealth - remaining
	If delta < 0.5 && delta > -0.5
		Return
	EndIf
	If delta > 0.0
		LastHealth = remaining
		Int dmgInt = delta as Int
		String line = "hit dmg=" + dmgInt + " source=" + sourceName + " aggressor=?"
		Debug.TraceUser("TrainingDummy", line)
		TrainingDummyUI.LogHit(delta, line)
		If DummyQuest
			DummyQuest.Notify("Dummy hit: " + dmgInt + " dmg")
		Else
			Debug.Notification("Dummy hit: " + dmgInt + " dmg")
		EndIf
		NoteDamage()
		Return
	EndIf
	Float heal = 0.0 - delta
	; Small poll gains are engine OOC regen (HealRate ForceAV does not stop it).
	; Larger pulses and OnHit heals still count for blessing / aura tests.
	If TrainingDummyUI.ClampPollHeal(dummy, heal)
		LastHealth = remaining - heal
		Return
	EndIf
	LastHealth = remaining
	Int healInt = heal as Int
	String line = "heal amt=" + healInt + " source=" + sourceName + " aggressor=?"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogHit(0.0 - heal, line)
	If DummyQuest
		DummyQuest.Notify("Dummy heal: " + healInt)
	Else
		Debug.Notification("Dummy heal: " + healInt)
	EndIf
EndFunction

; Pin without breaking combat — restrained stops the run-in-place.
; Snap back if combat packages shoved them off the spawn spot.
Function PinInPlace(Actor dummy)
	If !dummy
		Return
	EndIf
	dummy.EnableAI(True)
	dummy.SetDontMove(True)
	dummy.SetRestrained(True)
	If HasAnchor
		Float dx = dummy.GetPositionX() - AnchorX
		Float dy = dummy.GetPositionY() - AnchorY
		Float dz = dummy.GetPositionZ() - AnchorZ
		Float limit = SnapDistance
		If limit < 8.0
			limit = 8.0
		EndIf
		If (dx * dx) + (dy * dy) + (dz * dz) > (limit * limit)
			dummy.SetPosition(AnchorX, AnchorY, AnchorZ)
			dummy.SetAngle(0.0, 0.0, AnchorAngleZ)
			dummy.SetDontMove(True)
			dummy.SetRestrained(True)
		EndIf
	EndIf
EndFunction

Function NoteDamage()
	LastDamageRealTime = Utility.GetCurrentRealTime()
	WatchingCombat = True
	If !PinWatchActive
		RegisterForSingleUpdate(PinInterval)
	EndIf
EndFunction

; Summon / reassert: pin, remember spawn spot, and clear any leftover combat.
Function HoldStill(Actor dummy)
	If !dummy
		Return
	EndIf
	dummy.StopCombat()
	RememberAnchor(dummy)
	PinInPlace(dummy)
	WatchingCombat = False
	PosturePassesLeft = 0
	EnsurePinWatch(dummy)
EndFunction

Function Configure()
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	Int level = 1
	Float maxHp = 50.0
	Float startHp = 50.0
	If DummyQuest
		level = DummyQuest.EffectiveLevel()
		maxHp = DummyQuest.EffectiveMaxHealth()
		startHp = DummyQuest.EffectiveStartHealth()
		DummyQuest.ApplyHealth(dummy, maxHp, startHp)
	Else
		level = Game.GetPlayer().GetLevel()
		maxHp = (level as Float) * 50.0
		startHp = maxHp
		dummy.SetActorValue("Health", maxHp)
		dummy.RestoreActorValue("Health", maxHp)
	EndIf
	MaxHealth = maxHp
	dummy.SetGhost(False)
	HoldStill(dummy)
	TrainingDummyUI.SetActorLevel(dummy, level)
	LastHealth = startHp
EndFunction

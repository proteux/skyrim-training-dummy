ScriptName PTX_TrainingDummyAlias extends ReferenceAlias
{Keeps the dummy still, at configured level/HP. Immortal = Essential bleedout; else die + Resurrect.}

PTX_TrainingDummyQuest Property DummyQuest Auto

; Max health; also tracks HP before the latest OnHit for per-hit damage logging.
Float Property MaxHealth = 50.0 Auto
Float LastHealth = 50.0
; Bleedout / get-up clears DontMove / restrain; reassert for a few passes.
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
; Real time of the last poll heal check — used to size the OOC regen strip.
Float LastPollRealTime = 0.0
; Real time when delayed recovery should fire; 0 = not waiting; < 0 = wait for Heal now.
Float DownUntil = 0.0

Bool Function IsDownWaiting()
	Return DownUntil != 0.0
EndFunction

Function ClearDownWait(Actor dummy = None)
	DownUntil = 0.0
	If !dummy
		dummy = GetActorReference()
	EndIf
	If dummy && !dummy.IsDead()
		; Allow engine / RestoreActorValue to end bleedout again.
		dummy.SetNoBleedoutRecovery(False)
	EndIf
EndFunction

Function SyncFromQuest()
	If DummyQuest
		MaxHealth = DummyQuest.EffectiveMaxHealth()
	EndIf
	LastHealth = MaxHealth
	LastPollRealTime = Utility.GetCurrentRealTime()
	Actor dummy = GetActorReference()
	ClearDownWait(dummy)
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
	If !dummy.IsDead()
		PinInPlace(dummy)
	EndIf
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
	ClearDownWait()
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
	If !dummy || dummy.IsDead()
		Return
	EndIf
	; During forced immortal downtime, strip heals that would end bleedout and skip noisy deltas.
	If IsDownWaiting()
		KeepBleedoutDown(dummy)
		PinInPlace(dummy)
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
		String line = "hit target=" + SlotTag() + " dmg=" + dmgInt + " source=" + sourceName + " aggressor=" + who
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
		String line = "heal target=" + SlotTag() + " amt=" + healInt + " source=" + sourceName + " aggressor=" + who
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

; Essential path — collapse, wait DownSeconds (or until Heal now if 0), then full HP.
Event OnEnterBleedout()
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	If DummyQuest && !DummyQuest.Immortal
		Return
	EndIf
	; Engine essential recovery stands them up in ~seconds; block it until we heal.
	dummy.SetNoBleedoutRecovery(True)
	PinInPlace(dummy)
	NoteDamage()
	EnsurePinWatch(dummy)
	LastHealth = dummy.GetActorValue("Health")
	BeginDownWait(dummy, "bleedout, recovering")
EndEvent

; Mortal path — corpse waits DownSeconds (or until Heal now if 0), then Resurrect.
Event OnDeath(Actor akKiller)
	Actor dummy = GetActorReference()
	If !dummy
		Return
	EndIf
	If DummyQuest && DummyQuest.Immortal
		Return
	EndIf
	NoteDamage()
	EnsurePinWatch(dummy)
	BeginDownWait(dummy, "died, respawning")
EndEvent

Function BeginDownWait(Actor dummy, String asLogVerb)
	If !dummy
		Return
	EndIf
	; Already in a downtime window — keep the original deadline / manual wait.
	If IsDownWaiting()
		Return
	EndIf
	Float delay = 10.0
	If DummyQuest
		delay = DummyQuest.DownSeconds
		MaxHealth = DummyQuest.EffectiveMaxHealth()
	EndIf
	If delay < 0.0
		delay = 0.0
	EndIf
	; 0 = stay down until Heal now (no auto-recovery).
	If delay <= 0.0
		DownUntil = -1.0
		String waitLine = "--- " + asLogVerb + ", waiting for heal now ---"
		Debug.TraceUser("TrainingDummy", waitLine)
		TrainingDummyUI.LogLine(waitLine)
		If DummyQuest
			DummyQuest.Notify("Dummy down until Heal now.")
		Else
			Debug.Notification("Dummy down until Heal now.")
		EndIf
		Return
	EndIf
	DownUntil = Utility.GetCurrentRealTime() + delay
	String line = "--- " + asLogVerb + " in " + (delay as Int) + "s ---"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogLine(line)
	If DummyQuest
		DummyQuest.Notify("Dummy down for " + (delay as Int) + "s.")
	Else
		Debug.Notification("Dummy down for " + (delay as Int) + "s.")
	EndIf
EndFunction

; Healing spells can end bleedout even with SetNoBleedoutRecovery — knock HP back down.
Function KeepBleedoutDown(Actor dummy)
	If !dummy || !IsDownWaiting() || dummy.IsDead()
		Return
	EndIf
	dummy.SetNoBleedoutRecovery(True)
	Float hp = dummy.GetActorValue("Health")
	If hp > 1.0
		dummy.DamageActorValue("Health", hp)
		hp = dummy.GetActorValue("Health")
	EndIf
	LastHealth = hp
EndFunction

; Heal now / timer — end wait, resurrect if needed, fill HP.
Function RecoverNow()
	FinishDownRecovery(GetActorReference())
EndFunction

Function FinishDownRecovery(Actor dummy = None)
	If !dummy
		dummy = GetActorReference()
	EndIf
	DownUntil = 0.0
	If !dummy
		Return
	EndIf
	If DummyQuest
		MaxHealth = DummyQuest.EffectiveMaxHealth()
		DummyQuest.ApplyImmortality(dummy)
	EndIf
	Bool wasDead = dummy.IsDead()
	If wasDead
		dummy.Resurrect()
	EndIf
	dummy.SetNoBleedoutRecovery(False)
	If DummyQuest
		DummyQuest.ApplyHealth(dummy, MaxHealth, MaxHealth)
	Else
		dummy.RestoreActorValue("Health", MaxHealth)
	EndIf
	LastHealth = MaxHealth
	; HoldStill clears DownUntil; re-pin without wiping the get-up passes below.
	If !dummy.IsDead()
		dummy.StopCombat()
	EndIf
	RememberAnchor(dummy)
	PinInPlace(dummy)
	WatchingCombat = False
	EnsurePinWatch(dummy)
	; Engine get-up packages clear pins; keep reasserting while calm timer runs.
	PosturePassesLeft = 5
	NoteDamage()
	String verb = "bleedout heal"
	If wasDead
		verb = "resurrect"
	EndIf
	String line = "--- " + verb + " hp=" + (MaxHealth as Int) + " ---"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogLine(line)
	If DummyQuest
		DummyQuest.Notify("Dummy stood back up.")
	Else
		Debug.Notification("Dummy stood back up.")
	EndIf
EndFunction

Event OnUpdate()
	Actor dummy = GetActorReference()
	If !dummy
		StopPinWatch()
		Return
	EndIf

	If IsDownWaiting()
		; Timed wait only — negative DownUntil means stay down until Heal now.
		If DownUntil > 0.0 && Utility.GetCurrentRealTime() >= DownUntil
			FinishDownRecovery(dummy)
		ElseIf !dummy.IsDead()
			KeepBleedoutDown(dummy)
			PinInPlace(dummy)
		EndIf
	ElseIf !dummy.IsDead()
		PinInPlace(dummy)
		; CastAs / Cast an aura apply effects without OnHit — catch HP drops here.
		; OOC HealRate is stripped by size (~0.7% max/s); real aura heals remain.
		ReportHealthDrop(dummy, "aura/poll")
	EndIf

	If WatchingCombat && !dummy.IsDead()
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

	If PinWatchActive || WatchingCombat || PosturePassesLeft > 0 || IsDownWaiting()
		Float interval = PinInterval
		If interval < 0.1
			interval = 0.1
		EndIf
		RegisterForSingleUpdate(interval)
	EndIf
EndEvent

; Logs damage or healing when HP changes without an OnHit (Cast an aura CastAs path).
Function ReportHealthDrop(Actor dummy, String sourceName)
	If !dummy || dummy.IsDead()
		Return
	EndIf
	Float now = Utility.GetCurrentRealTime()
	Float elapsed = now - LastPollRealTime
	If elapsed < 0.0
		elapsed = 0.0
	EndIf
	LastPollRealTime = now
	Float remaining = dummy.GetActorValue("Health")
	Float delta = LastHealth - remaining
	If delta < 0.5 && delta > -0.5
		Return
	EndIf
	If delta > 0.0
		LastHealth = remaining
		Int dmgInt = delta as Int
		String line = "hit target=" + SlotTag() + " dmg=" + dmgInt + " source=" + sourceName + " aggressor=?"
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
	; Strip the expected OOC HealRate slice; keep the rest (aura / CastAs ticks).
	Float undone = TrainingDummyUI.StripPollRegen(dummy, heal, elapsed)
	If undone > 0.0
		heal -= undone
		remaining -= undone
	EndIf
	If heal < 0.5
		LastHealth = remaining
		Return
	EndIf
	LastHealth = remaining
	Int healInt = heal as Int
	String line = "heal target=" + SlotTag() + " amt=" + healInt + " source=" + sourceName + " aggressor=?"
	Debug.TraceUser("TrainingDummy", line)
	TrainingDummyUI.LogHit(0.0 - heal, line)
	If DummyQuest
		DummyQuest.Notify("Dummy heal: " + healInt)
	Else
		Debug.Notification("Dummy heal: " + healInt)
	EndIf
EndFunction

; M1..M3 / F1..F3 from the quest alias grid.
String Function SlotTag()
	If DummyQuest
		Return DummyQuest.SlotTagForAlias(Self as ReferenceAlias)
	EndIf
	Return "?"
EndFunction

; Pin without breaking combat — restrained stops the run-in-place.
; Snap back if combat packages shoved them off the spawn spot.
Function PinInPlace(Actor dummy)
	If !dummy || dummy.IsDead()
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
	If !dummy.IsDead()
		dummy.StopCombat()
	EndIf
	RememberAnchor(dummy)
	If !dummy.IsDead()
		PinInPlace(dummy)
	EndIf
	WatchingCombat = False
	PosturePassesLeft = 0
	ClearDownWait(dummy)
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
		DummyQuest.ApplyImmortality(dummy)
		If dummy.IsDead()
			dummy.Resurrect()
		EndIf
		DummyQuest.ApplyHealth(dummy, maxHp, startHp)
	Else
		level = Game.GetPlayer().GetLevel()
		maxHp = (level as Float) * 50.0
		startHp = maxHp
		If dummy.IsDead()
			dummy.Resurrect()
		EndIf
		dummy.SetActorValue("Health", maxHp)
		dummy.RestoreActorValue("Health", maxHp)
	EndIf
	MaxHealth = maxHp
	dummy.SetGhost(False)
	HoldStill(dummy)
	TrainingDummyUI.SetActorLevel(dummy, level)
	LastHealth = startHp
	LastPollRealTime = Utility.GetCurrentRealTime()
EndFunction

ScriptName TrainingDummyUI Hidden
{SKSE natives implemented by TrainingDummyUI.dll.}

Function LogLine(String asLine) global native
; afDamage > 0 = hit, afDamage < 0 = heal (magnitude is the absolute amount).
Function LogHit(Float afDamage, String asLine) global native
; Actor.SetLevel does not exist in vanilla/SKSE Papyrus — this writes the
; unique TESNPC base level so GetLevel() matches (HP is still set in script).
Function SetActorLevel(Actor akActor, Int aiLevel) global native
; Per-instance FULL name (shared ActorBases can't hold three distinct names).
Function SetDisplayName(Actor akActor, String asName) global native
; Undo small poll-only HP gains (engine OOC regen). Larger pulses pass through.
Bool Function ClampPollHeal(Actor akActor, Float afHealAmount) global native

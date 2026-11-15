ScriptName TrainingDummyUI Hidden
{SKSE natives implemented by TrainingDummyUI.dll.}

Function LogLine(String asLine) global native
Function LogHit(Float afDamage, String asLine) global native
; Actor.SetLevel does not exist in vanilla/SKSE Papyrus — this writes the
; unique TESNPC base level so GetLevel() matches (HP is still set in script).
Function SetActorLevel(Actor akActor, Int aiLevel) global native

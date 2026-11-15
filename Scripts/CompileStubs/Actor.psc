Scriptname Actor extends ObjectReference Hidden
{Compile-only stub. Never shipped; the game has the real script.}

Function SetGhost(Bool abIsGhost) native
Function EnableAI(Bool abEnable) native
Function SetLevel(Int aiNewLevel) native
Function SetActorValue(String asValueName, Float afValue) native
Function RestoreActorValue(String asValueName, Float afAmount) native
Float Function GetActorValue(String asValueName) native
Int Function GetLevel() native
Bool Function HasSpell(Form akForm) native
Bool Function AddSpell(Spell akSpell, Bool abVerbose = True) native
Int Function AddItem(Form akItem, Int aiCount = 1, Bool abSilent = False) native
ActorBase Function GetActorBase() native

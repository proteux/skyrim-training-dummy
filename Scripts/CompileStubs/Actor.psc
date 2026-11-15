Scriptname Actor extends ObjectReference Hidden
{Compile-only stub. Never shipped; the game has the real script.}

Function SetGhost(Bool abIsGhost) native
Function EnableAI(Bool abEnable) native
Function SetDontMove(Bool abDontMove) native
Function SetRestrained(Bool abRestrained) native
Function StopCombat() native
Bool Function IsInCombat() native
Function SetActorValue(String asValueName, Float afValue) native
Function RestoreActorValue(String asValueName, Float afAmount) native
Function DamageActorValue(String asValueName, Float afAmount) native
Float Function GetActorValue(String asValueName) native
Int Function GetLevel() native
Bool Function HasSpell(Form akForm) native
Bool Function AddSpell(Spell akSpell, Bool abVerbose = True) native
Bool Function RemoveSpell(Spell akSpell) native
Int Function AddItem(Form akItem, Int aiCount = 1, Bool abSilent = False) native
Function EquipItem(Form akItem, Bool abPreventRemoval = False, Bool abSilent = False) native
Function UnequipAll() native
Function SetRelationshipRank(Actor akOther, Int aiRank) native
Function AddToFaction(Faction akFaction) native
Function RemoveFromFaction(Faction akFaction) native
Bool Function IsInFaction(Faction akFaction) native
Function SetCrimeFaction(Faction akFaction) native
ActorBase Function GetActorBase() native

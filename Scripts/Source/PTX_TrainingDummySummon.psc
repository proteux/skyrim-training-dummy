ScriptName PTX_TrainingDummySummon extends ActiveMagicEffect
{Self spell: spawn the configured dummy in front of the caster.}

PTX_TrainingDummyQuest Property DummyQuest Auto
ActorBase Property DummyBase Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Actor caster = akCaster
	If !caster
		caster = akTarget
	EndIf
	If !caster
		caster = Game.GetPlayer()
	EndIf
	If DummyQuest && DummyBase && caster
		DummyQuest.SpawnInFrontOf(caster, DummyBase)
	Else
		Debug.Notification("Training Dummy: summon missing quest or base.")
	EndIf
EndEvent

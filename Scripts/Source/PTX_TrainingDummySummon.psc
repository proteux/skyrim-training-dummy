ScriptName PTX_TrainingDummySummon extends ActiveMagicEffect
{Self spell: spawn the next free (or replace) slot for that gender.}

PTX_TrainingDummyQuest Property DummyQuest Auto
Bool Property IsFemale Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If !DummyQuest
		Debug.Notification("Training Dummy: summon missing quest.")
		Return
	EndIf
	If IsFemale
		DummyQuest.SummonFemale()
	Else
		DummyQuest.SummonMale()
	EndIf
EndEvent

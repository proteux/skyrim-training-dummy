ScriptName PTX_TrainingDummyDismiss extends ActiveMagicEffect
{Self spell: remove the current training dummy.}

PTX_TrainingDummyQuest Property DummyQuest Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If DummyQuest
		DummyQuest.ClearDummy()
		Debug.Notification("Training Dummies dismissed.")
	Else
		Debug.Notification("Training Dummy: dismiss missing quest property.")
	EndIf
EndEvent

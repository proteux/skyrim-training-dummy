#include "game/PapyrusNatives.h"

#include "game/CombatLog.h"

namespace tdui::game {
    namespace {
        constexpr const char* kScript = "TrainingDummyUI";

        void LogLine(RE::StaticFunctionTag*, RE::BSFixedString line) {
            if (!line.c_str() || line.c_str()[0] == '\0') {
                return;
            }
            CombatLog::Get().Push(0.0f, std::string(line.c_str()));
        }

        void LogHit(RE::StaticFunctionTag*, float damage, RE::BSFixedString line) {
            std::string text = line.c_str() ? std::string(line.c_str()) : std::string{};
            if (text.empty()) {
                if (damage < 0.0f) {
                    text = std::format("heal amt={}", static_cast<int>(-damage));
                } else {
                    text = std::format("hit dmg={}", static_cast<int>(damage));
                }
            }
            CombatLog::Get().Push(damage, std::move(text));
        }

        void SetActorLevel(RE::StaticFunctionTag*, RE::Actor* actor, std::int32_t level) {
            if (!actor) {
                return;
            }
            level = std::clamp(level, 1, 10000);
            auto* npc = actor->GetActorBase();
            if (!npc) {
                logger::warn("SetActorLevel: no actor base for {:08X}", actor->GetFormID());
                return;
            }
            // Fixed level (not PC×mult). Bases are shared by up to 3 instances each;
            // mutating level on the ActorBase is intentional for these dummy FormIDs.
            npc->actorData.actorBaseFlags.reset(RE::ACTOR_BASE_DATA::Flag::kPCLevelMult);
            npc->actorData.level = static_cast<std::uint16_t>(level);
            npc->actorData.calcLevelMin = 0;
            npc->actorData.calcLevelMax = 0;
        }

        // Per-instance name: shared ActorBases can't hold distinct FULL names.
        void SetDisplayName(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString name) {
            if (!actor || !name.c_str() || name.c_str()[0] == '\0') {
                return;
            }
            actor->SetDisplayName(name, true);
        }

        // Undo only the expected out-of-combat HealRate slice of a poll heal.
        // Vanilla ~0.7% max HP/s; ForceAV on HealRate does not stop the engine.
        // In combat the engine already suppresses HealRate, so this is a no-op.
        // Returns how much HP was damaged back (0 = nothing stripped).
        float StripPollRegen(RE::StaticFunctionTag*, RE::Actor* actor, float healAmount, float elapsedSeconds) {
            if (!actor || healAmount <= 0.0f) {
                return 0.0f;
            }
            if (actor->IsInCombat()) {
                return 0.0f;
            }
            auto* values = actor->AsActorValueOwner();
            if (!values) {
                return 0.0f;
            }
            const float maxHp = values->GetBaseActorValue(RE::ActorValue::kHealth);
            // Cap elapsed so a long hitch can't eat a real heal burst.
            const float dt = std::clamp(elapsedSeconds, 0.0f, 1.0f);
            // 0.7%/s × 1.25 slack for hitchy polls / race variation.
            const float expected = maxHp * 0.007f * 1.25f * dt;
            const float undone = std::min(healAmount, expected);
            if (undone > 0.0f) {
                values->DamageActorValue(RE::ActorValue::kHealth, undone);
            }
            return undone;
        }

        bool Register(RE::BSScript::IVirtualMachine* vm) {
            vm->RegisterFunction("LogLine", kScript, LogLine);
            vm->RegisterFunction("LogHit", kScript, LogHit);
            vm->RegisterFunction("SetActorLevel", kScript, SetActorLevel);
            vm->RegisterFunction("SetDisplayName", kScript, SetDisplayName);
            vm->RegisterFunction("StripPollRegen", kScript, StripPollRegen);
            logger::info("Registered Papyrus natives on {}", kScript);
            return true;
        }
    }

    void RegisterPapyrusNatives() {
        if (!SKSE::GetPapyrusInterface()->Register(Register)) {
            logger::error("Could not register Papyrus natives on {}", kScript);
        }
    }
}

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

        // Papyrus SetActorValue on HealRate is ignored / overwritten; force the
        // permanent modifier so current == 0 (idempotent if called every pin tick).
        void ForceAvTo(RE::ActorValueOwner* values, RE::ActorValue av, float target) {
            values->SetBaseActorValue(av, target);
            const float current = values->GetActorValue(av);
            const float delta = target - current;
            if (delta > 0.001f || delta < -0.001f) {
                values->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kPermanent, av, delta);
            }
        }

        void KillEngineRegen(RE::StaticFunctionTag*, RE::Actor* actor) {
            if (!actor) {
                return;
            }
            auto* values = actor->AsActorValueOwner();
            if (!values) {
                return;
            }
            ForceAvTo(values, RE::ActorValue::kHealRate, 0.0f);
            ForceAvTo(values, RE::ActorValue::kHealRateMult, 0.0f);
        }

        bool Register(RE::BSScript::IVirtualMachine* vm) {
            vm->RegisterFunction("LogLine", kScript, LogLine);
            vm->RegisterFunction("LogHit", kScript, LogHit);
            vm->RegisterFunction("SetActorLevel", kScript, SetActorLevel);
            vm->RegisterFunction("SetDisplayName", kScript, SetDisplayName);
            vm->RegisterFunction("KillEngineRegen", kScript, KillEngineRegen);
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

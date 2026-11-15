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

        // Undo small poll-only HP gains from engine OOC regen. Larger pulses (blessing /
        // aura CastAs) are left alone so heal testing still works. OnHit heals never
        // reach this path. ForceAV on HealRate does not stop engine regen.
        bool ClampPollHeal(RE::StaticFunctionTag*, RE::Actor* actor, float healAmount) {
            if (!actor || healAmount <= 0.0f) {
                return false;
            }
            auto* values = actor->AsActorValueOwner();
            if (!values) {
                return false;
            }
            const float maxHp = values->GetBaseActorValue(RE::ActorValue::kHealth);
            // Vanilla HealRate ~0.7%/s; pin poll ~0.25s → ~0.175% of max. Allow slack
            // for hitchy frames; anything bigger is treated as a real heal.
            const float regenCap = std::max(8.0f, maxHp * 0.01f);
            if (healAmount > regenCap) {
                return false;
            }
            values->DamageActorValue(RE::ActorValue::kHealth, healAmount);
            return true;
        }

        bool Register(RE::BSScript::IVirtualMachine* vm) {
            vm->RegisterFunction("LogLine", kScript, LogLine);
            vm->RegisterFunction("LogHit", kScript, LogHit);
            vm->RegisterFunction("SetActorLevel", kScript, SetActorLevel);
            vm->RegisterFunction("SetDisplayName", kScript, SetDisplayName);
            vm->RegisterFunction("ClampPollHeal", kScript, ClampPollHeal);
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

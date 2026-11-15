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
                text = std::format("hit dmg={}", static_cast<int>(damage));
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
            // Fixed level (not PC×mult). Unique dummy bases are safe to mutate;
            // only one male / female instance uses each FormID.
            npc->actorData.actorBaseFlags.reset(RE::ACTOR_BASE_DATA::Flag::kPCLevelMult);
            npc->actorData.level = static_cast<std::uint16_t>(level);
            npc->actorData.calcLevelMin = 0;
            npc->actorData.calcLevelMax = 0;
        }

        bool Register(RE::BSScript::IVirtualMachine* vm) {
            vm->RegisterFunction("LogLine", kScript, LogLine);
            vm->RegisterFunction("LogHit", kScript, LogHit);
            vm->RegisterFunction("SetActorLevel", kScript, SetActorLevel);
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

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

        bool Register(RE::BSScript::IVirtualMachine* vm) {
            vm->RegisterFunction("LogLine", kScript, LogLine);
            vm->RegisterFunction("LogHit", kScript, LogHit);
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

#include "game/DummyBridge.h"

#include "game/Papyrus.h"

namespace tdui::game {
    namespace {
        DummySlotStatus ReadActor(RE::FormID formId) {
            DummySlotStatus s;
            if (formId == 0) {
                return s;
            }
            auto* form = RE::TESForm::LookupByID(formId);
            auto* actor = form ? form->As<RE::Actor>() : nullptr;
            if (!actor) {
                return s;
            }
            s.present = true;
            s.level = static_cast<int>(actor->GetLevel());
            if (auto* values = actor->AsActorValueOwner()) {
                s.health = values->GetActorValue(RE::ActorValue::kHealth);
                s.maxHealth = values->GetBaseActorValue(RE::ActorValue::kHealth);
            }
            return s;
        }

        std::int32_t IntFromVar(const RE::BSScript::Variable& r) {
            return r.IsInt() ? r.GetSInt() : 0;
        }
    }

    DummyBridge& DummyBridge::Get() {
        static DummyBridge instance;
        return instance;
    }

    void DummyBridge::RunOnGame(std::function<void()> fn) {
        if (auto* tasks = SKSE::GetTaskInterface()) {
            tasks->AddTask(std::move(fn));
        }
    }

    RE::TESForm* DummyBridge::QuestForm() const {
        auto* data = RE::TESDataHandler::GetSingleton();
        return data ? data->LookupForm(kQuestId, kEsp) : nullptr;
    }

    DummyStatus DummyBridge::Status() const {
        std::scoped_lock lock(statusMutex_);
        return status_;
    }

    void DummyBridge::OnDataLoaded() {
        if (QuestForm()) {
            logger::info("{} quest 0x{:X} found", kEsp, kQuestId);
        } else {
            logger::warn("{} quest 0x{:X} not found; UI actions will no-op until the esp is loaded", kEsp, kQuestId);
        }
    }

    void DummyBridge::CallQuest(const char* fn) {
        RunOnGame([this, fn] {
            auto* quest = QuestForm();
            if (!quest) {
                logger::warn("Call {}.{} skipped: quest missing", kQuestScript, fn);
                return;
            }
            CallMethod(quest, kQuestScript, fn, {});
        });
    }

    void DummyBridge::CallQuestSettings(const io::UiSettings& settings) {
        RunOnGame([this, settings] {
            auto* quest = QuestForm();
            if (!quest) {
                return;
            }
            CallMethod(quest, kQuestScript, "ApplyUiSettings", {}, settings.matchPlayer,
                static_cast<std::int32_t>(settings.level), settings.healthPerLevel, settings.healthStartPercent,
                settings.immortal, settings.downSeconds, settings.muteNotifications,
                static_cast<std::int32_t>(settings.relationshipRank));
        });
    }

    void DummyBridge::ApplySettings(const io::UiSettings& settings) {
        {
            std::scoped_lock lock(settingsMutex_);
            lastSettings_ = settings;
            hasSettings_ = true;
        }
        CallQuestSettings(settings);
    }

    void DummyBridge::SummonAfterSettings(const char* fn) {
        RunOnGame([this, fn] {
            auto* quest = QuestForm();
            if (!quest) {
                logger::warn("Call {}.{} skipped: quest missing", kQuestScript, fn);
                return;
            }
            io::UiSettings settings;
            bool apply = false;
            {
                std::scoped_lock lock(settingsMutex_);
                if (hasSettings_) {
                    settings = lastSettings_;
                    apply = true;
                }
            }
            if (!apply) {
                CallMethod(quest, kQuestScript, fn, {});
                return;
            }
            // Prime start-% / level without reasserting live dummies, then summon.
            CallMethod(quest, kQuestScript, "ApplyUiSettings",
                [quest, fn](const RE::BSScript::Variable&) {
                    CallMethod(quest, kQuestScript, fn, {});
                },
                settings.matchPlayer, static_cast<std::int32_t>(settings.level), settings.healthPerLevel,
                settings.healthStartPercent, settings.immortal, settings.downSeconds, settings.muteNotifications,
                static_cast<std::int32_t>(settings.relationshipRank), false);
        });
    }

    void DummyBridge::SummonMale() { SummonAfterSettings("SummonMale"); }
    void DummyBridge::SummonFemale() { SummonAfterSettings("SummonFemale"); }
    void DummyBridge::Dismiss() { CallQuest("ClearDummy"); }
    void DummyBridge::GiveSpells() { CallQuest("GivePlayerSpells"); }
    void DummyBridge::RemoveSpells() { CallQuest("RemovePlayerSpells"); }
    void DummyBridge::HealNow() { CallQuest("HealLiveDummies"); }

    // Walk male 0..2, then female 0..2, then PlayerHasSpells.
    void DummyBridge::FetchNextSlot(RE::TESForm* quest, std::shared_ptr<DummyStatus> st, int step) {
        if (!quest || !st) {
            return;
        }
        if (step < kMaxPerGender) {
            CallMethod(quest, kQuestScript, "GetMaleFormID", [this, quest, st, step](const RE::BSScript::Variable& r) {
                st->male[step] = ReadActor(static_cast<RE::FormID>(IntFromVar(r)));
                FetchNextSlot(quest, st, step + 1);
            }, static_cast<std::int32_t>(step));
            return;
        }
        const int femaleStep = step - kMaxPerGender;
        if (femaleStep < kMaxPerGender) {
            CallMethod(quest, kQuestScript, "GetFemaleFormID", [this, quest, st, step, femaleStep](const RE::BSScript::Variable& r) {
                st->female[femaleStep] = ReadActor(static_cast<RE::FormID>(IntFromVar(r)));
                FetchNextSlot(quest, st, step + 1);
            }, static_cast<std::int32_t>(femaleStep));
            return;
        }
        CallMethod(quest, kQuestScript, "PlayerHasSpells", [this, st](const RE::BSScript::Variable& r) {
            st->hasSpells = r.IsBool() && r.GetBool();
            st->fresh = true;
            std::scoped_lock lock(statusMutex_);
            status_ = *st;
        });
    }

    void DummyBridge::RefreshStatus() {
        const auto now = std::chrono::steady_clock::now();
        if (now - lastStatus_ < 250ms) {
            return;
        }
        lastStatus_ = now;

        RunOnGame([this] {
            auto* quest = QuestForm();
            if (!quest) {
                DummyStatus next;
                next.fresh = true;
                std::scoped_lock lock(statusMutex_);
                status_ = next;
                return;
            }

            auto st = std::make_shared<DummyStatus>();
            st->questLoaded = true;
            FetchNextSlot(quest, st, 0);
        });
    }
}

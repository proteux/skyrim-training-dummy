#pragma once

#include "io/UiSettings.h"

namespace tdui::game {
    inline constexpr const char* kEsp = "PTX_TrainingDummy.esp";
    inline constexpr const char* kQuestScript = "PTX_TrainingDummyQuest";
    inline constexpr RE::FormID kQuestId = 0x800;
    inline constexpr int kMaxPerGender = 3;

    struct DummySlotStatus {
        bool present = false;
        int level = 0;
        float health = 0.0f;
        float maxHealth = 0.0f;
    };

    struct DummyStatus {
        bool questLoaded = false;
        bool hasSpells = false;
        DummySlotStatus male[kMaxPerGender]{};
        DummySlotStatus female[kMaxPerGender]{};
        bool fresh = false;
    };

    class DummyBridge {
    public:
        static DummyBridge& Get();

        void OnDataLoaded();
        void RefreshStatus();
        DummyStatus Status() const;

        void ApplySettings(const io::UiSettings& settings);
        void SummonMale();
        void SummonFemale();
        void Dismiss();
        void GiveSpells();
        void RemoveSpells();
        void HealNow();

        static void RunOnGame(std::function<void()> fn);

    private:
        RE::TESForm* QuestForm() const;
        void CallQuest(const char* fn);
        void CallQuestSettings(const io::UiSettings& settings);
        void SummonAfterSettings(const char* fn);
        void FetchNextSlot(RE::TESForm* quest, std::shared_ptr<DummyStatus> st, int step);

        mutable std::mutex statusMutex_;
        DummyStatus status_;
        std::chrono::steady_clock::time_point lastStatus_{};

        mutable std::mutex settingsMutex_;
        io::UiSettings lastSettings_{};
        bool hasSettings_ = false;
    };
}

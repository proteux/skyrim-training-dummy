#include "ui/App.h"

#include "Version.h"
#include "game/CombatLog.h"
#include "game/DummyBridge.h"

namespace tdui::ui {
    using namespace ImGuiMCP;

    namespace {
        constexpr ImVec4 kWarn{ 0.95f, 0.75f, 0.30f, 1.0f };
        constexpr ImVec4 kDamage{ 0.95f, 0.45f, 0.30f, 1.0f };
        constexpr ImVec4 kHeal{ 0.40f, 0.85f, 0.50f, 1.0f };
        constexpr int kMeterBuckets = 40;
        constexpr float kMeterWindowSec = 10.0f;

        void SlotCell(const game::DummySlotStatus& s) {
            if (s.present) {
                Text("%.0f / %.0f", s.health, s.maxHealth);
            } else {
                TextDisabled("%s", "-");
            }
        }

        void GenderRow(const char* gender, const game::DummySlotStatus (&slots)[game::kMaxPerGender]) {
            TableNextRow();
            TableNextColumn();
            TextUnformatted(gender);
            for (const auto& s : slots) {
                TableNextColumn();
                SlotCell(s);
            }
        }

        // Wall-clock buckets so the plot scrolls with time; values are per-second rates.
        void FillRateBuckets(const std::vector<game::LogEntry>& lines, float* damageOut, float* healOut) {
            std::fill(damageOut, damageOut + kMeterBuckets, 0.0f);
            std::fill(healOut, healOut + kMeterBuckets, 0.0f);
            const auto now = std::chrono::steady_clock::now();
            const float bucketSec = kMeterWindowSec / static_cast<float>(kMeterBuckets);
            for (const auto& e : lines) {
                const float age = std::chrono::duration<float>(now - e.time).count();
                if (age < 0.0f || age >= kMeterWindowSec) {
                    continue;
                }
                const int idx = std::clamp(
                    static_cast<int>((kMeterWindowSec - age) / bucketSec), 0, kMeterBuckets - 1);
                if (e.damage > 0.0f) {
                    damageOut[idx] += e.damage;
                } else if (e.damage < 0.0f) {
                    healOut[idx] += -e.damage;
                }
            }
            const float invBucket = 1.0f / bucketSec;
            for (int i = 0; i < kMeterBuckets; ++i) {
                damageOut[i] *= invBucket;
                healOut[i] *= invBucket;
            }
        }

        float SeriesPeak(const float* values, int count) {
            float peak = 0.0f;
            for (int i = 0; i < count; ++i) {
                peak = std::max(peak, values[i]);
            }
            return peak;
        }

        void DrawMeterHeading(const char* label, float rate10, float rate5, const ImVec4& color) {
            TextColored(color, "%s", label);
            SameLine();
            Text("%.1f/s", rate10);
            TextDisabled("5s %.1f/s", rate5);
        }

        void DrawMeterPlot(const char* plotId, const float* buckets, float scaleMax, const ImVec4& color) {
            PushStyleColor(ImGuiCol_PlotHistogram, color);
            // No overlay — the heading already shows the rate; empty label keeps the plot full-width.
            PlotHistogram(plotId, buckets, kMeterBuckets, 0, nullptr, 0.0f, scaleMax, ImVec2{ -1.0f, 88.0f });
            PopStyleColor();
        }
    }

    std::filesystem::path GameDataDir() {
        wchar_t exe[MAX_PATH] = {};
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        return std::filesystem::path(exe).parent_path() / L"Data";
    }

    App& App::Get() {
        static App instance;
        return instance;
    }

    void App::Init() {
        settingsPath_ = GameDataDir() / "SKSE" / "Plugins" / "TrainingDummyUI" / "settings.json";
        settings_.Load(settingsPath_);
        PushSettingsToGame();
        logger::info("Training Dummy UI {} ready", kVersion);
    }

    void App::SaveSettings() {
        if (!settings_.Save(settingsPath_)) {
            logger::warn("Could not save {}", settingsPath_.string());
        }
    }

    void App::PushSettingsToGame() {
        game::DummyBridge::Get().ApplySettings(settings_);
    }

    void App::BeginFrame() {
        const int frame = GetFrameCount();
        if (frame == frame_) {
            return;
        }
        frame_ = frame;
        game::DummyBridge::Get().RefreshStatus();
    }

    void App::DrawSection() {
        BeginFrame();
        TextUnformatted("Training Dummy");
        SameLine();
        TextDisabled("UI %s", kVersion);
        Spacing();
        if (window_) {
            bool open = window_->IsOpen.load();
            if (Checkbox("Open window", &open)) {
                window_->IsOpen = open;
            }
            TextDisabled("Pause game is fixed at registration (restart Skyrim after changing it).");
            if (Checkbox("Pause game while window open", &settings_.pauseGame)) {
                SaveSettings();
            }
        }
        Separator();
        DrawControls(false);
        Separator();
        DrawStatus();
        Separator();
        DrawCombatTabs();
    }

    void App::DrawWindow() {
        if (!window_ || !window_->IsOpen.load()) {
            return;
        }
        BeginFrame();
        bool open = true;
        SetNextWindowSize(ImVec2{ 520, 640 }, ImGuiCond_FirstUseEver);
        if (Begin("Training Dummy", &open)) {
            DrawControls(true);
            Separator();
            DrawStatus();
            Separator();
            DrawCombatTabs();
        }
        End();
        if (!open) {
            window_->IsOpen = false;
        }
    }

    void App::DrawControls(bool windowMode) {
        auto& bridge = game::DummyBridge::Get();

        if (Button("Summon Male")) {
            bridge.SummonMale();
        }
        SameLine();
        if (Button("Summon Female")) {
            bridge.SummonFemale();
        }
        SameLine();
        if (Button("Dismiss")) {
            bridge.Dismiss();
        }
        SameLine();
        if (Button("Heal now")) {
            bridge.HealNow();
        }

        if (!windowMode) {
            if (Button("Add spells")) {
                bridge.GiveSpells();
            }
            SameLine();
            if (Button("Remove spells")) {
                bridge.RemoveSpells();
            }
            Spacing();
            DrawSummonSettings();
            return;
        }

        Spacing();
        if (CollapsingHeader("Summon settings")) {
            DrawSummonSettings();
        }
    }

    void App::DrawSummonSettings() {
        bool settingsDirty = false;
        if (Checkbox("Match player level", &settings_.matchPlayer)) {
            settingsDirty = true;
        }
        BeginDisabled(settings_.matchPlayer);
        SetNextItemWidth(180);
        SliderInt("Level", &settings_.level, 1, 100);
        if (IsItemDeactivatedAfterEdit()) {
            settingsDirty = true;
        }
        EndDisabled();

        SetNextItemWidth(180);
        SliderFloat("Health per level", &settings_.healthPerLevel, 1.0f, 500.0f, "%.0f");
        if (IsItemDeactivatedAfterEdit()) {
            settingsDirty = true;
        }

        SetNextItemWidth(180);
        SliderFloat("Start at % HP", &settings_.healthStartPercent, 1.0f, 100.0f, "%.0f%%");
        if (IsItemDeactivatedAfterEdit()) {
            settingsDirty = true;
        }

        if (Checkbox("Immortal", &settings_.immortal)) {
            settingsDirty = true;
        }
        TextDisabled(settings_.immortal ? "Essential: kneel on 0 HP, then recover."
                                       : "Mortal: die on 0 HP, then Resurrect.");

        SetNextItemWidth(180);
        SliderFloat("Down time", &settings_.downSeconds, 0.0f, 60.0f, "%.0f s");
        if (IsItemDeactivatedAfterEdit()) {
            settingsDirty = true;
        }
        TextDisabled("Seconds down before full recovery (0 = until Heal now).");

        if (settings_.matchPlayer) {
            TextDisabled("Max HP = player level x %.0f; start at %.0f%%", settings_.healthPerLevel,
                settings_.healthStartPercent);
        } else {
            TextDisabled("Max HP = %d x %.0f = %.0f; start at %.0f%%", settings_.level, settings_.healthPerLevel,
                settings_.level * settings_.healthPerLevel, settings_.healthStartPercent);
        }

        // Ranks match Actor.SetRelationshipRank / the Creation Kit.
        // Faction tag: Rival+ = Enemy pack, Acquaintance = Neutral, Friend+ = Ally pack.
        static constexpr const char* kRankLabels[] = {
            "Archnemesis (-4) - Enemy Faction",
            "Enemy (-3) - Enemy Faction",
            "Rival (-2) - Enemy Faction",
            "Acquaintance (-1) - Neutral Faction",
            "Friend (0) - Ally Faction",
            "Confidant (1) - Ally Faction",
            "Ally (2) - Ally Faction",
            "Lover (3) - Ally Faction",
        };
        const int rankIndex = std::clamp(settings_.relationshipRank + 4, 0, 7);
        SetNextItemWidth(320);
        if (BeginCombo("vs player", kRankLabels[rankIndex])) {
            for (int i = 0; i < 8; ++i) {
                const bool selected = i == rankIndex;
                if (Selectable(kRankLabels[i], selected)) {
                    settings_.relationshipRank = i - 4;
                    settingsDirty = true;
                }
                if (selected) {
                    SetItemDefaultFocus();
                }
            }
            EndCombo();
        }
        TextDisabled("Enemy pack: Ally to each other, Enemy to you. Ally pack: Ally to each other and to you.");

        if (settingsDirty) {
            settings_.level = std::clamp(settings_.level, 1, 1000);
            settings_.healthPerLevel = std::clamp(settings_.healthPerLevel, 1.0f, 10000.0f);
            settings_.healthStartPercent = std::clamp(settings_.healthStartPercent, 1.0f, 100.0f);
            settings_.downSeconds = std::clamp(settings_.downSeconds, 0.0f, 300.0f);
            settings_.relationshipRank = std::clamp(settings_.relationshipRank, -4, 3);
            SaveSettings();
            PushSettingsToGame();
        }
    }

    void App::DrawStatus() {
        const auto& st = game::DummyBridge::Get().Status();
        if (!st.questLoaded) {
            TextColored(kWarn, "PTX_TrainingDummy.esp quest not loaded");
            return;
        }
        if (BeginTable("##slots", 4,
                ImGuiTableFlags_Borders | ImGuiTableFlags_RowBg | ImGuiTableFlags_SizingStretchSame)) {
            TableSetupColumn("##g", ImGuiTableColumnFlags_WidthFixed, 24.0f);
            TableSetupColumn("##0");
            TableSetupColumn("##1");
            TableSetupColumn("##2");
            GenderRow("M", st.male);
            GenderRow("F", st.female);
            EndTable();
        }
    }

    void App::DrawCombatTabs() {
        // Rates first so ImGui opens it by default.
        if (!BeginTabBar("##combat")) {
            return;
        }
        if (BeginTabItem("Rates")) {
            DrawMeters();
            EndTabItem();
        }
        if (BeginTabItem("Log")) {
            DrawLog();
            EndTabItem();
        }
        EndTabBar();
    }

    void App::DrawMeters() {
        const float d5 = game::CombatLog::Get().DamageIn(5s);
        const float d10 = game::CombatLog::Get().DamageIn(10s);
        const float h5 = game::CombatLog::Get().HealingIn(5s);
        const float h10 = game::CombatLog::Get().HealingIn(10s);

        float damageBuckets[kMeterBuckets];
        float healBuckets[kMeterBuckets];
        FillRateBuckets(game::CombatLog::Get().Snapshot(), damageBuckets, healBuckets);
        const float scaleMax = std::max(1.0f, std::max(SeriesPeak(damageBuckets, kMeterBuckets),
                                                 SeriesPeak(healBuckets, kMeterBuckets)) *
                                                 1.15f);

        // Headings and plots are separate rows so both graphs share one baseline
        // even when one column's text wraps.
        if (BeginTable("##meters", 2, ImGuiTableFlags_SizingStretchSame)) {
            TableNextRow();
            TableNextColumn();
            DrawMeterHeading("DPS", d10 / 10.0f, d5 / 5.0f, kDamage);
            TableNextColumn();
            DrawMeterHeading("HPS", h10 / 10.0f, h5 / 5.0f, kHeal);

            TableNextRow();
            TableNextColumn();
            DrawMeterPlot("##dpsplot", damageBuckets, scaleMax, kDamage);
            TableNextColumn();
            DrawMeterPlot("##hpsplot", healBuckets, scaleMax, kHeal);
            EndTable();
        }
    }

    void App::DrawLog() {
        if (Button("Clear log")) {
            game::CombatLog::Get().Clear();
        }
        SameLine();
        if (Button("Copy to clipboard")) {
            const auto lines = game::CombatLog::Get().Snapshot();
            std::string text;
            text.reserve(lines.size() * 48);
            for (const auto& e : lines) {
                text += e.line;
                text += '\n';
            }
            SetClipboardText(text.c_str());
        }
        SameLine();
        Checkbox("Auto-scroll", &autoScroll_);

        const auto lines = game::CombatLog::Get().Snapshot();
        BeginChild("##combatlog", ImVec2{ 0, 0 }, ImGuiChildFlags_Border);
        for (const auto& e : lines) {
            if (e.damage > 0.0f) {
                TextColored(kDamage, "%s", e.line.c_str());
            } else if (e.damage < 0.0f) {
                TextColored(kHeal, "%s", e.line.c_str());
            } else {
                TextUnformatted(e.line.c_str());
            }
        }
        // SetScrollHereY is deferred until EndChild, so never infer "scrolled up"
        // from GetScrollY on the same frame — that was clearing the checkbox.
        if (autoScroll_) {
            SetScrollHereY(1.0f);
        } else if (GetScrollMaxY() <= 0.0f || GetScrollY() >= GetScrollMaxY() - 8.0f) {
            autoScroll_ = true;
        }
        if (IsWindowHovered() && GetIO()->MouseWheel > 0.0f) {
            autoScroll_ = false;
        }
        EndChild();
    }
}

#pragma once

#include "io/UiSettings.h"

#include <filesystem>

namespace tdui::ui {
    std::filesystem::path GameDataDir();

    class App {
    public:
        static App& Get();

        void Init();
        void SetWindow(SKSEMenuFramework::Model::WindowInterface* window) { window_ = window; }

        void DrawSection();
        void DrawWindow();

        void SaveSettings();

    private:
        void BeginFrame();
        void DrawControls(bool windowMode);
        void DrawSummonSettings();
        void DrawStatus();
        void DrawLog();
        void PushSettingsToGame();

        io::UiSettings settings_;
        std::filesystem::path settingsPath_;
        SKSEMenuFramework::Model::WindowInterface* window_ = nullptr;
        int frame_ = -1;
        bool autoScroll_ = true;
        std::size_t lastLogCount_ = 0;
    };
}

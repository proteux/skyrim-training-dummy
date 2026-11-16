// Training Dummy UI
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

#include "Version.h"
#include "game/DummyBridge.h"
#include "game/PapyrusNatives.h"
#include "io/UiSettings.h"
#include "ui/App.h"

namespace {
    void InitLogging() {
        auto dir = SKSE::log::log_directory();
        if (!dir) {
            return;
        }
        try {
            auto path = *dir / "TrainingDummyUI.log";
            auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(path.string(), true);
            auto log = std::make_shared<spdlog::logger>("global", std::move(sink));
            log->set_level(spdlog::level::info);
            log->flush_on(spdlog::level::info);
            log->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] %v");
            spdlog::set_default_logger(std::move(log));
        } catch (...) {
        }
    }

    void __stdcall RenderSection() { tdui::ui::App::Get().DrawSection(); }
    void __stdcall RenderWindow() { tdui::ui::App::Get().DrawWindow(); }

    void RegisterMenu() {
        if (!SKSEMenuFramework::IsInstalled()) {
            logger::error("SKSE Menu Framework is not installed; the Training Dummy menu is unavailable");
            return;
        }
        tdui::io::UiSettings early;
        early.Load(tdui::ui::GameDataDir() / "SKSE" / "Plugins" / "TrainingDummyUI" / "settings.json");

        SKSEMenuFramework::SetSection("Training Dummy");
        SKSEMenuFramework::AddSectionItem("Controls", RenderSection);
        auto* window = SKSEMenuFramework::AddWindow(RenderWindow, early.pauseGame);
        tdui::ui::App::Get().SetWindow(window);
        logger::info("Registered with SKSE Menu Framework {}", SKSEMenuFramework::GetMenuFrameworkVersion());
    }

    void OnMessage(SKSE::MessagingInterface::Message* msg) {
        switch (msg->type) {
        case SKSE::MessagingInterface::kPostLoad:
            RegisterMenu();
            break;
        case SKSE::MessagingInterface::kDataLoaded:
            tdui::game::DummyBridge::Get().OnDataLoaded();
            try {
                tdui::ui::App::Get().Init();
            } catch (const std::exception& e) {
                logger::critical("Training Dummy UI failed to start: {}", e.what());
            }
            break;
        case SKSE::MessagingInterface::kNewGame:
        case SKSE::MessagingInterface::kPostLoadGame:
            // Save restore can overwrite quest Auto properties after kDataLoaded.
            tdui::ui::App::Get().PushSettingsToGame();
            break;
        default:
            break;
        }
    }
}

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    InitLogging();
    logger::info("Training Dummy UI {} starting", tdui::kVersion);
    SKSE::Init(skse);
    if (!SKSE::GetMessagingInterface()->RegisterListener(OnMessage)) {
        logger::error("Could not register for SKSE messages");
        return false;
    }
    tdui::game::RegisterPapyrusNatives();
    return true;
}

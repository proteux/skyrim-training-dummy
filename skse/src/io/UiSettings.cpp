#include "io/UiSettings.h"

#ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#    define NOMINMAX
#endif
#include <Windows.h>

#include <algorithm>
#include <fstream>
#include <limits>
#include <sstream>
#include <system_error>
#include <type_traits>

namespace tdui::io {
    namespace {
        namespace fs = std::filesystem;

        void GetBool(const nlohmann::json& j, const char* key, bool& out) {
            if (auto it = j.find(key); it != j.end() && it->is_boolean()) {
                out = it->get<bool>();
            }
        }

        template <class T>
        void GetNumber(const nlohmann::json& j, const char* key, T& out) {
            if (auto it = j.find(key); it != j.end() && it->is_number()) {
                const double v = it->get<double>();
                if constexpr (std::is_floating_point_v<T>) {
                    if (std::isfinite(v)) {
                        out = static_cast<T>(v);
                    }
                } else if (std::isfinite(v) && v >= static_cast<double>(std::numeric_limits<T>::min()) &&
                           v <= static_cast<double>(std::numeric_limits<T>::max())) {
                    out = static_cast<T>(v);
                }
            }
        }

        std::optional<nlohmann::json> ReadJson(const fs::path& path) {
            std::ifstream in(path, std::ios::binary);
            if (!in) {
                return std::nullopt;
            }
            std::ostringstream ss;
            ss << in.rdbuf();
            try {
                return nlohmann::json::parse(ss.str(), nullptr, true, true);
            } catch (...) {
                return std::nullopt;
            }
        }

        bool WriteTextAtomic(const fs::path& path, const std::string& text) {
            std::error_code ec;
            fs::create_directories(path.parent_path(), ec);
            fs::path tmp = path;
            tmp += ".tdui.tmp";
            HANDLE h = CreateFileW(tmp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
            if (h == INVALID_HANDLE_VALUE) {
                return false;
            }
            DWORD written = 0;
            const bool wrote = WriteFile(h, text.data(), static_cast<DWORD>(text.size()), &written, nullptr) && written == text.size();
            const bool flushed = wrote && FlushFileBuffers(h);
            CloseHandle(h);
            if (!wrote || !flushed) {
                DeleteFileW(tmp.c_str());
                return false;
            }
            if (!MoveFileExW(tmp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
                DeleteFileW(tmp.c_str());
                return false;
            }
            return true;
        }
    }

    void UiSettings::Load(const std::filesystem::path& path) {
        auto j = ReadJson(path);
        if (!j || !j->is_object()) {
            return;
        }
        GetBool(*j, "pauseGame", pauseGame);
        GetBool(*j, "matchPlayer", matchPlayer);
        GetNumber(*j, "level", level);
        GetNumber(*j, "healthPerLevel", healthPerLevel);
        GetNumber(*j, "healthStartPercent", healthStartPercent);
        GetBool(*j, "muteNotifications", muteNotifications);
        GetNumber(*j, "relationshipRank", relationshipRank);
        level = std::clamp(level, 1, 1000);
        healthPerLevel = std::clamp(healthPerLevel, 1.0f, 10000.0f);
        healthStartPercent = std::clamp(healthStartPercent, 1.0f, 100.0f);
        relationshipRank = std::clamp(relationshipRank, -4, 3);
    }

    bool UiSettings::Save(const std::filesystem::path& path) const {
        nlohmann::json j;
        j["pauseGame"] = pauseGame;
        j["matchPlayer"] = matchPlayer;
        j["level"] = level;
        j["healthPerLevel"] = healthPerLevel;
        j["healthStartPercent"] = healthStartPercent;
        j["muteNotifications"] = muteNotifications;
        j["relationshipRank"] = relationshipRank;
        return WriteTextAtomic(path, j.dump(2, ' ', false, nlohmann::json::error_handler_t::replace));
    }
}

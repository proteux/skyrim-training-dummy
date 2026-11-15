#pragma once

#include <filesystem>
#include <string>

namespace tdui::io {
    struct UiSettings {
        bool pauseGame = false;
        bool matchPlayer = true;
        int level = 1;
        float healthPerLevel = 50.0f;
        bool muteNotifications = true;
        // Toward the player: -4 Archnemesis … 3 Lover (default). Use -3 Enemy for harmful Spell auras.
        int relationshipRank = 3;

        void Load(const std::filesystem::path& path);
        bool Save(const std::filesystem::path& path) const;
    };
}

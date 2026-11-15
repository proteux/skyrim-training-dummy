#pragma once

#include <filesystem>
#include <string>

namespace tdui::io {
    struct UiSettings {
        bool pauseGame = false;
        bool matchPlayer = true;
        int level = 1;
        float healthPerLevel = 50.0f;
        // Current HP as % of max on summon / settings reassert (1–100). Heal now still fills to 100%.
        float healthStartPercent = 100.0f;
        bool muteNotifications = true;
        // Toward the player: -4 Archnemesis … 3 Lover (default). Enemy/Archnemesis join a player-only hostile faction for IsHostileToActor.
        int relationshipRank = 3;

        void Load(const std::filesystem::path& path);
        bool Save(const std::filesystem::path& path) const;
    };
}

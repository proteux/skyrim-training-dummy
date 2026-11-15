#pragma once

#include <chrono>
#include <cstddef>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

namespace tdui::game {
    struct LogEntry {
        std::chrono::steady_clock::time_point time{};
        float damage = 0.0f;
        std::string line;
    };

    class CombatLog {
    public:
        static CombatLog& Get();

        // damage > 0 = hit, damage < 0 = heal (stored as negative for window sums).
        void Push(float damage, std::string line);
        void Clear();

        // Snapshot for the UI thread.
        std::vector<LogEntry> Snapshot() const;
        float DamageIn(std::chrono::milliseconds window) const;
        float HealingIn(std::chrono::milliseconds window) const;

        static constexpr std::size_t kMaxLines = 500;

    private:
        mutable std::mutex mutex_;
        std::deque<LogEntry> lines_;
    };
}

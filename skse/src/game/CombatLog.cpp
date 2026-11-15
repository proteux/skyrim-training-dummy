#include "game/CombatLog.h"

namespace tdui::game {
    CombatLog& CombatLog::Get() {
        static CombatLog instance;
        return instance;
    }

    void CombatLog::Push(float damage, std::string line) {
        std::scoped_lock lock(mutex_);
        lines_.push_back(LogEntry{ std::chrono::steady_clock::now(), damage, std::move(line) });
        while (lines_.size() > kMaxLines) {
            lines_.pop_front();
        }
    }

    void CombatLog::Clear() {
        std::scoped_lock lock(mutex_);
        lines_.clear();
    }

    std::vector<LogEntry> CombatLog::Snapshot() const {
        std::scoped_lock lock(mutex_);
        return { lines_.begin(), lines_.end() };
    }

    namespace {
        float SumInWindow(const std::deque<LogEntry>& lines, std::chrono::milliseconds window, bool healing) {
            const auto cutoff = std::chrono::steady_clock::now() - window;
            float sum = 0.0f;
            for (auto it = lines.rbegin(); it != lines.rend(); ++it) {
                if (it->time < cutoff) {
                    break;
                }
                if (healing) {
                    if (it->damage < 0.0f) {
                        sum += -it->damage;
                    }
                } else if (it->damage > 0.0f) {
                    sum += it->damage;
                }
            }
            return sum;
        }
    }

    float CombatLog::DamageIn(std::chrono::milliseconds window) const {
        std::scoped_lock lock(mutex_);
        return SumInWindow(lines_, window, false);
    }

    float CombatLog::HealingIn(std::chrono::milliseconds window) const {
        std::scoped_lock lock(mutex_);
        return SumInWindow(lines_, window, true);
    }
}

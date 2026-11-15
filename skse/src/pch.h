#pragma once

#include "RE/Skyrim.h"
#include "SKSE/SKSE.h"

#ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#    define NOMINMAX
#endif
#include <Windows.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <deque>
#include <filesystem>
#include <format>
#include <fstream>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#ifdef interface
#    undef interface
#endif
#ifdef GetObject
#    undef GetObject
#endif

#include <nlohmann/json.hpp>
#include <spdlog/sinks/basic_file_sink.h>

#include "SKSEMenuFramework.h"

using namespace std::literals;

namespace logger = SKSE::log;

cmake_minimum_required(VERSION 3.21)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION" TDUI_VERSION)
string(STRIP "${TDUI_VERSION}" TDUI_VERSION)

project(TrainingDummyUI VERSION ${TDUI_VERSION} DESCRIPTION "Training Dummy SKSE Menu Framework UI" LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(nlohmann_json CONFIG REQUIRED)
find_package(CommonLibSSE CONFIG REQUIRED)

configure_file(src/Version.h.in "${CMAKE_CURRENT_BINARY_DIR}/generated/Version.h" @ONLY)

add_commonlibsse_plugin(${PROJECT_NAME}
    NAME "TrainingDummyUI"
    AUTHOR "white"
    USE_ADDRESS_LIBRARY
    SOURCES
        src/main.cpp
        src/io/UiSettings.cpp
        src/game/Papyrus.cpp
        src/game/PapyrusNatives.cpp
        src/game/CombatLog.cpp
        src/game/DummyBridge.cpp
        src/ui/App.cpp
)
target_include_directories(${PROJECT_NAME} PRIVATE src include "${CMAKE_CURRENT_BINARY_DIR}/generated")
target_link_libraries(${PROJECT_NAME} PRIVATE nlohmann_json::nlohmann_json)
target_precompile_headers(${PROJECT_NAME} PRIVATE src/pch.h)

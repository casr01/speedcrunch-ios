# SpeedCrunch engine as a static library (Qt Core only) plus a C bridge.
#
# Desktop test build:   cmake -S engine -B build && cmake --build build && ./build/sc-cli "2+2"
# iOS build:            see scripts/build-engine-ios.sh

cmake_minimum_required(VERSION 3.21)
project(SpeedCrunchEngine LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core)

set(UPSTREAM ${CMAKE_CURRENT_SOURCE_DIR}/../upstream)

file(GLOB FLOATNUM_SOURCES ${UPSTREAM}/math/floatnum/*.c)

set(ENGINE_SOURCES
    ${FLOATNUM_SOURCES}
    ${UPSTREAM}/math/number.c
    ${UPSTREAM}/math/hmath.cpp
    ${UPSTREAM}/math/cmath.cpp
    ${UPSTREAM}/math/cnumberparser.cpp
    ${UPSTREAM}/math/rational.cpp
    ${UPSTREAM}/math/quantity.cpp
    ${UPSTREAM}/core/constants.cpp
    ${UPSTREAM}/core/evaluator.cpp
    ${UPSTREAM}/core/functions.cpp
    ${UPSTREAM}/core/mathdsl.cpp
    ${UPSTREAM}/core/numberformatter.cpp
    ${UPSTREAM}/core/opcode.cpp
    ${UPSTREAM}/core/session.cpp
    ${UPSTREAM}/core/sessionhistory.cpp
    ${UPSTREAM}/core/settings.cpp
    ${UPSTREAM}/core/units.cpp
    ${UPSTREAM}/core/unitdisplayformat.cpp
    ${UPSTREAM}/core/userdefinitions.cpp
    ${UPSTREAM}/core/userfunction.cpp
    ${UPSTREAM}/core/userunit.cpp
    ${UPSTREAM}/core/variable.cpp
    ${UPSTREAM}/gui/displayformatutils.cpp
    # Headers with Q_OBJECT so AUTOMOC sees them.
    ${UPSTREAM}/core/constants.h
    ${UPSTREAM}/core/evaluator.h
    ${UPSTREAM}/core/functions.h
    src/speedcrunch_bridge.cpp
    include/speedcrunch_bridge.h
)

add_library(speedcrunch_engine STATIC ${ENGINE_SOURCES})
target_include_directories(speedcrunch_engine
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE ${UPSTREAM} ${UPSTREAM}/math ${UPSTREAM}/core)
target_compile_definitions(speedcrunch_engine PRIVATE SPEEDCRUNCH_HEADLESS QT_USE_QSTRINGBUILDER)
target_link_libraries(speedcrunch_engine PUBLIC Qt6::Core)

if(NOT IOS)
    add_executable(sc-cli cli/main.cpp)
    target_link_libraries(sc-cli PRIVATE speedcrunch_engine)
endif()

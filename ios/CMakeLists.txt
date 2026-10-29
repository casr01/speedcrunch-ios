# SpeedCrunch for iOS — Xcode project generator.
#
# Do not run this directly; use scripts/setup-ios.sh, which installs Qt for iOS
# and calls Qt's qt-cmake wrapper with the Xcode generator.

cmake_minimum_required(VERSION 3.24)
project(SpeedCrunchiOS VERSION 1.0.0 LANGUAGES C CXX Swift)

if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
    message(FATAL_ERROR "Generate this project with -G Xcode (see scripts/setup-ios.sh).")
endif()

set(SC_BUNDLE_ID "com.example.speedcrunch" CACHE STRING "App bundle identifier (must be unique to your Apple account)")
set(SC_TEAM_ID "" CACHE STRING "Apple development team ID (leave empty to choose it in Xcode)")
set(SC_DEPLOYMENT_TARGET "16.0" CACHE STRING "Minimum iOS version")

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../upstream/UPSTREAM_COMMIT" SC_UPSTREAM_COMMIT)
string(STRIP "${SC_UPSTREAM_COMMIT}" SC_UPSTREAM_COMMIT)
string(SUBSTRING "${SC_UPSTREAM_COMMIT}" 0 7 SC_UPSTREAM_COMMIT)

set(CMAKE_Swift_LANGUAGE_VERSION 5)

# The engine: SpeedCrunch's math/ and core/ plus the C bridge, against Qt Core.
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../engine ${CMAKE_CURRENT_BINARY_DIR}/engine)

file(GLOB APP_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/Sources/*.swift)
set(APP_ASSETS ${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets)

add_executable(SpeedCrunch MACOSX_BUNDLE
    ${APP_SOURCES}
    ${APP_ASSETS}
    ${CMAKE_CURRENT_SOURCE_DIR}/BridgingHeader.h
)

target_link_libraries(SpeedCrunch PRIVATE speedcrunch_engine)

set_target_properties(SpeedCrunch PROPERTIES
    RESOURCE "${APP_ASSETS}"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
    MACOSX_BUNDLE_BUNDLE_NAME "SpeedCrunch"
    MACOSX_BUNDLE_GUI_IDENTIFIER "${SC_BUNDLE_ID}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "1"

    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${SC_BUNDLE_ID}"
    XCODE_ATTRIBUTE_PRODUCT_NAME "SpeedCrunch"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${SC_DEPLOYMENT_TARGET}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/BridgingHeader.h"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME "AccentColor"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${SC_TEAM_ID}"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks"
    # Swift links with clang, which does not add the C++ runtime by itself.
    XCODE_ATTRIBUTE_OTHER_LDFLAGS "$(inherited) -lc++"
    XCODE_GENERATE_SCHEME ON
)

# codesign refuses bundles whose files carry extended attributes ("resource
# fork, Finder information, or similar detritus not allowed"). Files in
# Documents/iCloud folders or unpacked from archives often have them, so strip
# them from the finished bundle; Xcode runs this before its CodeSign step.
add_custom_command(TARGET SpeedCrunch POST_BUILD
    COMMAND /bin/sh "${CMAKE_CURRENT_SOURCE_DIR}/strip-xattrs.sh"
    COMMENT "Removing extended attributes before code signing"
    VERBATIM)

# Same deployment target for the engine library so it links cleanly.
set_target_properties(speedcrunch_engine PROPERTIES
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${SC_DEPLOYMENT_TARGET}"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
)

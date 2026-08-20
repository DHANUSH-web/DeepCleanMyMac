cmake_minimum_required(VERSION 3.21)
project(dcmm-desktop VERSION 1.0.0 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  message(WARNING "dcmm-desktop is developed for LLVM/Clang. Current: ${CMAKE_CXX_COMPILER_ID}")
endif()

add_compile_options(-fobjc-arc -Wall -Wextra -Wno-unused-parameter)

# dcmmlib lives under extras/ (git submodule). Sibling ../dcmmlib is a fallback.
set(DCMM_BUILD_TESTS OFF CACHE BOOL "Disable engine tests when nested" FORCE)
set(DCMM_BUILD_CLI OFF CACHE BOOL "Disable engine CLI when nested" FORCE)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/extras/dcmmlib/CMakeLists.txt")
  add_subdirectory(extras/dcmmlib)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../dcmmlib/CMakeLists.txt")
  add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../dcmmlib" ${CMAKE_BINARY_DIR}/dcmmlib)
else()
  message(FATAL_ERROR "dcmmlib not found. Run: git submodule update --init extras/dcmmlib")
endif()

set(UI_SOURCES
  src/main.mm
  src/AppDelegate.mm
  src/ui/Widgets.mm
  src/ui/SidebarView.mm
  src/ui/DashboardView.mm
  src/ui/ResultsView.mm
  src/ui/DuplicatesView.mm
  src/ui/LargeFilesView.mm
  src/ui/UninstallerView.mm
  src/ui/SpaceLensView.mm
  src/ui/MaintenanceView.mm
  src/ui/MainWindowController.mm
)

add_executable(DeepCleanMyMac MACOSX_BUNDLE ${UI_SOURCES})
target_include_directories(DeepCleanMyMac PRIVATE include)
target_link_libraries(DeepCleanMyMac PRIVATE
  dcmm
  "-framework Cocoa"
  "-framework AppKit"
  "-framework Foundation"
  "-framework QuartzCore"
  "-framework Collaboration"
)

set(ICON_FILE "${CMAKE_SOURCE_DIR}/resources/AppIcon.icns")
if(EXISTS "${ICON_FILE}")
  target_sources(DeepCleanMyMac PRIVATE "${ICON_FILE}")
  set_source_files_properties("${ICON_FILE}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
endif()

set_target_properties(DeepCleanMyMac PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/resources/Info.plist.in"
  MACOSX_BUNDLE_BUNDLE_NAME "DeepCleanMyMac"
  MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
  MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.deepclean.DeepCleanMyMac"
  MACOSX_BUNDLE_ICON_FILE "AppIcon"
  OUTPUT_NAME "DeepCleanMyMac"
)

option(DCMM_DESKTOP_BUILD_TESTS "Build GoogleTest suite for the desktop app" ON)
if(DCMM_DESKTOP_BUILD_TESTS)
  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.15.2.zip
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
  enable_testing()
  add_executable(dcmm-desktop-tests
    tests/test_engine_link.cpp
    tests/test_modules.cpp
  )
  target_include_directories(dcmm-desktop-tests PRIVATE include)
  target_link_libraries(dcmm-desktop-tests PRIVATE dcmm GTest::gtest_main)
  include(GoogleTest)
  gtest_discover_tests(dcmm-desktop-tests)
endif()

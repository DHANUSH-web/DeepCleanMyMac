#pragma once

#include "dcmm/path.hpp"

#include <gtest/gtest.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

namespace fs = std::filesystem;

class HomeFixture : public ::testing::Test {
 protected:
  fs::path home;
  fs::path trash;

  void SetUp() override {
    auto stamp = std::to_string(reinterpret_cast<uintptr_t>(this));
    auto base = fs::weakly_canonical(fs::temp_directory_path());
    home = base / ("dcmm-desktop-home-" + stamp);
    trash = base / ("dcmm-desktop-trash-" + stamp);
    fs::remove_all(home);
    fs::remove_all(trash);
    fs::create_directories(home / "Library" / "Caches");
    fs::create_directories(home / "Library" / "Logs");
    fs::create_directories(home / "Library" / "Saved Application State");
    fs::create_directories(home / "Desktop");
    fs::create_directories(home / "Documents");
    fs::create_directories(home / "Downloads");
    fs::create_directories(home / "Movies");
    fs::create_directories(home / "Applications");
    fs::create_directories(trash);
    setenv("DCMM_HOME", home.string().c_str(), 1);
    setenv("DCMM_TRASH", trash.string().c_str(), 1);
  }

  void TearDown() override {
    unsetenv("DCMM_HOME");
    unsetenv("DCMM_TRASH");
    std::error_code ec;
    fs::remove_all(home, ec);
    fs::remove_all(trash, ec);
  }

  static void writeBytes(const fs::path& p, std::size_t n, char fill = 'x') {
    fs::create_directories(p.parent_path());
    std::ofstream out(p, std::ios::binary);
    std::string chunk(n, fill);
    out.write(chunk.data(), static_cast<std::streamsize>(chunk.size()));
  }
};

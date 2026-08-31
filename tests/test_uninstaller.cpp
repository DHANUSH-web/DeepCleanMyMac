#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "home_fixture.hpp"

#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, UninstallerListsAppsWithoutSelectingLeftovers) {
  auto app = home / "Applications" / "Fixture.app" / "Contents";
  fs::create_directories(app);
  {
    std::ofstream out(app / "Info.plist");
    out << "<?xml version=\"1.0\"?><plist><dict>"
           "<key>CFBundleName</key><string>Fixture</string>"
           "<key>CFBundleIdentifier</key><string>com.example.Fixture</string>"
           "</dict></plist>";
  }
  writeBytes(home / "Library" / "Caches" / "com.example.Fixture" / "c.bin", 256);

  dcmm::Engine e;
  auto apps = e.listApps();
  bool found = false;
  for (auto& a : apps) {
    if (a.bundleId != "com.example.Fixture" && a.name != "Fixture") continue;
    found = true;
    e.attachLeftovers(a);
    for (const auto& it : a.leftovers) EXPECT_FALSE(it.selected);
  }
  EXPECT_TRUE(found);
}

TEST_F(HomeFixture, UninstallIncludesAppWhenLeftoversUnchecked) {
  auto appDir = home / "Applications" / "Fixture.app";
  fs::create_directories(appDir / "Contents");
  {
    std::ofstream out(appDir / "Contents" / "Info.plist");
    out << "<?xml version=\"1.0\"?><plist><dict>"
           "<key>CFBundleName</key><string>Fixture</string>"
           "<key>CFBundleIdentifier</key><string>com.example.Fixture</string>"
           "</dict></plist>";
  }
  writeBytes(home / "Library" / "Caches" / "com.example.Fixture" / "c.bin", 256);
  dcmm::Engine e;
  auto apps = e.listApps();
  const dcmm::InstalledApp* found = nullptr;
  for (auto& a : apps) {
    if (a.bundleId == "com.example.Fixture" || a.name == "Fixture") found = &a;
  }
  ASSERT_NE(found, nullptr);
  dcmm::InstalledApp app = *found;
  e.attachLeftovers(app);
  auto paths = ui::uninstallPaths(app);
  ASSERT_FALSE(paths.empty());
  EXPECT_EQ(paths.front(), app.appPath);
  for (const auto& p : paths) EXPECT_EQ(p.find("Caches"), std::string::npos);
  auto r = ui::applyClean(e, paths, ui::CleanPref::MoveToTrash);
  EXPECT_GE(r.trashedItems, 1u);
  EXPECT_FALSE(fs::exists(appDir));
  EXPECT_TRUE(fs::exists(home / "Library" / "Caches" / "com.example.Fixture"));
}

TEST_F(HomeFixture, ApplicationSupportNamesUseIdAndShortName) {
  dcmm::InstalledApp app;
  app.appPath = (home / "Applications" / "Chrome.app").string();
  app.name = "Google Chrome";
  app.bundleId = "com.google.chrome";
  auto names = ui::applicationSupportNames(app);
  bool id = false, display = false, shortName = false;
  for (const auto& n : names) {
    if (n == "com.google.chrome") id = true;
    if (n == "Google Chrome") display = true;
    if (n == "Chrome") shortName = true;
  }
  EXPECT_TRUE(id);
  EXPECT_TRUE(display);
  EXPECT_TRUE(shortName);
}

TEST_F(HomeFixture, UninstallRemovesApplicationSupportNamedFolders) {
  auto appDir = home / "Applications" / "Chrome.app";
  fs::create_directories(appDir / "Contents");
  {
    std::ofstream out(appDir / "Contents" / "Info.plist");
    out << "<?xml version=\"1.0\"?><plist><dict>"
           "<key>CFBundleName</key><string>Google Chrome</string>"
           "<key>CFBundleIdentifier</key><string>com.google.chrome</string>"
           "</dict></plist>";
  }
  writeBytes(home / "Library" / "Application Support" / "com.google.chrome" / "Prefs", 64);
  writeBytes(home / "Library" / "Application Support" / "Chrome" / "Cache", 64);
  writeBytes(home / "Library" / "Application Support" / "Google" / "keep.txt", 32);
  writeBytes(home / "Library" / "Caches" / "com.google.chrome" / "c.bin", 64);
  dcmm::Engine e;
  auto apps = e.listApps();
  const dcmm::InstalledApp* found = nullptr;
  for (auto& a : apps) {
    if (a.bundleId == "com.google.chrome") found = &a;
  }
  ASSERT_NE(found, nullptr);
  dcmm::InstalledApp app = *found;
  auto paths = ui::uninstallPaths(app);
  bool sawId = false, sawChrome = false, sawCache = false;
  for (const auto& p : paths) {
    if (p.find("Application Support") != std::string::npos && p.find("com.google.chrome") != std::string::npos)
      sawId = true;
    if (p.size() >= 6 && p.compare(p.size() - 6, 6, "Chrome") == 0) sawChrome = true;
    if (p.find("Caches") != std::string::npos) sawCache = true;
  }
  EXPECT_TRUE(sawId);
  EXPECT_TRUE(sawChrome);
  EXPECT_FALSE(sawCache);
  auto r = ui::applyClean(e, paths, ui::CleanPref::MoveToTrash);
  EXPECT_GE(r.trashedItems, 1u);
  EXPECT_FALSE(fs::exists(appDir));
  EXPECT_FALSE(fs::exists(home / "Library" / "Application Support" / "com.google.chrome"));
  EXPECT_FALSE(fs::exists(home / "Library" / "Application Support" / "Chrome"));
  EXPECT_TRUE(fs::exists(home / "Library" / "Application Support" / "Google" / "keep.txt"));
  EXPECT_TRUE(fs::exists(home / "Library" / "Caches" / "com.google.chrome"));
}

TEST_F(HomeFixture, UninstallPathsCollectsMultipleApps) {
  dcmm::InstalledApp a, b;
  a.appPath = (home / "Applications" / "One.app").string();
  a.appBytes = 10;
  b.appPath = (home / "Applications" / "Two.app").string();
  b.appBytes = 20;
  dcmm::ScanItem leftover;
  leftover.path = (home / "Library" / "Caches" / "com.example.Two").string();
  leftover.selected = true;
  leftover.bytes = 5;
  b.leftovers.push_back(leftover);
  auto paths = ui::uninstallPaths(std::vector<dcmm::InstalledApp>{a, b});
  ASSERT_EQ(paths.size(), 3u);
  EXPECT_EQ(paths[0], a.appPath);
  EXPECT_EQ(paths[1], b.appPath);
  EXPECT_EQ(paths[2], leftover.path);
  EXPECT_EQ(ui::uninstallBytes(std::vector<dcmm::InstalledApp>{a, b}), 35u);
}

TEST_F(HomeFixture, UninstallerRefusesSystemApps) {
  dcmm::Engine e;
  auto r = e.trashPaths({"/System/Applications/Safari.app"});
  EXPECT_EQ(r.trashedItems, 0u);
  EXPECT_GE(r.failedItems, 1u);
}

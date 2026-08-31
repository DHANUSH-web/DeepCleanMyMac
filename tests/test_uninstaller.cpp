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

TEST_F(HomeFixture, UninstallerRefusesSystemApps) {
  dcmm::Engine e;
  auto r = e.trashPaths({"/System/Applications/Safari.app"});
  EXPECT_EQ(r.trashedItems, 0u);
  EXPECT_GE(r.failedItems, 1u);
}

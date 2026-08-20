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

TEST_F(HomeFixture, UninstallerRefusesSystemApps) {
  dcmm::Engine e;
  auto r = e.trashPaths({"/System/Applications/Safari.app"});
  EXPECT_EQ(r.trashedItems, 0u);
  EXPECT_GE(r.failedItems, 1u);
}

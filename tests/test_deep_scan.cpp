#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, DeepScanListsEachCacheChildUnchecked) {
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 2048);
  writeBytes(home / "Library" / "Caches" / "Arc" / "b.bin", 1024);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::DeepScan);
  EXPECT_FALSE(ui::allScanItemsSelected(r));
  EXPECT_EQ(r.selectedBytes(), 0u);

  bool foundJunk = false, foundArc = false;
  for (const auto& g : r.groups) {
    if (g.id != "user_caches") continue;
    EXPECT_GT(g.items.size(), 1u);
    for (const auto& it : g.items) {
      EXPECT_FALSE(it.selected);
      if (it.displayName == "com.example.Junk") foundJunk = true;
      if (it.displayName == "Arc") foundArc = true;
    }
  }
  EXPECT_TRUE(foundJunk);
  EXPECT_TRUE(foundArc);
  for (const auto& g : r.groups) {
    if (g.id != "user_caches") continue;
    for (std::size_t i = 1; i < g.items.size(); ++i)
      EXPECT_GE(g.items[i - 1].bytes, g.items[i].bytes);
    EXPECT_EQ(g.items.front().displayName, "com.example.Junk");
  }
}

TEST_F(HomeFixture, DeepScanGroupsComAppleAsNativeSystemItems) {
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 2048);
  writeBytes(home / "Library" / "Caches" / "com.apple.Safari" / "c.bin", 4096);
  writeBytes(home / "Library" / "Logs" / "com.apple.bird" / "l.bin", 512);
  writeBytes(home / "Library" / "Caches" / "Arc" / "b.bin", 1024);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::DeepScan);
  ASSERT_FALSE(r.groups.empty());
  EXPECT_EQ(r.groups.back().id, "native_system");
  EXPECT_EQ(r.groups.back().title, "Native System Items");
  bool sawSafari = false, sawBird = false, sawJunkInNative = false;
  for (const auto& it : r.groups.back().items) {
    EXPECT_FALSE(it.selected);
    EXPECT_TRUE(it.reviewFirst);
    EXPECT_TRUE(ui::isNativeAppleScanItem(it));
    if (it.displayName == "com.apple.Safari") sawSafari = true;
    if (it.displayName == "com.apple.bird") sawBird = true;
    if (it.displayName == "com.example.Junk") sawJunkInNative = true;
  }
  EXPECT_TRUE(sawSafari);
  EXPECT_TRUE(sawBird);
  EXPECT_FALSE(sawJunkInNative);
  bool junkInCaches = false, safariInCaches = false, arcInCaches = false;
  for (const auto& g : r.groups) {
    if (g.id != "user_caches") continue;
    for (const auto& it : g.items) {
      if (it.displayName == "com.example.Junk") junkInCaches = true;
      if (it.displayName == "com.apple.Safari") safariInCaches = true;
      if (it.displayName == "Arc") arcInCaches = true;
    }
  }
  EXPECT_TRUE(junkInCaches);
  EXPECT_TRUE(arcInCaches);
  EXPECT_FALSE(safariInCaches);
}

TEST_F(HomeFixture, DeepScanOptInCleanOnlyCheckedRows) {
  writeBytes(home / "Library" / "Caches" / "keep.me" / "a.bin", 1024);
  writeBytes(home / "Library" / "Caches" / "drop.me" / "b.bin", 1024);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::DeepScan);
  for (auto& g : r.groups)
    for (auto& it : g.items)
      if (it.displayName == "drop.me") it.selected = true;
  auto result = e.trashPaths(r.selectedPaths());
  EXPECT_GE(result.trashedItems, 1u);
  EXPECT_TRUE(fs::exists(home / "Library" / "Caches" / "keep.me"));
  EXPECT_FALSE(fs::exists(home / "Library" / "Caches" / "drop.me"));
}

TEST(DeepScan, GroupCheckSelectsEveryItem) {
  dcmm::ScanGroup g;
  g.items.push_back({"/a", "a", "", 0, 0, false, false});
  g.items.push_back({"/b", "b", "", 0, 0, false, false});
  g.items.push_back({"/c", "c", "", 0, 0, false, false});
  EXPECT_EQ(ui::scanGroupCheck(g), ui::GroupCheck::Off);
  ui::setScanGroupSelected(g, true);
  EXPECT_EQ(ui::scanGroupCheck(g), ui::GroupCheck::On);
  for (const auto& it : g.items) EXPECT_TRUE(it.selected);
  g.items[1].selected = false;
  EXPECT_EQ(ui::scanGroupCheck(g), ui::GroupCheck::Mixed);
  ui::setScanGroupSelected(g, false);
  EXPECT_EQ(ui::scanGroupCheck(g), ui::GroupCheck::Off);
}

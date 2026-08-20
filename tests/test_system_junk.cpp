#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, SystemJunkListsEachCacheChildUnchecked) {
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 2048);
  writeBytes(home / "Library" / "Caches" / "Arc" / "b.bin", 1024);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::SystemJunk);
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

TEST_F(HomeFixture, SystemJunkOptInCleanOnlyCheckedRows) {
  writeBytes(home / "Library" / "Caches" / "keep.me" / "a.bin", 1024);
  writeBytes(home / "Library" / "Caches" / "drop.me" / "b.bin", 1024);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::SystemJunk);
  for (auto& g : r.groups)
    for (auto& it : g.items)
      if (it.displayName == "drop.me") it.selected = true;
  auto result = e.trashPaths(r.selectedPaths());
  EXPECT_GE(result.trashedItems, 1u);
  EXPECT_TRUE(fs::exists(home / "Library" / "Caches" / "keep.me"));
  EXPECT_FALSE(fs::exists(home / "Library" / "Caches" / "drop.me"));
}

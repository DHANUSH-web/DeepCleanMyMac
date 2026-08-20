#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, SmartScanRecommendsWholeCacheGroup) {
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 4096);
  writeBytes(home / "Library" / "Logs" / "app.log", 512);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::SmartScan);
  EXPECT_FALSE(r.groups.empty());
  EXPECT_GE(r.totalBytes(), 4096u);
  EXPECT_TRUE(ui::allScanItemsSelected(r));

  bool sawChildName = false;
  bool sawCaches = false;
  for (const auto& g : r.groups) {
    EXPECT_EQ(g.items.size(), 1u);
    EXPECT_TRUE(g.items[0].selected);
    if (g.id == "user_caches") {
      sawCaches = true;
      EXPECT_EQ(g.items[0].displayName, "User Caches");
    }
    for (const auto& it : g.items)
      if (it.displayName == "com.example.Junk") sawChildName = true;
  }
  EXPECT_TRUE(sawCaches);
  EXPECT_FALSE(sawChildName);
}

TEST_F(HomeFixture, SmartScanSelectAllToggles) {
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 2048);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::SmartScan);
  ASSERT_TRUE(ui::allScanItemsSelected(r));
  ui::setAllScanItemsSelected(r, false);
  EXPECT_FALSE(ui::allScanItemsSelected(r));
  EXPECT_EQ(r.selectedBytes(), 0u);
  EXPECT_TRUE(r.selectedPaths().empty());
  ui::setAllScanItemsSelected(r, true);
  EXPECT_TRUE(ui::allScanItemsSelected(r));
  EXPECT_FALSE(r.selectedPaths().empty());
}

TEST_F(HomeFixture, SmartScanCleanMovesCacheChildren) {
  auto child = home / "Library" / "Caches" / "com.example.Junk";
  writeBytes(child / "a.bin", 2048);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::SmartScan);
  auto paths = r.selectedPaths();
  ASSERT_FALSE(paths.empty());
  auto result = e.trashPaths(paths);
  EXPECT_GE(result.trashedItems, 1u);
  EXPECT_FALSE(fs::exists(child));
  EXPECT_TRUE(fs::exists(home / "Library" / "Caches"));
}

TEST_F(HomeFixture, SmartScanDoesNotIncludeNpm) {
  writeBytes(home / ".npm" / "_cacache" / "x", 1024);
  writeBytes(home / "Library" / "Caches" / "keep" / "c.bin", 256);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::SmartScan);
  for (const auto& g : r.groups)
    for (const auto& it : g.items) EXPECT_EQ(it.path.find(".npm"), std::string::npos);
}

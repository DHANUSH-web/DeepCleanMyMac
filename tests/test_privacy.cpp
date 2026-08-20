#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, PrivacyFindsSafariCacheUnchecked) {
  writeBytes(home / "Library" / "Caches" / "com.apple.Safari" / "cache.db", 4096);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::Privacy);
  EXPECT_GE(r.totalBytes(), 4096u);
  EXPECT_FALSE(ui::allScanItemsSelected(r));
  bool found = false;
  for (const auto& g : r.groups)
    for (const auto& it : g.items) {
      EXPECT_FALSE(it.selected);
      if (it.path.find("Safari") != std::string::npos) found = true;
    }
  EXPECT_TRUE(found);
}

TEST_F(HomeFixture, PrivacyCookiesAreReviewFirst) {
  writeBytes(home / "Library" / "Cookies" / "Cookies.binarycookies", 128);
  dcmm::Engine e;
  auto r = ui::runScan(e, ui::Module::Privacy);
  bool saw = false;
  for (const auto& g : r.groups) {
    if (g.id != "cookies") continue;
    saw = true;
    EXPECT_TRUE(g.reviewFirst);
    for (const auto& it : g.items) {
      EXPECT_TRUE(it.reviewFirst);
      EXPECT_FALSE(it.selected);
    }
  }
  EXPECT_TRUE(saw);
}

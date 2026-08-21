#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, SpaceLensMeasuresHomeFolders) {
  writeBytes(home / "Downloads" / "movie.bin", 8192);
  writeBytes(home / "Library" / "Caches" / "c.bin", 4096);
  dcmm::Engine e;
  auto nodes = e.spaceLens();
  EXPECT_FALSE(nodes.empty());
  bool sawDownloads = false, sawCaches = false, sawLibraryRoot = false;
  for (const auto& n : nodes) {
    if (n.name == "Downloads") sawDownloads = true;
    if (n.name == "Library/Caches") sawCaches = true;
    if (n.name == "Library") sawLibraryRoot = true;
  }
  EXPECT_TRUE(sawDownloads);
  EXPECT_TRUE(sawCaches);
  EXPECT_FALSE(sawLibraryRoot);
  for (std::size_t i = 1; i < nodes.size(); ++i) EXPECT_GE(nodes[i - 1].bytes, nodes[i].bytes);
}

TEST(SpaceLens, SizeBandByBytes) {
  EXPECT_EQ(ui::spaceSizeBand(0), ui::SpaceSizeBand::Normal);
  EXPECT_EQ(ui::spaceSizeBand(500ull * 1024ull * 1024ull), ui::SpaceSizeBand::Normal);
  EXPECT_EQ(ui::spaceSizeBand(500ull * 1024ull * 1024ull + 1), ui::SpaceSizeBand::Big);
  EXPECT_EQ(ui::spaceSizeBand(1024ull * 1024ull * 1024ull), ui::SpaceSizeBand::Big);
  EXPECT_EQ(ui::spaceSizeBand(1024ull * 1024ull * 1024ull + 1), ui::SpaceSizeBand::TooBig);
}

TEST(SpaceLens, SharePercentOfListedTotal) {
  EXPECT_EQ(ui::spaceSharePercent(0, 100), "0%");
  EXPECT_EQ(ui::spaceSharePercent(50, 100), "50%");
  EXPECT_EQ(ui::spaceSharePercent(1, 1000), "0.1%");
  EXPECT_EQ(ui::spaceSharePercent(1, 10000), "<0.1%");
}

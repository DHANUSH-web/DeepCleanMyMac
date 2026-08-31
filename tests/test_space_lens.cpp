#include "AppFeatures.hpp"
#include "AppSettings.hpp"
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

TEST_F(HomeFixture, SpaceLensSelectedPathsIncludeOwnRiskFolders) {
  writeBytes(home / "Downloads" / "movie.bin", 8192);
  writeBytes(home / "Library" / "Caches" / "c.bin", 4096);
  writeBytes(home / "Documents" / "keep.txt", 1024);
  dcmm::Engine e;
  auto nodes = e.spaceLens();
  ASSERT_FALSE(nodes.empty());
  std::vector<char> selected(nodes.size(), 1);
  auto paths = ui::selectedSpaceLensPaths(nodes, selected);
  EXPECT_EQ(paths.size(), nodes.size());
  bool sawDocuments = false, sawDownloads = false, sawCaches = false;
  for (const auto& p : paths) {
    if (p == (home / "Documents").string()) sawDocuments = true;
    if (p == (home / "Downloads").string()) sawDownloads = true;
    if (p == (home / "Library" / "Caches").string()) sawCaches = true;
  }
  EXPECT_TRUE(sawDocuments);
  EXPECT_TRUE(sawDownloads);
  EXPECT_TRUE(sawCaches);
  EXPECT_TRUE(ui::spaceLensDanger((home / "Documents").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Downloads").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Desktop").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Pictures").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Music").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Movies").string()));
  EXPECT_FALSE(ui::spaceLensDanger((home / "Library" / "Caches").string()));
  EXPECT_FALSE(ui::spaceLensDanger((home / "Library" / "Logs").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Library" / "Keychains").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Library" / "Mail").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Library" / "Safari").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Library" / "Messages").string()));
  EXPECT_TRUE(ui::spaceLensDanger((home / "Library" / "Application Support").string()));
  EXPECT_FALSE(ui::spaceLensDanger((home / "Projects").string()));
}

TEST_F(HomeFixture, SpaceLensOwnRiskCleansDocumentsAndCaches) {
  writeBytes(home / "Documents" / "keep.txt", 1024);
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 2048);
  dcmm::Engine e;
  auto docs = ui::applySpaceLensClean(e, {(home / "Documents").string()}, ui::CleanPref::MoveToTrash);
  EXPECT_GE(docs.trashedItems, 1u);
  EXPECT_FALSE(fs::exists(home / "Documents" / "keep.txt"));
  EXPECT_TRUE(fs::exists(trash / "Documents"));

  auto caches = ui::applySpaceLensClean(
      e, {(home / "Library" / "Caches").string()}, ui::CleanPref::MoveToTrash);
  EXPECT_GE(caches.trashedItems, 1u);
  EXPECT_TRUE(fs::exists(home / "Library" / "Caches"));
  EXPECT_FALSE(fs::exists(home / "Library" / "Caches" / "com.example.Junk"));
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

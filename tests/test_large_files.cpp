#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, LargeFilesUsesDesktopDocumentsDownloadsMovies) {
  auto opt = ui::largeFileOptions(home.string());
  ASSERT_EQ(opt.roots.size(), 4u);
  EXPECT_EQ(opt.roots[0], (home / "Desktop").string());
  EXPECT_EQ(opt.roots[1], (home / "Documents").string());
  EXPECT_EQ(opt.roots[2], (home / "Downloads").string());
  EXPECT_EQ(opt.roots[3], (home / "Movies").string());
  EXPECT_EQ(opt.minBytes, 50ull * 1024ull * 1024ull);
  EXPECT_EQ(opt.limit, 300u);
}

TEST_F(HomeFixture, LargeFilesIgnoresSmallFilesAtDefaultThreshold) {
  writeBytes(home / "Downloads" / "tiny.bin", 4096);
  dcmm::Engine e;
  auto files = e.findLargeFiles(ui::largeFileOptions(home.string()));
  EXPECT_TRUE(files.empty());
  EXPECT_TRUE(ui::selectedLargeFilePaths(files).empty());
}

TEST_F(HomeFixture, LargeFilesFindsOversizedDownloadsUnchecked) {
  writeBytes(home / "Downloads" / "big.bin", 8192);
  writeBytes(home / "Library" / "Caches" / "not-a-root.bin", 8192);
  auto opt = ui::largeFileOptions(home.string());
  opt.minBytes = 100;
  dcmm::Engine e;
  auto files = e.findLargeFiles(opt);
  ASSERT_FALSE(files.empty());
  bool sawDownloads = false, sawCaches = false;
  for (const auto& f : files) {
    EXPECT_FALSE(f.selected);
    if (f.path.find("Downloads") != std::string::npos) sawDownloads = true;
    if (f.path.find("Caches") != std::string::npos) sawCaches = true;
  }
  EXPECT_TRUE(sawDownloads);
  EXPECT_FALSE(sawCaches);
  EXPECT_TRUE(ui::selectedLargeFilePaths(files).empty());
  files[0].selected = true;
  auto paths = ui::selectedLargeFilePaths(files);
  ASSERT_EQ(paths.size(), 1u);
  auto result = e.trashPaths(paths);
  EXPECT_EQ(result.trashedItems, 1u);
  EXPECT_FALSE(fs::exists(home / "Downloads" / "big.bin"));
}

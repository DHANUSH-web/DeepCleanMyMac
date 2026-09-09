#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, LargeFilesUsesHomeFolderRoots) {
  auto opt = ui::largeFileOptions(home.string());
  auto specs = ui::largeFileRootSpecs(home.string());
  ASSERT_EQ(specs.size(), 8u);
  EXPECT_STREQ(specs[0].title, "Desktop");
  EXPECT_STREQ(specs[1].title, "Documents");
  EXPECT_STREQ(specs[2].title, "Downloads");
  EXPECT_STREQ(specs[3].title, "Pictures");
  EXPECT_STREQ(specs[4].title, "Movies");
  EXPECT_STREQ(specs[5].title, "Music");
  EXPECT_STREQ(specs[6].title, "iCloud Drive");
  EXPECT_STREQ(specs[7].title, "Bin");
  EXPECT_EQ(opt.roots[0], (home / "Desktop").string());
  EXPECT_EQ(opt.roots[3], (home / "Pictures").string());
  EXPECT_EQ(opt.roots[5], (home / "Music").string());
  EXPECT_EQ(opt.roots[7], (home / ".Trash").string());
  EXPECT_EQ(opt.minBytes, ui::kDefaultLargeFileMinBytes);
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

TEST_F(HomeFixture, LargeFilesGroupsByRootName) {
  dcmm::LargeFile pic, dl, bin;
  pic.path = (home / "Pictures" / "shot.png").string();
  pic.bytes = 200ull * 1024ull * 1024ull;
  dl.path = (home / "Downloads" / "film.mov").string();
  dl.bytes = 80ull * 1024ull * 1024ull;
  bin.path = (home / ".Trash" / "old.bin").string();
  bin.bytes = 60ull * 1024ull * 1024ull;
  auto groups = ui::groupLargeFiles({pic, dl, bin}, home.string());
  ASSERT_EQ(groups.size(), 3u);
  EXPECT_EQ(groups[0].title, "Downloads");
  EXPECT_EQ(groups[1].title, "Pictures");
  EXPECT_EQ(groups[2].title, "Bin");
  EXPECT_EQ(groups[1].files[0].path, pic.path);
  ui::setLargeFileGroupSelected(groups[1], true);
  EXPECT_EQ(ui::largeFileGroupCheck(groups[1]), ui::GroupCheck::On);
  EXPECT_EQ(ui::selectedLargeFilePaths(groups).size(), 1u);
}

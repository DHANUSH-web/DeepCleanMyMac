#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, DuplicatesDefaultRootsExcludeHome) {
  auto opt = ui::duplicateOptions(home.string());
  ASSERT_EQ(opt.roots.size(), 6u);
  EXPECT_EQ(opt.roots[0], (home / "Documents").string());
  EXPECT_EQ(opt.roots[1], (home / "Downloads").string());
  EXPECT_EQ(opt.roots[2], (home / "Desktop").string());
  EXPECT_EQ(opt.roots[3], (home / "Pictures").string());
  EXPECT_EQ(opt.roots[4], (home / "Movies").string());
  EXPECT_EQ(opt.roots[5], (home / "Music").string());
  EXPECT_EQ(opt.minBytes, 256ull * 1024ull);
}

TEST_F(HomeFixture, DuplicatesHomeToggleWalksHomeOnce) {
  auto opt = ui::duplicateOptions(home.string(), true);
  ASSERT_EQ(opt.roots.size(), 1u);
  EXPECT_EQ(opt.roots[0], home.string());
}

TEST_F(HomeFixture, DuplicatesKeepsFirstCopyAndTrashesTheRest) {
  const std::size_t n = 256ull * 1024ull + 64;
  writeBytes(home / "Downloads" / "a.bin", n, 'D');
  writeBytes(home / "Documents" / "b.bin", n, 'D');
  dcmm::Engine e;
  auto groups = e.findDuplicates(ui::duplicateOptions(home.string()));
  ASSERT_FALSE(groups.empty());
  ASSERT_GE(groups[0].files.size(), 2u);
  EXPECT_TRUE(groups[0].files[0].keep);
  EXPECT_FALSE(groups[0].files[1].keep);
  auto paths = ui::duplicatePathsToTrash(groups);
  ASSERT_EQ(paths.size(), groups[0].files.size() - 1);
  auto result = e.trashPaths(paths);
  EXPECT_GE(result.trashedItems, 1u);
  int remaining = 0;
  if (fs::exists(home / "Downloads" / "a.bin")) ++remaining;
  if (fs::exists(home / "Documents" / "b.bin")) ++remaining;
  EXPECT_EQ(remaining, 1);
}

TEST_F(HomeFixture, DuplicatesNothingToTrashWhenEveryCopyKept) {
  const std::size_t n = 256ull * 1024ull + 8;
  writeBytes(home / "Documents" / "x.bin", n, 'K');
  writeBytes(home / "Documents" / "y.bin", n, 'K');
  dcmm::Engine e;
  auto groups = e.findDuplicates(ui::duplicateOptions(home.string()));
  ASSERT_FALSE(groups.empty());
  for (auto& g : groups)
    for (auto& f : g.files) f.keep = true;
  EXPECT_TRUE(ui::duplicatePathsToTrash(groups).empty());
}

#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, DuplicatesScansDownloadsDesktopDocuments) {
  auto opt = ui::duplicateOptions(home.string());
  ASSERT_EQ(opt.roots.size(), 3u);
  EXPECT_EQ(opt.roots[0], (home / "Downloads").string());
  EXPECT_EQ(opt.roots[1], (home / "Desktop").string());
  EXPECT_EQ(opt.roots[2], (home / "Documents").string());
  EXPECT_EQ(opt.minBytes, 256ull * 1024ull);
}

TEST_F(HomeFixture, DuplicatesKeepsFirstCopyAndTrashesTheRest) {
  const std::size_t n = 256ull * 1024ull + 64;
  writeBytes(home / "Downloads" / "a.bin", n, 'D');
  writeBytes(home / "Desktop" / "b.bin", n, 'D');
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
  if (fs::exists(home / "Desktop" / "b.bin")) ++remaining;
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

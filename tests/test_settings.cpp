#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "Modules.h"
#include "home_fixture.hpp"

#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

TEST(Settings, AppearanceIdsRoundTrip) {
  EXPECT_STREQ(ui::appearancePrefId(ui::AppearancePref::System), "system");
  EXPECT_STREQ(ui::appearancePrefId(ui::AppearancePref::Light), "light");
  EXPECT_STREQ(ui::appearancePrefId(ui::AppearancePref::Dark), "dark");
  EXPECT_EQ(ui::appearancePrefFromId("light"), ui::AppearancePref::Light);
  EXPECT_EQ(ui::appearancePrefFromId("dark"), ui::AppearancePref::Dark);
  EXPECT_EQ(ui::appearancePrefFromId(""), ui::AppearancePref::System);
  EXPECT_EQ(ui::appearancePrefFromId("nope"), ui::AppearancePref::System);
}

TEST(Settings, LargeFileDefaultMinIs50MB) {
  EXPECT_EQ(ui::kDefaultLargeFileMinBytes, 50ull * 1024ull * 1024ull);
  EXPECT_EQ(ui::kMebibyte, 1024ull * 1024ull);
}

TEST(Settings, CleanIdsAndCopy) {
  EXPECT_STREQ(ui::cleanPrefId(ui::CleanPref::MoveToTrash), "trash");
  EXPECT_STREQ(ui::cleanPrefId(ui::CleanPref::DeletePermanently), "delete");
  EXPECT_EQ(ui::cleanPrefFromId("delete"), ui::CleanPref::DeletePermanently);
  EXPECT_EQ(ui::cleanPrefFromId("trash"), ui::CleanPref::MoveToTrash);
  EXPECT_STREQ(ui::cleanButtonTitle(ui::CleanPref::MoveToTrash), "Move to Trash");
  EXPECT_STREQ(ui::cleanButtonTitle(ui::CleanPref::DeletePermanently), "Delete Permanently");
  EXPECT_NE(std::string(ui::cleanButtonTitleWithBytes(ui::CleanPref::DeletePermanently, 1024)).find(
                "Delete"),
            std::string::npos);
}

TEST(Settings, IsASidebarPageNotADashboardTool) {
  EXPECT_STREQ(ui::title(ui::Module::Settings), "Settings");
  EXPECT_TRUE(ui::sidebarSymbol(ui::Module::Settings) && *ui::sidebarSymbol(ui::Module::Settings));
  for (const auto& t : ui::dashboardTools()) EXPECT_NE(t.module, ui::Module::Settings);
}

TEST_F(HomeFixture, PermanentDeleteRemovesCacheChildNotDocuments) {
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 2048);
  writeBytes(home / "Documents" / "keep.txt", 64);
  const auto cache = (home / "Library" / "Caches" / "com.example.Junk").string();
  dcmm::Engine e;
  auto r = ui::applyClean(e, {cache}, ui::CleanPref::DeletePermanently);
  EXPECT_GE(r.trashedItems, 1u);
  EXPECT_FALSE(fs::exists(home / "Library" / "Caches" / "com.example.Junk"));
  EXPECT_TRUE(fs::exists(home / "Documents" / "keep.txt"));
  EXPECT_TRUE(fs::is_empty(trash) || !fs::exists(trash / "com.example.Junk"));
}

TEST_F(HomeFixture, MoveToTrashStillUsesTrashFolder) {
  writeBytes(home / "Library" / "Caches" / "com.example.Junk" / "a.bin", 2048);
  const auto cache = (home / "Library" / "Caches" / "com.example.Junk").string();
  dcmm::Engine e;
  auto r = ui::applyClean(e, {cache}, ui::CleanPref::MoveToTrash);
  EXPECT_GE(r.trashedItems, 1u);
  EXPECT_FALSE(fs::exists(home / "Library" / "Caches" / "com.example.Junk"));
  EXPECT_TRUE(fs::exists(trash / "com.example.Junk"));
}

TEST_F(HomeFixture, PermanentDeleteRefusesDocumentsFolder) {
  writeBytes(home / "Documents" / "keep.txt", 64);
  dcmm::Engine e;
  auto r = ui::applyClean(e, {(home / "Documents").string()}, ui::CleanPref::DeletePermanently);
  EXPECT_EQ(r.trashedItems, 0u);
  EXPECT_TRUE(fs::exists(home / "Documents" / "keep.txt"));
}

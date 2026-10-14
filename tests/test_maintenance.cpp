#include "AppFeatures.hpp"
#include "home_fixture.hpp"

#include <gtest/gtest.h>
#include <set>
#include <string>

TEST(Maintenance, CardsMatchEngineTaskIds)
{
  dcmm::Engine e;
  auto tasks = e.maintenance_tasks();
  std::set<std::string> ids;
  for (const auto& t : tasks)
  {
    ids.insert(t.id);
  }
  for (const char* id : ui::maintenanceIds())
  {
    EXPECT_TRUE(ids.count(id)) << id;
  }
}

TEST_F(HomeFixture, EmptyTrashPreviewNothingToDo)
{
  dcmm::Engine e;
  auto p = e.preview_maintenance("empty_trash");
  EXPECT_TRUE(p.nothingToDo);
  EXPECT_NE(p.message.find("Nothing to clean"), std::string::npos);
}

TEST_F(HomeFixture, EmptyTrashRunRemovesOnlyTrashContents)
{
  writeBytes(home / ".Trash" / "gone.txt", 128);
  writeBytes(home / "Documents" / "keep.txt", 64);
  dcmm::Engine e;
  auto before = e.preview_maintenance("empty_trash");
  EXPECT_FALSE(before.nothingToDo);
  auto done = e.run_maintenance("empty_trash");
  EXPECT_FALSE(done.nothingToDo);
  EXPECT_GE(done.itemsAffected, 1u);
  EXPECT_FALSE(fs::exists(home / ".Trash" / "gone.txt"));
  EXPECT_TRUE(fs::exists(home / "Documents" / "keep.txt"));
}

TEST_F(HomeFixture, QuickLookPreviewAndClean)
{
  writeBytes(home / "Library" / "Caches" / "com.apple.QuickLook.thumbnailcache" / "t.bin", 256);
  dcmm::Engine e;
  auto p = e.preview_maintenance("quicklook");
  EXPECT_FALSE(p.nothingToDo);
  auto done = e.run_maintenance("quicklook");
  EXPECT_GE(done.itemsAffected, 1u);
  EXPECT_FALSE(fs::exists(home / "Library" / "Caches" / "com.apple.QuickLook.thumbnailcache"));
}

TEST(Maintenance, UnknownTaskIsNothingToDo)
{
  dcmm::Engine e;
  auto p = e.preview_maintenance("not_a_real_task");
  EXPECT_TRUE(p.nothingToDo);
}

TEST(Maintenance, DnsAndLaunchServicesDoNotClaimFileDeletes)
{
  dcmm::Engine e;
  for (const char* id : {"flush_dns", "launch_services"})
  {
    bool found = false;
    for (const auto& t : e.maintenance_tasks())
    {
      if (t.id != id)
      {
        continue;
      }
      found = true;
      EXPECT_NE(t.note.find("Does not delete files"), std::string::npos);
    }
    EXPECT_TRUE(found);
  }
}

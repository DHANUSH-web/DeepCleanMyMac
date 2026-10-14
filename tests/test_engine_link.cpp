#include "dcmm/common/dcmm.h"
#include "dcmm/common/engine.hpp"
#include "dcmm/common/path.hpp"

#include <gtest/gtest.h>

TEST(DesktopEngine, LinksAndReportsDisk)
{
  dcmm::Engine e;
  auto d = e.disk("/");
  EXPECT_GT(d.totalBytes, 0u);
}

TEST(DesktopEngine, CAbiVersion)
{
  EXPECT_STREQ(dcmm_version(), "1.0.0");
}

TEST(DesktopEngine, RefusesToTrashRoot)
{
  dcmm::Engine e;
  auto r = e.trash_paths({"/"});
  EXPECT_GE(r.failedItems, 1u);
  EXPECT_EQ(r.trashedItems, 0u);
}

TEST(DesktopEngine, RefusesHomeAndDocuments)
{
  dcmm::Engine e;
  auto home = dcmm::home_directory();
  EXPECT_EQ(e.trash_paths({home}).trashedItems, 0u);
  EXPECT_EQ(e.trash_paths({dcmm::join_path(home, "Documents")}).trashedItems, 0u);
}

TEST(DesktopEngine, EmptySelectionIsANoOp)
{
  dcmm::Engine e;
  auto r = e.trash_paths({});
  EXPECT_EQ(r.trashedItems, 0u);
  EXPECT_EQ(r.trashedBytes, 0u);
}

#include "dcmm/dcmm.h"
#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

TEST(DesktopEngine, LinksAndReportsDisk) {
  dcmm::Engine e;
  auto d = e.disk("/");
  EXPECT_GT(d.totalBytes, 0u);
}

TEST(DesktopEngine, CAbiVersion) {
  EXPECT_STREQ(dcmm_version(), "1.0.0");
}

TEST(DesktopEngine, RefusesToTrashRoot) {
  dcmm::Engine e;
  auto r = e.trashPaths({"/"});
  EXPECT_GE(r.failedItems, 1u);
  EXPECT_EQ(r.trashedItems, 0u);
}

TEST(DesktopEngine, RefusesHomeAndDocuments) {
  dcmm::Engine e;
  auto home = dcmm::homeDirectory();
  EXPECT_EQ(e.trashPaths({home}).trashedItems, 0u);
  EXPECT_EQ(e.trashPaths({dcmm::joinPath(home, "Documents")}).trashedItems, 0u);
}

TEST(DesktopEngine, EmptySelectionIsANoOp) {
  dcmm::Engine e;
  auto r = e.trashPaths({});
  EXPECT_EQ(r.trashedItems, 0u);
  EXPECT_EQ(r.trashedBytes, 0u);
}

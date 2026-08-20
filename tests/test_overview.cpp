#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

TEST(Overview, DiskUsageIsReadable) {
  dcmm::Engine e;
  auto d = e.disk("/");
  EXPECT_GT(d.totalBytes, 0u);
  EXPECT_LE(d.availableBytes, d.totalBytes);
  EXPECT_FALSE(d.mountPoint.empty());
}

TEST(Overview, MemoryStatsAreReadable) {
  dcmm::Engine e;
  auto m = e.memory();
  EXPECT_GT(m.totalBytes, 0u);
  EXPECT_LE(m.usedBytes, m.totalBytes);
}

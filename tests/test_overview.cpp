#include "SystemInfo.hpp"
#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

#include <algorithm>
#include <string>
#include <utility>
#include <vector>

namespace {

bool hasFact(const std::vector<std::pair<std::string, std::string>>& facts, const char* label) {
  return std::any_of(facts.begin(), facts.end(),
                     [&](const auto& f) { return f.first == label && !f.second.empty(); });
}

}  // namespace

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

TEST(Overview, CoreSummaryJoinsPerformanceAndEfficiency) {
  EXPECT_EQ(ui::formatCoreSummary(10, 4, 6), "10 (4 performance and 6 efficiency)");
  EXPECT_EQ(ui::formatCoreSummary(8, 0, 0), "8");
  EXPECT_TRUE(ui::formatCoreSummary(0, 0, 0).empty());
}

TEST(Overview, HostInfoHasModelChipMemoryAndOs) {
  auto h = ui::hostInfo();
  EXPECT_FALSE(h.modelId.empty());
  EXPECT_FALSE(h.chip.empty());
  EXPECT_GT(h.physicalCpus, 0);
  EXPECT_GT(h.memoryBytes, 0u);
  EXPECT_FALSE(h.osVersion.empty());
  EXPECT_FALSE(ui::formatOsLine(h).empty());
  auto facts = ui::machineFacts(h);
  EXPECT_TRUE(hasFact(facts, "Chip"));
  EXPECT_TRUE(hasFact(facts, "Cores"));
  EXPECT_TRUE(hasFact(facts, "Memory"));
  EXPECT_TRUE(hasFact(facts, "macOS"));
  EXPECT_TRUE(hasFact(facts, "Model"));
}

TEST(Overview, VolumeInfoHasStartupDiskAndSsdFacts) {
  auto v = ui::volumeInfo("/");
  EXPECT_GT(v.totalBytes, 0u);
  EXPECT_FALSE(v.volumeName.empty());
  EXPECT_FALSE(v.mountPoint.empty());
  EXPECT_FALSE(v.fileSystem.empty());
  EXPECT_FALSE(v.bsdName.empty());
  auto facts = ui::storageFacts(v);
  EXPECT_TRUE(hasFact(facts, "Kind"));
  EXPECT_TRUE(hasFact(facts, "File system"));
  EXPECT_TRUE(hasFact(facts, "Device"));
  EXPECT_TRUE(hasFact(facts, "Mount"));
  EXPECT_FALSE(ui::formatStorageKind(v).empty());
  if (v.solidState || v.protocol == "Apple Fabric")
    EXPECT_NE(ui::formatStorageKind(v).find("SSD"), std::string::npos);
}

TEST(Overview, StorageKindNamesInternalSsd) {
  ui::VolumeInfo v;
  v.internal = true;
  v.solidState = true;
  EXPECT_EQ(ui::formatStorageKind(v), "Internal SSD");
  v.solidState = false;
  v.protocol = "Apple Fabric";
  EXPECT_EQ(ui::formatStorageKind(v), "Internal SSD");
  v.protocol.clear();
  v.deviceModel = "APPLE SSD AP0512Z";
  EXPECT_EQ(ui::formatStorageKind(v), "Internal SSD");
}

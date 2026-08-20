#include "home_fixture.hpp"

#include "dcmm/dcmm.hpp"

#include <gtest/gtest.h>

TEST_F(HomeFixture, SpaceLensMeasuresHomeFolders) {
  writeBytes(home / "Downloads" / "movie.bin", 8192);
  writeBytes(home / "Library" / "Caches" / "c.bin", 4096);
  dcmm::Engine e;
  auto nodes = e.spaceLens();
  EXPECT_FALSE(nodes.empty());
  bool sawDownloads = false, sawCaches = false;
  for (const auto& n : nodes) {
    if (n.name == "Downloads") sawDownloads = true;
    if (n.name.find("Caches") != std::string::npos) sawCaches = true;
  }
  EXPECT_TRUE(sawDownloads);
  EXPECT_TRUE(sawCaches);
  for (std::size_t i = 1; i < nodes.size(); ++i) EXPECT_GE(nodes[i - 1].bytes, nodes[i].bytes);
}

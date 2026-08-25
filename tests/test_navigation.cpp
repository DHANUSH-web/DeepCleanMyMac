#include "AppFeatures.hpp"
#include "Modules.h"

#include <gtest/gtest.h>
#include <set>

TEST(Navigation, SidebarHasASymbolPerModule) {
  for (int i = 0; i < static_cast<int>(ui::Module::Count); ++i) {
    auto m = static_cast<ui::Module>(i);
    EXPECT_TRUE(ui::sidebarSymbol(m) && *ui::sidebarSymbol(m)) << ui::title(m);
  }
}

TEST(Navigation, DashboardToolsAreASubsetOfSidebar) {
  auto tools = ui::dashboardTools();
  EXPECT_EQ(tools.size(), 6u);
  std::set<int> seen;
  for (const auto& t : tools) {
    EXPECT_GE(static_cast<int>(t.module), 0);
    EXPECT_LT(static_cast<int>(t.module), static_cast<int>(ui::Module::Count));
    EXPECT_STREQ(t.title, ui::title(t.module));
    EXPECT_STREQ(t.symbol, ui::sidebarSymbol(t.module));
    EXPECT_TRUE(t.subtitle && *t.subtitle);
    EXPECT_TRUE(seen.insert(static_cast<int>(t.module)).second) << "duplicate dashboard tool";
  }
}

TEST(Navigation, DashboardDoesNotReplaceSystemJunkOrSpaceLens) {
  bool hasJunk = false, hasLens = false, hasOverview = false, hasSmart = false, hasSettings = false;
  for (const auto& t : ui::dashboardTools()) {
    if (t.module == ui::Module::SystemJunk) hasJunk = true;
    if (t.module == ui::Module::SpaceLens) hasLens = true;
    if (t.module == ui::Module::Overview) hasOverview = true;
    if (t.module == ui::Module::SmartScan) hasSmart = true;
    if (t.module == ui::Module::Settings) hasSettings = true;
  }
  EXPECT_TRUE(hasSmart);
  EXPECT_FALSE(hasJunk);
  EXPECT_FALSE(hasLens);
  EXPECT_FALSE(hasOverview);
  EXPECT_FALSE(hasSettings);
}

TEST(Navigation, ScanDispatchOnlyForScanPages) {
  dcmm::Engine e;
  auto empty = ui::runScan(e, ui::Module::Overview);
  EXPECT_TRUE(empty.groups.empty());
  empty = ui::runScan(e, ui::Module::LargeFiles);
  EXPECT_TRUE(empty.groups.empty());
}

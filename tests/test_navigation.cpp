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
  EXPECT_EQ(tools.size(), 8u);
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

TEST(Navigation, DashboardHasNeccessaryDashboardToolsOnly)
{
  bool hasSmartScan = false,
  hasDeepScan       = false,
  hasLargeFiles     = false,
  hasDuplicates     = false,
  hasUninstaller    = false,
  hasPrivacy        = false,
  hasSpaceLens      = false,
  hasMyMac          = false,
  hasSettings       = false,
  hasMaintenance    = false;

  for (const auto& t : ui::dashboardTools())
  {
    if (t.module == ui::Module::SmartScan)
      hasSmartScan = true;
    else if (t.module == ui::Module::DeepScan)
      hasDeepScan = true;
    else if (t.module == ui::Module::LargeFiles)
      hasLargeFiles = true;
    else if (t.module == ui::Module::Duplicates)
      hasDuplicates = true;
    else if (t.module == ui::Module::Uninstaller)
      hasUninstaller = true;
    else if (t.module == ui::Module::Privacy)
      hasPrivacy = true;
    else if (t.module == ui::Module::SpaceLens)
      hasSpaceLens = true;
    else if (t.module == ui::Module::Maintenance)
      hasMaintenance = true;
    else if (t.module == ui::Module::Settings)
      hasSettings = true;
    else if (t.module == ui::Module::MyMac)
      hasMyMac = true;
  }

  EXPECT_TRUE(hasSmartScan);
  EXPECT_TRUE(hasDeepScan);
  EXPECT_TRUE(hasLargeFiles);
  EXPECT_TRUE(hasDuplicates);
  EXPECT_TRUE(hasUninstaller);
  EXPECT_TRUE(hasPrivacy);
  EXPECT_TRUE(hasSpaceLens);
  EXPECT_TRUE(hasMaintenance);
  EXPECT_FALSE(hasMyMac);
  EXPECT_FALSE(hasSettings);
}

TEST(Navigation, ScanDispatchOnlyForScanPages) {
  dcmm::Engine e;
  auto empty = ui::runScan(e, ui::Module::MyMac);
  EXPECT_TRUE(empty.groups.empty());
  empty = ui::runScan(e, ui::Module::LargeFiles);
  EXPECT_TRUE(empty.groups.empty());
}

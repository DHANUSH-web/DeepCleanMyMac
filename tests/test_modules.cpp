#include "Modules.h"

#include <gtest/gtest.h>

TEST(Modules, Titles) {
  EXPECT_STREQ(ui::title(ui::Module::Overview), "Overview");
  EXPECT_STREQ(ui::title(ui::Module::SmartScan), "Smart Scan");
  EXPECT_STREQ(ui::subtitle(ui::Module::Privacy), "Browser traces and tracking leftovers");
  EXPECT_EQ(static_cast<int>(ui::Module::Count), 9);
}

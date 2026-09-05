#include "AppFeatures.hpp"
#include "Modules.h"

#include <gtest/gtest.h>
#include <set>
#include <string>

TEST(Modules, CountAndOrder) {
  EXPECT_EQ(static_cast<int>(ui::Module::MyMac), 0);
  EXPECT_EQ(static_cast<int>(ui::Module::SmartScan), 1);
  EXPECT_EQ(static_cast<int>(ui::Module::DeepScan), 2);
  EXPECT_EQ(static_cast<int>(ui::Module::LargeFiles), 3);
  EXPECT_EQ(static_cast<int>(ui::Module::Duplicates), 4);
  EXPECT_EQ(static_cast<int>(ui::Module::Uninstaller), 5);
  EXPECT_EQ(static_cast<int>(ui::Module::Privacy), 6);
  EXPECT_EQ(static_cast<int>(ui::Module::SpaceLens), 7);
  EXPECT_EQ(static_cast<int>(ui::Module::Maintenance), 8);
  EXPECT_EQ(static_cast<int>(ui::Module::Settings), 9);
  EXPECT_EQ(static_cast<int>(ui::Module::Count), 10);
}

TEST(Modules, EveryPageHasTitleAndSubtitle) {
  std::set<std::string> titles;
  for (int i = 0; i < static_cast<int>(ui::Module::Count); ++i) {
    auto m = static_cast<ui::Module>(i);
    auto t = ui::title(m);
    auto s = ui::subtitle(m);
    ASSERT_TRUE(t && *t);
    ASSERT_TRUE(s && *s);
    titles.insert(t);
    EXPECT_TRUE(ui::sidebarSymbol(m) && *ui::sidebarSymbol(m));
  }
  EXPECT_EQ(titles.size(), static_cast<size_t>(ui::Module::Count));
}

TEST(Modules, Titles) {
  EXPECT_STREQ(ui::title(ui::Module::MyMac), "My Mac");
  EXPECT_STREQ(ui::title(ui::Module::SmartScan), "Smart Scan");
  EXPECT_STREQ(ui::title(ui::Module::DeepScan), "Deep Scan");
  EXPECT_STREQ(ui::title(ui::Module::LargeFiles), "Large Files");
  EXPECT_STREQ(ui::title(ui::Module::Duplicates), "Duplicates");
  EXPECT_STREQ(ui::title(ui::Module::Uninstaller), "Uninstaller");
  EXPECT_STREQ(ui::title(ui::Module::Privacy), "Privacy");
  EXPECT_STREQ(ui::title(ui::Module::SpaceLens), "Space Lens");
  EXPECT_STREQ(ui::title(ui::Module::Maintenance), "Maintenance");
  EXPECT_STREQ(ui::title(ui::Module::Settings), "Settings");
}

TEST(Modules, Subtitles) {
  EXPECT_STREQ(ui::subtitle(ui::Module::MyMac), "Your MacBook, startup disk and DCMM tools");
  EXPECT_STREQ(ui::subtitle(ui::Module::SmartScan), "Recommended safe groups — no file picking");
  EXPECT_STREQ(ui::subtitle(ui::Module::DeepScan),
               "Item-by-item scan — review before cleaning. Not everything here is safe to remove");
  EXPECT_STREQ(ui::subtitle(ui::Module::LargeFiles), "Oversized files hogging the disk");
  EXPECT_STREQ(ui::subtitle(ui::Module::Duplicates), "Copies you no longer need");
  EXPECT_STREQ(ui::subtitle(ui::Module::Uninstaller), "Uninstall multiple apps and their leftover files at once");
  EXPECT_STREQ(ui::subtitle(ui::Module::Privacy), "Browser traces and tracking leftovers");
  EXPECT_STREQ(ui::subtitle(ui::Module::SpaceLens),
               "Find all the heavy items, including hidden files and folders");
  EXPECT_STREQ(ui::subtitle(ui::Module::Maintenance), "Some more tools for your MacBook");
  EXPECT_STREQ(ui::subtitle(ui::Module::Settings), "Manage DCMM appearance and behaviour");
}

TEST(Modules, UnknownIsEmpty) {
  EXPECT_STREQ(ui::title(static_cast<ui::Module>(99)), "");
  EXPECT_STREQ(ui::subtitle(static_cast<ui::Module>(99)), "");
}

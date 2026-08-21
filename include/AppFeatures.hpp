#pragma once

#include "Modules.h"

#include "dcmm/dcmm.hpp"

#include <array>
#include <cstdio>
#include <string>
#include <vector>

namespace ui {

inline const char* sidebarSymbol(Module m) {
  switch (m) {
    case Module::Overview: return "square.grid.2x2";
    case Module::SmartScan: return "sparkles";
    case Module::SystemJunk: return "internaldrive";
    case Module::LargeFiles: return "doc.badge.ellipsis";
    case Module::Duplicates: return "doc.on.doc";
    case Module::Uninstaller: return "shippingbox";
    case Module::Privacy: return "eye.slash";
    case Module::SpaceLens: return "chart.bar";
    case Module::Maintenance: return "wrench.and.screwdriver";
    default: return "questionmark.circle";
  }
}

struct DashboardTool {
  Module module;
  const char* symbol;
  const char* title;
  const char* subtitle;
};

inline std::array<DashboardTool, 6> dashboardTools() {
  return {{
      {Module::SmartScan, sidebarSymbol(Module::SmartScan), "Smart Scan",
       "Recommended caches and logs. Clean whole groups, not individual files."},
      {Module::LargeFiles, sidebarSymbol(Module::LargeFiles), "Large Files",
       "Surface oversized files you can review and remove."},
      {Module::Duplicates, sidebarSymbol(Module::Duplicates), "Duplicates",
       "Hash-matched copies under common folders."},
      {Module::Uninstaller, sidebarSymbol(Module::Uninstaller), "Uninstaller",
       "Remove an app together with leftover files."},
      {Module::Privacy, sidebarSymbol(Module::Privacy), "Privacy",
       "Browser caches and tracking leftovers you choose."},
      {Module::Maintenance, sidebarSymbol(Module::Maintenance), "Maintenance",
       "Empty Trash, flush DNS, rebuild Launch Services."},
  }};
}

inline dcmm::ScanReport runScan(dcmm::Engine& engine, Module page,
                                const dcmm::ProgressFn& progress = nullptr) {
  switch (page) {
    case Module::SmartScan: return engine.scanSmart(progress);
    case Module::SystemJunk: return engine.scanJunk(progress);
    case Module::Privacy: return engine.scanPrivacy(progress);
    default: return {};
  }
}

inline bool allScanItemsSelected(const dcmm::ScanReport& r) {
  bool any = false;
  for (const auto& g : r.groups)
    for (const auto& it : g.items) {
      any = true;
      if (!it.selected) return false;
    }
  return any;
}

inline void setAllScanItemsSelected(dcmm::ScanReport& r, bool selected) {
  for (auto& g : r.groups)
    for (auto& it : g.items) it.selected = selected;
}

inline dcmm::LargeFileOptions largeFileOptions(const std::string& home = dcmm::homeDirectory()) {
  dcmm::LargeFileOptions opt;
  opt.roots = {dcmm::joinPath(home, "Desktop"), dcmm::joinPath(home, "Documents"),
               dcmm::joinPath(home, "Downloads"), dcmm::joinPath(home, "Movies")};
  opt.minBytes = 50ull * 1024ull * 1024ull;
  opt.limit = 300;
  return opt;
}

inline dcmm::DuplicateOptions duplicateOptions(const std::string& home = dcmm::homeDirectory()) {
  dcmm::DuplicateOptions opt;
  opt.roots = {dcmm::joinPath(home, "Downloads"), dcmm::joinPath(home, "Desktop"),
               dcmm::joinPath(home, "Documents")};
  opt.minBytes = 256ull * 1024ull;
  return opt;
}

inline std::vector<std::string> selectedLargeFilePaths(const std::vector<dcmm::LargeFile>& files) {
  std::vector<std::string> out;
  for (const auto& f : files)
    if (f.selected) out.push_back(f.path);
  return out;
}

inline std::vector<std::string> duplicatePathsToTrash(
    const std::vector<dcmm::DuplicateGroup>& groups) {
  std::vector<std::string> out;
  for (const auto& g : groups)
    for (const auto& f : g.files)
      if (!f.keep) out.push_back(f.path);
  return out;
}

inline std::array<const char*, 4> maintenanceIds() {
  return {"empty_trash", "flush_dns", "launch_services", "quicklook"};
}

inline std::string spaceSharePercent(uint64_t bytes, uint64_t total) {
  if (total == 0 || bytes == 0) return "0%";
  const double p = 100.0 * static_cast<double>(bytes) / static_cast<double>(total);
  char buf[32];
  if (p >= 9.95)
    std::snprintf(buf, sizeof(buf), "%.0f%%", p);
  else if (p >= 0.05)
    std::snprintf(buf, sizeof(buf), "%.1f%%", p);
  else
    std::snprintf(buf, sizeof(buf), "<0.1%%");
  return buf;
}

}  // namespace ui

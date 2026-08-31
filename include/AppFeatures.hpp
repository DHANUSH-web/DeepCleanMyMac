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
    case Module::Settings: return "gearshape";
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

inline void appendUniquePath(std::vector<std::string>& out, const std::string& path) {
  if (path.empty()) return;
  for (const auto& e : out)
    if (e == path) return;
  out.push_back(path);
}

inline std::vector<std::string> applicationSupportNames(const dcmm::InstalledApp& app) {
  std::vector<std::string> names;
  auto add = [&](std::string n) {
    if (n.empty()) return;
    while (!n.empty() && (n.back() == '/' || n.back() == '\\')) n.pop_back();
    const auto slash = n.find_last_of("/\\");
    if (slash != std::string::npos) n = n.substr(slash + 1);
    if (n.size() > 4 && n.compare(n.size() - 4, 4, ".app") == 0) n.resize(n.size() - 4);
    if (n.empty()) return;
    for (const auto& e : names)
      if (e == n) return;
    names.push_back(std::move(n));
  };
  add(app.bundleId);
  add(app.name);
  add(dcmm::displayName(app.appPath));
  return names;
}

inline std::vector<std::string> applicationSupportLeftoverPaths(const dcmm::InstalledApp& app) {
  const auto root = dcmm::joinPath(dcmm::homeDirectory(), "Library/Application Support");
  std::vector<std::string> out;
  for (const auto& n : applicationSupportNames(app)) {
    const auto p = dcmm::joinPath(root, n);
    if (dcmm::pathExists(p) && dcmm::isSafeToTrash(p)) appendUniquePath(out, p);
  }
  return out;
}

inline std::vector<std::string> uninstallPaths(const dcmm::InstalledApp& app) {
  std::vector<std::string> out;
  appendUniquePath(out, app.appPath);
  for (const auto& p : applicationSupportLeftoverPaths(app)) appendUniquePath(out, p);
  for (const auto& it : app.leftovers)
    if (it.selected) appendUniquePath(out, it.path);
  return out;
}

inline uint64_t uninstallBytes(const dcmm::InstalledApp& app) {
  uint64_t n = 0;
  const auto paths = uninstallPaths(app);
  for (const auto& p : paths) {
    if (p == app.appPath) {
      n += app.appBytes;
      continue;
    }
    for (const auto& it : app.leftovers)
      if (it.path == p) {
        n += it.bytes;
        break;
      }
  }
  return n;
}

inline std::vector<std::string> uninstallPaths(const std::vector<dcmm::InstalledApp>& apps) {
  std::vector<std::string> out;
  for (const auto& app : apps) {
    auto p = uninstallPaths(app);
    out.insert(out.end(), p.begin(), p.end());
  }
  return out;
}

inline uint64_t uninstallBytes(const std::vector<dcmm::InstalledApp>& apps) {
  uint64_t n = 0;
  for (const auto& app : apps) n += uninstallBytes(app);
  return n;
}

inline std::array<const char*, 4> maintenanceIds() {
  return {"empty_trash", "flush_dns", "launch_services", "quicklook"};
}

enum class SpaceSizeBand { Normal, Big, TooBig };

inline constexpr uint64_t kSpaceBigBytes = 500ull * 1024ull * 1024ull;
inline constexpr uint64_t kSpaceTooBigBytes = 1024ull * 1024ull * 1024ull;

inline SpaceSizeBand spaceSizeBand(uint64_t bytes) {
  if (bytes > kSpaceTooBigBytes) return SpaceSizeBand::TooBig;
  if (bytes > kSpaceBigBytes) return SpaceSizeBand::Big;
  return SpaceSizeBand::Normal;
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

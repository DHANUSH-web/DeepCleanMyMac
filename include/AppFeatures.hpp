#pragma once

#include "Modules.h"

#include "dcmm/dcmm.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdio>
#include <string>
#include <vector>

namespace ui {

inline const char* sidebarSymbol(Module m) {
  switch (m) {
    case Module::Overview:    return "internaldrive.fill";
    case Module::SmartScan:   return "apple.intelligence";
    case Module::SystemJunk:  return "externaldrive.connected.to.line.below.fill";
    case Module::LargeFiles:  return "arrow.up.circle.fill";
    case Module::Duplicates:  return "square.stack.3d.up.fill";
    case Module::Uninstaller: return "trash.fill";
    case Module::Privacy:     return "hand.raised.fill";
    case Module::SpaceLens:   return "binoculars.fill";
    case Module::Maintenance: return "bolt.fill";
    case Module::Settings:    return "gear";
    default:                  return "questionmark.circle.fill";
  }
}

struct DashboardTool {
  Module module;
  const char* symbol;
  const char* title;
  const char* subtitle;
};

inline std::array<DashboardTool, 8> dashboardTools() {
  return {{
      {Module::SmartScan, sidebarSymbol(Module::SmartScan), "Smart Scan",
       "Recommended caches and logs. Clean whole groups, not individual files."},
      {Module::SystemJunk, sidebarSymbol(Module::SystemJunk), "System Wide Scan",
       "Deep clean your Mac HD, find who is the hidden culprit."},
      {Module::LargeFiles, sidebarSymbol(Module::LargeFiles), "Large Files",
       "Surface oversized files you can review and remove."},
      {Module::Duplicates, sidebarSymbol(Module::Duplicates), "Duplicates",
       "Hash-matched copies under common folders."},
      {Module::Uninstaller, sidebarSymbol(Module::Uninstaller), "Uninstaller",
       "Uninstall multiple apps and their leftover files at once."},
      {Module::Privacy, sidebarSymbol(Module::Privacy), "Privacy",
       "Browser caches and tracking leftovers you choose."},
      {Module::SpaceLens, sidebarSymbol(Module::SpaceLens), "Space Lens",
        "Find all hidden heavy items in your MacBook."},
      {Module::Maintenance, sidebarSymbol(Module::Maintenance), "Maintenance",
       "Empty Trash, flush DNS, rebuild Launch Services."},
  }};
}

inline bool scanNameHasComApple(const std::string& name) {
  std::string lower = name;
  for (char& c : lower) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return lower.find("com.apple") != std::string::npos;
}

inline bool isNativeAppleScanItem(const dcmm::ScanItem& it) {
  return scanNameHasComApple(it.displayName) || scanNameHasComApple(dcmm::displayName(it.path));
}

inline void regroupNativeSystemItems(dcmm::ScanReport& r) {
  dcmm::ScanGroup native;
  native.id = "native_system";
  native.title = "Native System Items";
  native.subtitle = "Apple identifiers (com.apple) — not safe to delete";
  native.reviewFirst = true;
  for (auto& g : r.groups) {
    std::vector<dcmm::ScanItem> keep;
    keep.reserve(g.items.size());
    for (auto& it : g.items) {
      if (isNativeAppleScanItem(it)) {
        it.selected = false;
        it.reviewFirst = true;
        native.items.push_back(std::move(it));
      } else {
        keep.push_back(std::move(it));
      }
    }
    g.items = std::move(keep);
  }
  r.groups.erase(std::remove_if(r.groups.begin(), r.groups.end(),
                                [](const dcmm::ScanGroup& g) { return g.items.empty(); }),
                 r.groups.end());
  if (native.items.empty()) return;
  native.sortBySizeDescending();
  r.groups.insert(r.groups.begin(), std::move(native));
}

inline dcmm::ScanReport runScan(dcmm::Engine& engine, Module page,
                                const dcmm::ProgressFn& progress = nullptr) {
  switch (page) {
    case Module::SmartScan: return engine.scanSmart(progress);
    case Module::SystemJunk: {
      auto r = engine.scanJunk(progress);
      regroupNativeSystemItems(r);
      return r;
    }
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

enum class GroupCheck { Off, Mixed, On };

inline GroupCheck scanGroupCheck(const dcmm::ScanGroup& g) {
  if (g.items.empty()) return GroupCheck::Off;
  bool any = false, all = true;
  for (const auto& it : g.items) {
    if (it.selected) any = true;
    else all = false;
  }
  if (all) return GroupCheck::On;
  if (any) return GroupCheck::Mixed;
  return GroupCheck::Off;
}

inline void setScanGroupSelected(dcmm::ScanGroup& g, bool selected) {
  for (auto& it : g.items) it.selected = selected;
}

struct LargeFileRootSpec {
  const char* id;
  const char* title;
  std::string path;
};

inline std::vector<LargeFileRootSpec> largeFileRootSpecs(const std::string& home = dcmm::homeDirectory()) {
  return {
      {"desktop", "Desktop", dcmm::joinPath(home, "Desktop")},
      {"documents", "Documents", dcmm::joinPath(home, "Documents")},
      {"downloads", "Downloads", dcmm::joinPath(home, "Downloads")},
      {"pictures", "Pictures", dcmm::joinPath(home, "Pictures")},
      {"movies", "Movies", dcmm::joinPath(home, "Movies")},
      {"music", "Music", dcmm::joinPath(home, "Music")},
      {"icloud", "iCloud Drive",
       dcmm::joinPath(home, "Library/Mobile Documents/com~apple~CloudDocs")},
      {"bin", "Bin", dcmm::joinPath(home, ".Trash")},
  };
}

inline dcmm::LargeFileOptions largeFileOptions(const std::string& home = dcmm::homeDirectory()) {
  dcmm::LargeFileOptions opt;
  for (const auto& s : largeFileRootSpecs(home)) opt.roots.push_back(s.path);
  const auto icloudLink = dcmm::joinPath(home, "iCloud Drive");
  if (dcmm::pathExists(icloudLink)) opt.roots.push_back(icloudLink);
  opt.minBytes = 50ull * 1024ull * 1024ull;
  opt.limit = 300;
  return opt;
}

inline bool largeFilePathInRoot(const std::string& path, const std::string& root) {
  if (root.empty() || path.size() < root.size()) return false;
  if (path.compare(0, root.size(), root) != 0) return false;
  if (path.size() == root.size()) return true;
  const char c = path[root.size()];
  return c == '/' || c == '\\';
}

struct LargeFileGroup {
  std::string id;
  std::string title;
  std::vector<dcmm::LargeFile> files;
  uint64_t totalBytes() const {
    uint64_t n = 0;
    for (const auto& f : files) n += f.bytes;
    return n;
  }
};

inline std::vector<LargeFileGroup> groupLargeFiles(const std::vector<dcmm::LargeFile>& files,
                                                   const std::string& home = dcmm::homeDirectory()) {
  auto specs = largeFileRootSpecs(home);
  const auto icloudLink = dcmm::joinPath(home, "iCloud Drive");
  std::vector<LargeFileGroup> groups;
  groups.reserve(specs.size());
  for (const auto& s : specs) groups.push_back({s.id, s.title, {}});
  auto indexForPath = [&](const std::string& path) -> int {
    int best = -1;
    std::size_t bestLen = 0;
    for (int i = 0; i < (int)specs.size(); ++i) {
      if (largeFilePathInRoot(path, specs[(size_t)i].path) && specs[(size_t)i].path.size() >= bestLen) {
        best = i;
        bestLen = specs[(size_t)i].path.size();
      }
    }
    if (best < 0 && largeFilePathInRoot(path, icloudLink)) {
      for (int i = 0; i < (int)specs.size(); ++i)
        if (specs[(size_t)i].id == std::string("icloud")) return i;
    }
    return best;
  };
  for (const auto& f : files) {
    int i = indexForPath(f.path);
    if (i >= 0) groups[(size_t)i].files.push_back(f);
  }
  groups.erase(std::remove_if(groups.begin(), groups.end(),
                              [](const LargeFileGroup& g) { return g.files.empty(); }),
               groups.end());
  return groups;
}

inline GroupCheck largeFileGroupCheck(const LargeFileGroup& g) {
  if (g.files.empty()) return GroupCheck::Off;
  bool any = false, all = true;
  for (const auto& f : g.files) {
    if (f.selected) any = true;
    else all = false;
  }
  if (all) return GroupCheck::On;
  if (any) return GroupCheck::Mixed;
  return GroupCheck::Off;
}

inline void setLargeFileGroupSelected(LargeFileGroup& g, bool selected) {
  for (auto& f : g.files) f.selected = selected;
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

inline std::vector<std::string> selectedLargeFilePaths(const std::vector<LargeFileGroup>& groups) {
  std::vector<std::string> out;
  for (const auto& g : groups)
    for (const auto& f : g.files)
      if (f.selected) out.push_back(f.path);
  return out;
}

inline uint64_t selectedLargeFileBytes(const std::vector<LargeFileGroup>& groups) {
  uint64_t n = 0;
  for (const auto& g : groups)
    for (const auto& f : g.files)
      if (f.selected) n += f.bytes;
  return n;
}

/// Orange warning on default home-folder roots and on Library items that are
/// not safe to delete (Keychains, Mail, …). Junk-category roots such as
/// Caches and Logs do not get a mark.
inline bool spaceLensDanger(const std::string& path) {
  if (path.empty()) return false;
  std::string p = path;
  while (p.size() > 1 && (p.back() == '/' || p.back() == '\\')) p.pop_back();
  const std::string home = dcmm::homeDirectory();
  static const char* roots[] = {"Desktop", "Documents", "Downloads", "Pictures",
                                "Movies",  "Music",     "Public",    "Applications",
                                nullptr};
  for (int i = 0; roots[i]; ++i) {
    if (p == dcmm::joinPath(home, roots[i])) return true;
  }
  if (dcmm::isJunkCategoryRoot(p)) return false;
  const auto library = dcmm::joinPath(home, "Library");
  const bool underLibrary =
      p == library || (p.size() > library.size() && p.compare(0, library.size(), library) == 0 &&
                       (p[library.size()] == '/' || p[library.size()] == '\\'));
  return underLibrary;
}

inline bool spacePathIsUnder(const std::string& child, const std::string& parent) {
  if (parent.empty() || child.size() <= parent.size()) return false;
  if (child.compare(0, parent.size(), parent) != 0) return false;
  const char c = child[parent.size()];
  return c == '/' || c == '\\';
}

/// Keep ancestors only so deleting a folder does not also list its children.
inline void pruneNestedSpaceLensPaths(std::vector<std::string>& paths) {
  std::sort(paths.begin(), paths.end(),
            [](const std::string& a, const std::string& b) { return a.size() < b.size(); });
  std::vector<std::string> kept;
  kept.reserve(paths.size());
  for (const auto& p : paths) {
    if (p.empty()) continue;
    bool nested = false;
    for (const auto& k : kept) {
      if (spacePathIsUnder(p, k)) {
        nested = true;
        break;
      }
    }
    if (!nested) kept.push_back(p);
  }
  paths = std::move(kept);
}

inline std::vector<std::string> selectedSpaceLensPaths(const std::vector<dcmm::SpaceNode>& nodes,
                                                       const std::vector<char>& selected) {
  std::vector<std::string> out;
  for (std::size_t i = 0; i < nodes.size(); ++i) {
    if (i >= selected.size() || !selected[i]) continue;
    if (nodes[i].path.empty()) continue;
    out.push_back(nodes[i].path);
  }
  pruneNestedSpaceLensPaths(out);
  return out;
}

inline uint64_t selectedSpaceLensBytes(const std::vector<dcmm::SpaceNode>& nodes,
                                       const std::vector<char>& selected) {
  auto paths = selectedSpaceLensPaths(nodes, selected);
  uint64_t n = 0;
  for (const auto& p : paths)
    for (std::size_t i = 0; i < nodes.size(); ++i)
      if (nodes[i].path == p) {
        n += nodes[i].bytes;
        break;
      }
  return n;
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
  for (const auto& it : app.leftovers) appendUniquePath(out, it.path);
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

/// Share of `bytes` against disk volume capacity (`total`), not the listed-row sum.
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

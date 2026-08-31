#pragma once

#include "AppFeatures.hpp"

#include "dcmm/dcmm.hpp"
#include "dcmm/safety.hpp"

#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

namespace ui {

enum class AppearancePref { System = 0, Light, Dark };
enum class CleanPref { MoveToTrash = 0, DeletePermanently };

inline const char* appearancePrefId(AppearancePref p) {
  switch (p) {
    case AppearancePref::Light: return "light";
    case AppearancePref::Dark: return "dark";
    case AppearancePref::System:
    default: return "system";
  }
}

inline AppearancePref appearancePrefFromId(std::string_view id) {
  if (id == "light") return AppearancePref::Light;
  if (id == "dark") return AppearancePref::Dark;
  return AppearancePref::System;
}

inline const char* cleanPrefId(CleanPref p) {
  return p == CleanPref::DeletePermanently ? "delete" : "trash";
}

inline CleanPref cleanPrefFromId(std::string_view id) {
  if (id == "delete" || id == "permanent") return CleanPref::DeletePermanently;
  return CleanPref::MoveToTrash;
}

inline const char* cleanButtonTitle(CleanPref p) {
  return p == CleanPref::DeletePermanently ? "Delete Permanently" : "Move to Trash";
}

inline const char* cleanMenuTitle(CleanPref p) {
  return p == CleanPref::DeletePermanently ? "Delete Permanently…" : "Move to Trash…";
}

inline std::string cleanButtonTitleWithBytes(CleanPref p, uint64_t bytes) {
  if (bytes == 0) return cleanButtonTitle(p);
  if (p == CleanPref::DeletePermanently)
    return std::string("Delete ") + dcmm::formatBytes(bytes) + " Permanently";
  return std::string("Move ") + dcmm::formatBytes(bytes) + " to Trash";
}

inline const char* cleanNothingDetail(CleanPref p) {
  return p == CleanPref::DeletePermanently
             ? "No items were deleted. Protected paths are skipped."
             : "No items were moved. Protected paths are skipped.";
}

inline std::string cleanFinishedDetail(CleanPref p, const dcmm::CleanResult& r) {
  const char* how = p == CleanPref::DeletePermanently ? "deleting" : "moving";
  const char* dest = p == CleanPref::DeletePermanently ? "" : " to Trash";
  std::string s = "Freed " + dcmm::formatBytes(r.trashedBytes) + " by " + how + " " +
                  dcmm::formatCount(r.trashedItems, "item", "items") + dest + ".";
  if (r.failedItems) s += " " + std::to_string(r.failedItems) + " skipped.";
  return s;
}

inline std::vector<std::string> cleanTargets(const std::string& path) {
  namespace fs = std::filesystem;
  std::vector<std::string> out;
  if (path.empty()) return out;
  if (dcmm::isJunkCategoryRoot(path)) {
    std::error_code ec;
    fs::directory_iterator it(path, fs::directory_options::skip_permission_denied, ec);
    for (; it != fs::directory_iterator() && !ec; it.increment(ec)) {
      const std::string full = it->path().string();
      if (dcmm::isSafeToTrash(full)) out.push_back(full);
    }
    return out;
  }
  if (dcmm::isSafeToTrash(path)) out.push_back(path);
  return out;
}

inline uint64_t cleanPathBytes(const std::string& path) {
  namespace fs = std::filesystem;
  std::error_code ec;
  fs::path p(path);
  if (fs::is_regular_file(p, ec)) return fs::file_size(p, ec);
  uint64_t n = 0;
  fs::recursive_directory_iterator it(p, fs::directory_options::skip_permission_denied, ec);
  for (; it != fs::recursive_directory_iterator() && !ec; it.increment(ec)) {
    if (it->is_regular_file(ec)) n += it->file_size(ec);
  }
  return n;
}

inline dcmm::CleanResult applyClean(dcmm::Engine& engine, const std::vector<std::string>& paths,
                                    CleanPref mode) {
  if (mode != CleanPref::DeletePermanently) return engine.trashPaths(paths);
  namespace fs = std::filesystem;
  dcmm::CleanResult result;
  for (const auto& p : paths) {
    auto targets = cleanTargets(p);
    if (targets.empty()) {
      result.failedItems++;
      result.errors.push_back("Blocked (protected path): " + p);
      continue;
    }
    for (const auto& t : targets) {
      if (!dcmm::isSafeToTrash(t)) {
        result.failedItems++;
        result.errors.push_back("Blocked (protected path): " + t);
        continue;
      }
      const uint64_t bytes = cleanPathBytes(t);
      std::error_code rec;
      fs::remove_all(t, rec);
      if (rec) {
        result.failedItems++;
        result.errors.push_back(t + ": " + rec.message());
        continue;
      }
      result.trashedItems++;
      result.trashedBytes += bytes;
    }
  }
  return result;
}

inline bool moveOwnRiskToTrash(const std::string& path, std::string& err) {
  namespace fs = std::filesystem;
  std::error_code ec;
  fs::path src(path);
  if (!fs::exists(src, ec)) {
    err = "not found";
    return false;
  }
  const char* env = std::getenv("DCMM_TRASH");
  fs::path destRoot =
      env && *env ? fs::path(env) : fs::path(dcmm::joinPath(dcmm::homeDirectory(), ".Trash"));
  fs::create_directories(destRoot, ec);
  std::string stem = src.filename().string();
  fs::path dest = destRoot / stem;
  int n = 1;
  while (fs::exists(dest, ec)) dest = destRoot / (stem + " " + std::to_string(n++));
  fs::rename(src, dest, ec);
  if (!ec) return true;
  err = "could not move to Trash (" + ec.message() + ")";
  return false;
}

/// Space Lens clean: junk-category roots still expand to children; every other
/// checked row is removed at the user's own risk.
inline dcmm::CleanResult applySpaceLensClean(dcmm::Engine& engine,
                                             const std::vector<std::string>& paths,
                                             CleanPref mode) {
  namespace fs = std::filesystem;
  dcmm::CleanResult result;
  std::vector<std::string> enginePaths;
  std::vector<std::string> ownRisk;
  for (const auto& p : paths) {
    if (p.empty() || p == "/" || p == "\\") {
      result.failedItems++;
      result.errors.push_back("Blocked (protected path): " + p);
      continue;
    }
    if (dcmm::isJunkCategoryRoot(p) || dcmm::isSafeToTrash(p))
      enginePaths.push_back(p);
    else
      ownRisk.push_back(p);
  }
  if (!enginePaths.empty()) {
    auto r = applyClean(engine, enginePaths, mode);
    result.trashedItems += r.trashedItems;
    result.trashedBytes += r.trashedBytes;
    result.failedItems += r.failedItems;
    result.errors.insert(result.errors.end(), r.errors.begin(), r.errors.end());
  }
  for (const auto& t : ownRisk) {
    if (t.empty() || t == "/" || t == "\\") {
      result.failedItems++;
      result.errors.push_back("Blocked (protected path): " + t);
      continue;
    }
    const uint64_t bytes = cleanPathBytes(t);
    if (mode == CleanPref::DeletePermanently) {
      std::error_code rec;
      fs::remove_all(t, rec);
      if (rec) {
        result.failedItems++;
        result.errors.push_back(t + ": " + rec.message());
        continue;
      }
    } else {
      std::string err;
      if (!moveOwnRiskToTrash(t, err)) {
        result.failedItems++;
        result.errors.push_back(t + ": " + err);
        continue;
      }
    }
    result.trashedItems++;
    result.trashedBytes += bytes;
  }
  return result;
}

}  // namespace ui

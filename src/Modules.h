#pragma once

namespace ui {

enum class Module : int {
  Overview = 0,
  SmartScan,
  SystemJunk,
  LargeFiles,
  Duplicates,
  Uninstaller,
  Privacy,
  SpaceLens,
  Maintenance,
  Count
};

inline const char* title(Module m) {
  switch (m) {
    case Module::Overview: return "Overview";
    case Module::SmartScan: return "Smart Scan";
    case Module::SystemJunk: return "System Junk";
    case Module::LargeFiles: return "Large Files";
    case Module::Duplicates: return "Duplicates";
    case Module::Uninstaller: return "Uninstaller";
    case Module::Privacy: return "Privacy";
    case Module::SpaceLens: return "Space Lens";
    case Module::Maintenance: return "Maintenance";
    default: return "";
  }
}

inline const char* subtitle(Module m) {
  switch (m) {
    case Module::Overview: return "Disk health at a glance";
    case Module::SmartScan: return "Find reclaimable space in one pass";
    case Module::SystemJunk: return "Caches, logs, and leftover files";
    case Module::LargeFiles: return "Oversized files hogging the disk";
    case Module::Duplicates: return "Copies you no longer need";
    case Module::Uninstaller: return "Apps and their leftover files";
    case Module::Privacy: return "Browser traces and tracking leftovers";
    case Module::SpaceLens: return "Where your home folder went";
    case Module::Maintenance: return "Housekeeping tasks";
    default: return "";
  }
}

}  // namespace ui

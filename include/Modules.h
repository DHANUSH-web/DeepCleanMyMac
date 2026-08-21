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
    case Module::Overview: return "This Mac and the startup disk";
    case Module::SmartScan: return "Recommended safe groups — no file picking";
    case Module::SystemJunk: return "Every cache and leftover, item by item";
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

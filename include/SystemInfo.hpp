#pragma once

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace ui {

struct HostInfo {
  std::string computerName;
  std::string modelName;
  std::string modelId;
  std::string chip;
  int physicalCpus = 0;
  int performanceCpus = 0;
  int efficiencyCpus = 0;
  uint64_t memoryBytes = 0;
  uint64_t memoryUsedBytes = 0;
  uint64_t memoryWiredBytes = 0;
  uint64_t memoryCompressedBytes = 0;
  std::string osName;
  std::string osVersion;
  std::string osBuild;
  std::string serial;
  std::string hostname;
};

struct VolumeInfo {
  std::string volumeName;
  std::string mountPoint;
  std::string fileSystem;
  std::string bsdName;
  std::string deviceModel;
  std::string protocol;
  std::string volumeUUID;
  std::string mediumType;
  std::string smartStatus;
  std::string trim;
  uint64_t totalBytes = 0;
  uint64_t availableBytes = 0;
  uint64_t importantAvailableBytes = 0;
  uint64_t opportunisticAvailableBytes = 0;
  uint64_t purgeableBytes = 0;
  uint64_t mediaSizeBytes = 0;
  uint32_t blockSize = 0;
  bool internal = false;
  bool solidState = false;
  bool ejectable = false;
  bool encrypted = false;
  bool writable = false;
};

HostInfo hostInfo();
VolumeInfo volumeInfo(const std::string& path = "/");

inline constexpr const char* kMaskedSerial = "********";

std::string formatCoreSummary(int physical, int performance, int efficiency);
std::string formatOsLine(const HostInfo& h);
std::string formatStorageKind(const VolumeInfo& v);
/// Decimal (1000) units, same as System Settings storage.
std::string formatDiskBytes(uint64_t bytes);
std::string yesNo(bool v);

std::vector<std::pair<std::string, std::string>> machineFacts(const HostInfo& h);
std::vector<std::pair<std::string, std::string>> storageFacts(const VolumeInfo& v);

}  // namespace ui

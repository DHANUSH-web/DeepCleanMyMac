#include "SystemInfo.hpp"

#include "dcmm/path.hpp"

#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>
#include <IOKit/IOBSD.h>
#include <IOKit/IOKitKeys.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/storage/IOStorageDeviceCharacteristics.h>
#include <SystemConfiguration/SystemConfiguration.h>

#include <limits.h>
#include <mach/mach.h>
#include <sys/sysctl.h>

#include <cstring>

namespace ui {
namespace {

void cfRelease(CFTypeRef v) {
  if (v) CFRelease(v);
}

std::string cfString(CFTypeRef v) {
  if (!v) return {};
  if (CFGetTypeID(v) == CFStringGetTypeID()) {
    CFStringRef s = static_cast<CFStringRef>(v);
    CFIndex n = CFStringGetMaximumSizeForEncoding(CFStringGetLength(s), kCFStringEncodingUTF8) + 1;
    std::string out(static_cast<size_t>(n), '\0');
    if (!CFStringGetCString(s, out.data(), n, kCFStringEncodingUTF8)) return {};
    out.resize(std::strlen(out.c_str()));
    return out;
  }
  if (CFGetTypeID(v) == CFDataGetTypeID()) {
    CFDataRef d = static_cast<CFDataRef>(v);
    const UInt8* p = CFDataGetBytePtr(d);
    CFIndex n = CFDataGetLength(d);
    while (n > 0 && p[n - 1] == 0) --n;
    return std::string(reinterpret_cast<const char*>(p), reinterpret_cast<const char*>(p) + n);
  }
  if (CFGetTypeID(v) == CFUUIDGetTypeID()) {
    CFStringRef s = CFUUIDCreateString(kCFAllocatorDefault, static_cast<CFUUIDRef>(v));
    std::string out = cfString(s);
    cfRelease(s);
    return out;
  }
  if (CFGetTypeID(v) == CFBooleanGetTypeID())
    return CFBooleanGetValue(static_cast<CFBooleanRef>(v)) ? "Yes" : "No";
  if (CFGetTypeID(v) == CFNumberGetTypeID()) {
    long long n = 0;
    CFNumberGetValue(static_cast<CFNumberRef>(v), kCFNumberLongLongType, &n);
    return std::to_string(n);
  }
  return {};
}

bool cfBool(CFTypeRef v, bool fallback = false) {
  if (v && CFGetTypeID(v) == CFBooleanGetTypeID()) return CFBooleanGetValue(static_cast<CFBooleanRef>(v));
  return fallback;
}

uint64_t cfU64(CFTypeRef v) {
  if (!v) return 0;
  if (CFGetTypeID(v) == CFNumberGetTypeID()) {
    long long n = 0;
    CFNumberGetValue(static_cast<CFNumberRef>(v), kCFNumberLongLongType, &n);
    return n < 0 ? 0 : static_cast<uint64_t>(n);
  }
  return 0;
}

std::string sysctlString(const char* name) {
  size_t n = 0;
  if (sysctlbyname(name, nullptr, &n, nullptr, 0) != 0 || n == 0) return {};
  std::string s(n, '\0');
  if (sysctlbyname(name, s.data(), &n, nullptr, 0) != 0) return {};
  if (n > 0 && s[n - 1] == '\0') s.resize(n - 1);
  else s.resize(n);
  while (!s.empty() && s.back() == '\0') s.pop_back();
  return s;
}

int sysctlInt(const char* name) {
  int v = 0;
  size_t n = sizeof(v);
  if (sysctlbyname(name, &v, &n, nullptr, 0) != 0) return 0;
  return v;
}

uint64_t sysctlU64(const char* name) {
  uint64_t v = 0;
  size_t n = sizeof(v);
  if (sysctlbyname(name, &v, &n, nullptr, 0) != 0) return 0;
  return v;
}

std::string plistString(CFDictionaryRef dict, CFStringRef key) {
  if (!dict) return {};
  return cfString(CFDictionaryGetValue(dict, key));
}

std::string ioPropertyString(io_registry_entry_t entry, CFStringRef key) {
  if (!entry) return {};
  CFTypeRef v = IORegistryEntryCreateCFProperty(entry, key, kCFAllocatorDefault, 0);
  std::string s = cfString(v);
  cfRelease(v);
  return s;
}

bool ioPropertyBool(io_registry_entry_t entry, CFStringRef key) {
  if (!entry) return false;
  CFTypeRef v = IORegistryEntryCreateCFProperty(entry, key, kCFAllocatorDefault, 0);
  bool b = cfBool(v);
  cfRelease(v);
  return b;
}

void copyDictString(CFDictionaryRef dict, CFStringRef key, std::string& dest) {
  if (dest.empty()) dest = plistString(dict, key);
}

void scrapeDeviceDicts(io_registry_entry_t entry, VolumeInfo& v) {
  CFTypeRef dc = IORegistryEntryCreateCFProperty(entry, CFSTR(kIOPropertyDeviceCharacteristicsKey),
                                                 kCFAllocatorDefault, 0);
  if (dc && CFGetTypeID(dc) == CFDictionaryGetTypeID()) {
    auto d = static_cast<CFDictionaryRef>(dc);
    copyDictString(d, CFSTR(kIOPropertyProductNameKey), v.deviceModel);
    copyDictString(d, CFSTR(kIOPropertyMediumTypeKey), v.mediumType);
    if (v.trim.empty()) v.trim = plistString(d, CFSTR("TRIM Support"));
    if (v.smartStatus.empty()) {
      v.smartStatus = plistString(d, CFSTR("S.M.A.R.T. Status"));
      if (v.smartStatus.empty()) v.smartStatus = plistString(d, CFSTR("SMART Status"));
    }
    std::string medium = plistString(d, CFSTR(kIOPropertyMediumTypeKey));
    if (medium == kIOPropertyMediumTypeSolidStateKey) v.solidState = true;
  }
  cfRelease(dc);

  CFTypeRef pc = IORegistryEntryCreateCFProperty(entry, CFSTR(kIOPropertyProtocolCharacteristicsKey),
                                                 kCFAllocatorDefault, 0);
  if (pc && CFGetTypeID(pc) == CFDictionaryGetTypeID()) {
    auto d = static_cast<CFDictionaryRef>(pc);
    copyDictString(d, CFSTR(kIOPropertyPhysicalInterconnectTypeKey), v.protocol);
  }
  cfRelease(pc);

  if (ioPropertyBool(entry, CFSTR("Solid State"))) v.solidState = true;
  if (v.smartStatus.empty()) {
    std::string smart = ioPropertyString(entry, CFSTR("SMART Status"));
    if (smart.empty()) smart = ioPropertyString(entry, CFSTR("S.M.A.R.T. Status"));
    v.smartStatus = smart;
  }
  if (v.trim.empty()) v.trim = ioPropertyString(entry, CFSTR("TRIM Support"));
}

void scrapeFromBsd(const std::string& bsd, VolumeInfo& v) {
  if (bsd.empty()) return;
  CFMutableDictionaryRef match = IOBSDNameMatching(kIOMainPortDefault, 0, bsd.c_str());
  if (!match) return;
  io_registry_entry_t entry = IOServiceGetMatchingService(kIOMainPortDefault, match);
  int depth = 0;
  while (entry && depth < 18) {
    scrapeDeviceDicts(entry, v);
    io_registry_entry_t parent = IO_OBJECT_NULL;
    if (IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent) != KERN_SUCCESS) {
      IOObjectRelease(entry);
      break;
    }
    IOObjectRelease(entry);
    entry = parent;
    ++depth;
  }
  if (entry) IOObjectRelease(entry);
}

void fillUrlCapacities(const char* path, VolumeInfo& v) {
  CFStringRef p = CFStringCreateWithCString(kCFAllocatorDefault, path, kCFStringEncodingUTF8);
  if (!p) return;
  CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, p, kCFURLPOSIXPathStyle, true);
  cfRelease(p);
  if (!url) return;

  auto num = [&](CFStringRef key) -> uint64_t {
    CFTypeRef val = nullptr;
    CFURLCopyResourcePropertyForKey(url, key, &val, nullptr);
    uint64_t n = cfU64(val);
    cfRelease(val);
    return n;
  };
  auto str = [&](CFStringRef key) -> std::string {
    CFTypeRef val = nullptr;
    CFURLCopyResourcePropertyForKey(url, key, &val, nullptr);
    std::string s = cfString(val);
    cfRelease(val);
    return s;
  };
  auto flag = [&](CFStringRef key) -> bool {
    CFTypeRef val = nullptr;
    CFURLCopyResourcePropertyForKey(url, key, &val, nullptr);
    bool b = cfBool(val);
    cfRelease(val);
    return b;
  };

  if (v.volumeName.empty()) v.volumeName = str(kCFURLVolumeNameKey);
  if (v.fileSystem.empty()) v.fileSystem = str(kCFURLVolumeLocalizedFormatDescriptionKey);
  if (v.volumeUUID.empty()) v.volumeUUID = str(kCFURLVolumeUUIDStringKey);
  if (!v.totalBytes) v.totalBytes = num(kCFURLVolumeTotalCapacityKey);
  if (!v.availableBytes) v.availableBytes = num(kCFURLVolumeAvailableCapacityKey);
  if (!v.importantAvailableBytes)
    v.importantAvailableBytes = num(kCFURLVolumeAvailableCapacityForImportantUsageKey);
  if (!v.opportunisticAvailableBytes)
    v.opportunisticAvailableBytes = num(kCFURLVolumeAvailableCapacityForOpportunisticUsageKey);
  v.encrypted = v.encrypted || flag(kCFURLVolumeIsEncryptedKey);
  if (flag(kCFURLVolumeIsInternalKey)) v.internal = true;
  cfRelease(url);
}

std::string dictGet(CFDictionaryRef d, CFStringRef key) {
  if (!d) return {};
  return cfString(CFDictionaryGetValue(d, key));
}

bool dictBool(CFDictionaryRef d, CFStringRef key) {
  if (!d) return false;
  return cfBool(CFDictionaryGetValue(d, key));
}

uint64_t dictU64(CFDictionaryRef d, CFStringRef key) {
  if (!d) return 0;
  return cfU64(CFDictionaryGetValue(d, key));
}

void fillDiskArbitration(const char* path, VolumeInfo& v) {
  DASessionRef session = DASessionCreate(kCFAllocatorDefault);
  if (!session) return;
  CFStringRef p = CFStringCreateWithCString(kCFAllocatorDefault, path, kCFStringEncodingUTF8);
  CFURLRef url = p ? CFURLCreateWithFileSystemPath(kCFAllocatorDefault, p, kCFURLPOSIXPathStyle, true)
                   : nullptr;
  cfRelease(p);
  DADiskRef disk = url ? DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url) : nullptr;
  cfRelease(url);
  CFDictionaryRef desc = disk ? DADiskCopyDescription(disk) : nullptr;
  if (desc) {
    if (v.volumeName.empty()) v.volumeName = dictGet(desc, kDADiskDescriptionVolumeNameKey);
    if (v.fileSystem.empty()) v.fileSystem = dictGet(desc, kDADiskDescriptionVolumeKindKey);
    if (v.bsdName.empty()) v.bsdName = dictGet(desc, kDADiskDescriptionMediaBSDNameKey);
    if (v.deviceModel.empty()) v.deviceModel = dictGet(desc, kDADiskDescriptionDeviceModelKey);
    if (v.protocol.empty()) v.protocol = dictGet(desc, kDADiskDescriptionDeviceProtocolKey);
    if (std::string id = dictGet(desc, kDADiskDescriptionVolumeUUIDKey); !id.empty())
      v.volumeUUID = std::move(id);
    v.internal = v.internal || dictBool(desc, kDADiskDescriptionDeviceInternalKey);
    v.ejectable = dictBool(desc, kDADiskDescriptionMediaEjectableKey);
    v.encrypted = v.encrypted || dictBool(desc, kDADiskDescriptionMediaEncryptedKey);
    v.writable = dictBool(desc, kDADiskDescriptionMediaWritableKey);
    v.mediaSizeBytes = dictU64(desc, kDADiskDescriptionMediaSizeKey);
    v.blockSize = static_cast<uint32_t>(dictU64(desc, kDADiskDescriptionMediaBlockSizeKey));
    if (CFDictionaryContainsKey(desc, CFSTR("DAMediaSolidState")))
      v.solidState = dictBool(desc, CFSTR("DAMediaSolidState"));
    CFURLRef mount = static_cast<CFURLRef>(CFDictionaryGetValue(desc, kDADiskDescriptionVolumePathKey));
    if (mount && CFGetTypeID(mount) == CFURLGetTypeID()) {
      char buf[PATH_MAX]{};
      if (CFURLGetFileSystemRepresentation(mount, true, reinterpret_cast<UInt8*>(buf), sizeof(buf)))
        v.mountPoint = buf;
    }
  }
  DADiskRef whole = disk ? DADiskCopyWholeDisk(disk) : nullptr;
  CFDictionaryRef wdesc = whole ? DADiskCopyDescription(whole) : nullptr;
  if (wdesc) {
    if (v.deviceModel.empty()) v.deviceModel = dictGet(wdesc, kDADiskDescriptionDeviceModelKey);
    if (v.protocol.empty()) v.protocol = dictGet(wdesc, kDADiskDescriptionDeviceProtocolKey);
    v.internal = v.internal || dictBool(wdesc, kDADiskDescriptionDeviceInternalKey);
    if (CFDictionaryContainsKey(wdesc, CFSTR("DAMediaSolidState")))
      v.solidState = v.solidState || dictBool(wdesc, CFSTR("DAMediaSolidState"));
  }
  cfRelease(wdesc);
  if (whole) CFRelease(whole);
  cfRelease(desc);
  if (disk) CFRelease(disk);
  CFRelease(session);
}

void addFact(std::vector<std::pair<std::string, std::string>>& out, const char* label,
             std::string value) {
  if (value.empty()) return;
  out.emplace_back(label, std::move(value));
}

}  // namespace

std::string yesNo(bool v) { return v ? "Yes" : "No"; }

std::string formatCoreSummary(int physical, int performance, int efficiency) {
  if (performance > 0 && efficiency > 0) {
    const int total = physical > 0 ? physical : performance + efficiency;
    return std::to_string(total) + " (" + std::to_string(performance) + " performance and " +
           std::to_string(efficiency) + " efficiency)";
  }
  if (physical > 0) return std::to_string(physical);
  return {};
}

std::string formatOsLine(const HostInfo& h) {
  std::string name = h.osName.empty() ? "macOS" : h.osName;
  if (h.osVersion.empty()) return {};
  std::string s = name + " " + h.osVersion;
  if (!h.osBuild.empty()) s += " (" + h.osBuild + ")";
  return s;
}

std::string formatStorageKind(const VolumeInfo& v) {
  const bool ssd = v.solidState || v.mediumType == "Solid State" ||
                   v.protocol == "Apple Fabric" ||
                   v.deviceModel.find("SSD") != std::string::npos;
  std::string loc = v.internal ? "Internal" : (v.ejectable ? "External" : "Local");
  if (ssd) return loc + " SSD";
  return loc + " disk";
}

HostInfo hostInfo() {
  HostInfo h;
  if (CFStringRef name = SCDynamicStoreCopyComputerName(nullptr, nullptr)) {
    h.computerName = cfString(name);
    CFRelease(name);
  }
  if (h.computerName.empty()) {
    if (CFStringRef name = SCDynamicStoreCopyLocalHostName(nullptr)) {
      h.computerName = cfString(name);
      CFRelease(name);
    }
  }
  h.hostname = sysctlString("kern.hostname");
  h.modelId = sysctlString("hw.model");
  h.chip = sysctlString("machdep.cpu.brand_string");
  if (h.chip.empty() && sysctlInt("hw.optional.arm64")) h.chip = "Apple Silicon";
  h.physicalCpus = sysctlInt("hw.physicalcpu");
  h.performanceCpus = sysctlInt("hw.perflevel0.physicalcpu");
  h.efficiencyCpus = sysctlInt("hw.perflevel1.physicalcpu");
  h.memoryBytes = sysctlU64("hw.memsize");

  mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
  vm_statistics64_data_t vm{};
  if (host_statistics64(mach_host_self(), HOST_VM_INFO64, reinterpret_cast<host_info64_t>(&vm),
                        &count) == KERN_SUCCESS) {
    vm_size_t page = 0;
    host_page_size(mach_host_self(), &page);
    uint64_t pg = static_cast<uint64_t>(page);
    h.memoryWiredBytes = vm.wire_count * pg;
    h.memoryCompressedBytes = vm.compressor_page_count * pg;
    uint64_t freeb = vm.free_count * pg;
    h.memoryUsedBytes = h.memoryBytes > freeb ? h.memoryBytes - freeb : 0;
  }

  io_registry_entry_t product = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product");
  if (product) {
    h.modelName = ioPropertyString(product, CFSTR("product-name"));
    if (h.modelName.empty()) h.modelName = ioPropertyString(product, CFSTR("product-description"));
    IOObjectRelease(product);
  }
  io_service_t platform =
      IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
  if (platform) {
    h.serial = ioPropertyString(platform, CFSTR(kIOPlatformSerialNumberKey));
    if (h.modelId.empty()) h.modelId = ioPropertyString(platform, CFSTR("model"));
    IOObjectRelease(platform);
  }

  CFURLRef sv = CFURLCreateWithFileSystemPath(
      kCFAllocatorDefault, CFSTR("/System/Library/CoreServices/SystemVersion.plist"),
      kCFURLPOSIXPathStyle, false);
  CFReadStreamRef stream = sv ? CFReadStreamCreateWithFile(kCFAllocatorDefault, sv) : nullptr;
  cfRelease(sv);
  if (stream && CFReadStreamOpen(stream)) {
    CFPropertyListRef plist = CFPropertyListCreateWithStream(
        kCFAllocatorDefault, stream, 0, kCFPropertyListImmutable, nullptr, nullptr);
    if (plist && CFGetTypeID(plist) == CFDictionaryGetTypeID()) {
      auto d = static_cast<CFDictionaryRef>(plist);
      h.osName = plistString(d, CFSTR("ProductName"));
      h.osVersion = plistString(d, CFSTR("ProductUserVisibleVersion"));
      if (h.osVersion.empty()) h.osVersion = plistString(d, CFSTR("ProductVersion"));
      h.osBuild = plistString(d, CFSTR("ProductBuildVersion"));
    }
    cfRelease(plist);
    CFReadStreamClose(stream);
  }
  cfRelease(stream);
  if (h.osVersion.empty()) h.osVersion = sysctlString("kern.osproductversion");
  if (h.osBuild.empty()) h.osBuild = sysctlString("kern.osversion");
  if (h.osName.empty()) h.osName = "macOS";
  return h;
}

VolumeInfo volumeInfo(const std::string& path) {
  VolumeInfo v;
  const char* p = path.empty() ? "/" : path.c_str();
  v.mountPoint = p;
  fillUrlCapacities(p, v);
  fillDiskArbitration(p, v);
  if (v.fileSystem == "apfs") v.fileSystem = "APFS";
  scrapeFromBsd(v.bsdName, v);

  if (v.importantAvailableBytes == 0) fillUrlCapacities("/System/Volumes/Data", v);
  VolumeInfo data;
  fillUrlCapacities("/System/Volumes/Data", data);
  fillDiskArbitration("/System/Volumes/Data", data);
  v.encrypted = v.encrypted || data.encrypted;
  v.writable = v.writable || data.writable;
  if (v.importantAvailableBytes == 0) v.importantAvailableBytes = data.importantAvailableBytes;
  if (v.availableBytes == 0) v.availableBytes = data.availableBytes;
  if (v.totalBytes == 0) v.totalBytes = data.totalBytes;

  if (v.importantAvailableBytes > v.availableBytes)
    v.purgeableBytes = v.importantAvailableBytes - v.availableBytes;

  if (!v.solidState && (v.protocol == "Apple Fabric" || v.mediumType == "Solid State" ||
                        v.deviceModel.find("SSD") != std::string::npos))
    v.solidState = true;
  if (v.trim == "true") v.trim = "Yes";
  if (v.trim == "false") v.trim = "No";
  return v;
}

std::vector<std::pair<std::string, std::string>> machineFacts(const HostInfo& h) {
  std::vector<std::pair<std::string, std::string>> out;
  addFact(out, "Chip", h.chip);
  addFact(out, "Cores", formatCoreSummary(h.physicalCpus, h.performanceCpus, h.efficiencyCpus));
  if (h.memoryBytes)
    addFact(out, "Memory", dcmm::formatBytes(h.memoryBytes));
  addFact(out, "macOS", formatOsLine(h));
  addFact(out, "Model", h.modelId);
  addFact(out, "Serial Number", h.serial);
  if (!h.hostname.empty() && h.hostname != h.computerName) addFact(out, "Hostname", h.hostname);
  return out;
}

std::vector<std::pair<std::string, std::string>> storageFacts(const VolumeInfo& v) {
  std::vector<std::pair<std::string, std::string>> out;
  addFact(out, "Kind", formatStorageKind(v));
  addFact(out, "Drive", v.deviceModel);
  addFact(out, "Protocol", v.protocol);
  addFact(out, "File system", v.fileSystem);
  addFact(out, "Device", v.bsdName);
  addFact(out, "Mount", v.mountPoint);
  if (v.mediaSizeBytes && v.mediaSizeBytes != v.totalBytes)
    addFact(out, "Container", dcmm::formatBytes(v.mediaSizeBytes));
  if (v.purgeableBytes) addFact(out, "Purgeable", dcmm::formatBytes(v.purgeableBytes));
  addFact(out, "FileVault", yesNo(v.encrypted));
  addFact(out, "Writable", yesNo(v.writable));
  if (v.blockSize) addFact(out, "Block size", std::to_string(v.blockSize) + " bytes");
  addFact(out, "SMART", v.smartStatus);
  addFact(out, "TRIM", v.trim);
  return out;
}

}  // namespace ui

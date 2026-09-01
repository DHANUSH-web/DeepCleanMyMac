#import "ui/UninstallerView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCUninstallerView () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

@implementation DCUninstallerView {
  dcmm::Engine _engine;
  struct AppRow {
    dcmm::InstalledApp app;
    bool selected = false;
  };
  std::vector<AppRow> _apps;
  NSButton* _reload;
  NSButton* _selAll;
  NSButton* _remove;
  NSTextField* _status;
  NSTableView* _appsTable;
  BOOL _listed;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Uninstaller", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Uninstaller)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _reload = DCPushButton(@"Refresh", self, @selector(reloadApps));
    _selAll = DCPushButton(@"Select All", self, @selector(toggleAll));
    _remove = DCDestructiveButton(@"Uninstall", self, @selector(uninstall));
    _remove.enabled = NO;
    NSStackView* actions = DCTrailingButtons(@[ _selAll, _reload, _remove ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(
        @"Check one or more apps to uninstall. Leftover files are removed with the app.");
    [page addArrangedSubview:_status];

    _appsTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_appsTable);
    _appsTable.dataSource = self;
    _appsTable.delegate = self;
    _appsTable.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    _appsTable.rowHeight = 47;
    DCAttachTableMenu(_appsTable, self);
    NSTableColumn* check = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    check.width = 24;
    check.minWidth = 24;
    check.maxWidth = 32;
    check.title = @"";
    [_appsTable addTableColumn:check];
    NSTableColumn* n = [[NSTableColumn alloc] initWithIdentifier:@"app"];
    n.title = @"Application";
    [_appsTable addTableColumn:n];
    NSTableColumn* s = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    s.title = @"Size";
    s.width = 80;
    [_appsTable addTableColumn:s];

    DCStackExpand(page, DCWrapTable(_appsTable));
    [self refreshUninstall];
  }
  return self;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  if (!self.window || _listed) return;
  _listed = YES;
  [self reloadApps];
}

- (void)reloadApps {
  _status.stringValue = @"Listing applications…";
  __weak DCUninstallerView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCUninstallerView* strong = weakSelf;
    if (!strong) return;
    auto apps = strong->_engine.listApps();
    dispatch_async(dispatch_get_main_queue(), ^{
      DCUninstallerView* s = weakSelf;
      if (!s) return;
      s->_apps.clear();
      s->_apps.reserve(apps.size());
      for (auto& a : apps) s->_apps.push_back({std::move(a), false});
      [s->_appsTable reloadData];
      s->_status.stringValue = [NSString stringWithFormat:@"%lu apps", (unsigned long)s->_apps.size()];
      [s refreshUninstall];
    });
  });
}

- (std::vector<dcmm::InstalledApp>)checkedApps {
  std::vector<dcmm::InstalledApp> out;
  for (auto& row : _apps)
    if (row.selected) out.push_back(row.app);
  return out;
}

- (BOOL)allAppsSelected {
  if (_apps.empty()) return NO;
  for (const auto& row : _apps)
    if (!row.selected) return NO;
  return YES;
}

- (void)refreshUninstall {
  std::size_t n = 0;
  for (const auto& row : _apps)
    if (row.selected) ++n;
  _remove.enabled = n > 0;
  if (n > 1)
    _remove.title = [NSString stringWithFormat:@"Uninstall %lu Apps", (unsigned long)n];
  else
    _remove.title = @"Uninstall";
  _selAll.title = [self allAppsSelected] ? @"Unselect All" : @"Select All";
  _selAll.enabled = !_apps.empty();
}

- (void)toggleAll {
  BOOL on = ![self allAppsSelected];
  for (auto& row : _apps) row.selected = on;
  [_appsTable reloadData];
  [self refreshUninstall];
}

- (void)uninstall {
  auto apps = [self checkedApps];
  for (auto& app : apps) _engine.attachLeftovers(app);
  auto paths = ui::uninstallPaths(apps);
  if (paths.empty()) {
    DCInformNothingToClean(@"Check one or more applications in the list first.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  uint64_t bytes = ui::uninstallBytes(apps);
  if (!DCConfirmClean(list, bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applyClean(_engine, paths, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
  } else {
    NSString* msg = DCNS(ui::cleanFinishedDetail(mode, r));
    _status.stringValue = msg;
    DCInformCleaned(@"Uninstall finished", msg);
  }
  [self reloadApps];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_apps.size();
}

- (CGFloat)tableView:(NSTableView*)tv heightOfRow:(NSInteger)row {
  return 47;
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto& a = _apps[(size_t)row];
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(togApp:)];
    b.state = a.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  if ([col.identifier isEqualToString:@"app"]) {
    t.stringValue = DCNS(a.app.name);
    t.toolTip = DCNS(a.app.appPath);
    NSImageView* icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    NSImage* img = [[[NSWorkspace sharedWorkspace] iconForFile:DCNS(a.app.appPath)] copy];
    img.size = NSMakeSize(35, 35);
    icon.image = img;
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    [icon.widthAnchor constraintEqualToConstant:35].active = YES;
    [icon.heightAnchor constraintEqualToConstant:35].active = YES;
    return DCCenteredIconTextCell(icon, t);
  }
  t.stringValue = DCNS(dcmm::formatBytes(a.app.appBytes));
  t.alignment = NSTextAlignmentRight;
  t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  return DCCenteredTextCell(t);
}

- (void)togApp:(NSButton*)s {
  if (s.tag < 0 || s.tag >= (NSInteger)_apps.size()) return;
  _apps[(size_t)s.tag].selected = s.state == NSControlStateValueOn;
  [self refreshUninstall];
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSInteger row = _appsTable.clickedRow;
  if (row < 0 || row >= (NSInteger)_apps.size()) return;
  auto& a = _apps[(size_t)row];
  DCAddPathMenuItems(menu, DCNS(a.app.appPath));
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* sel = [[NSMenuItem alloc] initWithTitle:a.selected ? @"Unselect" : @"Select"
                                               action:@selector(ctxToggleApp:)
                                        keyEquivalent:@""];
  sel.target = self;
  sel.tag = row;
  [menu addItem:sel];
}

- (void)ctxToggleApp:(NSMenuItem*)sender {
  if (sender.tag < 0 || sender.tag >= (NSInteger)_apps.size()) return;
  _apps[(size_t)sender.tag].selected = !_apps[(size_t)sender.tag].selected;
  [_appsTable reloadData];
  [self refreshUninstall];
}

@end

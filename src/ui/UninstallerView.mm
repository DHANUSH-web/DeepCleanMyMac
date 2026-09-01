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
  NSInteger _sel;
  NSButton* _reload;
  NSButton* _selAll;
  NSButton* _remove;
  NSTextField* _status;
  NSTableView* _appsTable;
  NSTableView* _leftTable;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _sel = -1;
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
        @"Check one or more apps to uninstall. Related files are optional — check only what you want removed.");
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

    _leftTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_leftTable);
    _leftTable.dataSource = self;
    _leftTable.delegate = self;
    DCAttachTableMenu(_leftTable, self);
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 24;
    c0.minWidth = 24;
    c0.maxWidth = 32;
    c0.title = @"";
    [_leftTable addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"leftover"];
    c1.title = @"Related Files";
    [_leftTable addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"lsize"];
    c2.title = @"Size";
    c2.width = 80;
    [_leftTable addTableColumn:c2];

    NSSplitView* split = [[NSSplitView alloc] initWithFrame:NSZeroRect];
    split.vertical = YES;
    split.dividerStyle = NSSplitViewDividerStyleThin;
    split.autosaveName = @"DCUninstallerSplit";
    [split addSubview:DCWrapTable(_appsTable)];
    [split addSubview:DCWrapTable(_leftTable)];
    DCStackExpand(page, split);
    [self refreshUninstall];
  }
  return self;
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
      s->_sel = -1;
      [s->_appsTable reloadData];
      [s->_leftTable reloadData];
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

- (void)tableViewSelectionDidChange:(NSNotification*)n {
  if (n.object != _appsTable) return;
  _sel = _appsTable.selectedRow;
  if (_sel >= 0 && _sel < (NSInteger)_apps.size())
    _engine.attachLeftovers(_apps[(size_t)_sel].app);
  [_leftTable reloadData];
}

- (void)uninstall {
  auto apps = [self checkedApps];
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
  if (tv == _appsTable) return (NSInteger)_apps.size();
  if (_sel < 0 || _sel >= (NSInteger)_apps.size()) return 0;
  return (NSInteger)_apps[(size_t)_sel].app.leftovers.size();
}

- (CGFloat)tableView:(NSTableView*)tv heightOfRow:(NSInteger)row {
  if (tv == _appsTable) return 47;
  return tv.rowHeight;
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  if (tv == _appsTable) {
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
  auto& it = _apps[(size_t)_sel].app.leftovers[(size_t)row];
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.state = it.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"leftover"]) {
    t.stringValue = DCNS(it.path);
    t.toolTip = t.stringValue;
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(it.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

- (void)togApp:(NSButton*)s {
  if (s.tag < 0 || s.tag >= (NSInteger)_apps.size()) return;
  _apps[(size_t)s.tag].selected = s.state == NSControlStateValueOn;
  [self refreshUninstall];
}

- (void)tog:(NSButton*)s {
  if (_sel < 0) return;
  auto& it = _apps[(size_t)_sel].app.leftovers[(size_t)s.tag];
  it.selected = s.state == NSControlStateValueOn;
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  if (menu == _appsTable.menu) {
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
    return;
  }
  NSInteger row = _leftTable.clickedRow;
  if (_sel < 0 || row < 0) return;
  auto& leftovers = _apps[(size_t)_sel].app.leftovers;
  if (row >= (NSInteger)leftovers.size()) return;
  auto& it = leftovers[(size_t)row];
  DCAddPathMenuItems(menu, DCNS(it.path));
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* sel = [[NSMenuItem alloc] initWithTitle:it.selected ? @"Unselect" : @"Select"
                                               action:@selector(ctxToggleSelect:)
                                        keyEquivalent:@""];
  sel.target = self;
  sel.tag = row;
  [menu addItem:sel];
  NSMenuItem* trash = [[NSMenuItem alloc] initWithTitle:DCNS(ui::cleanMenuTitle(DCCleanPref()))
                                                 action:@selector(ctxTrashLeftover:)
                                          keyEquivalent:@""];
  trash.target = self;
  trash.tag = row;
  [menu addItem:trash];
}

- (void)ctxToggleApp:(NSMenuItem*)sender {
  if (sender.tag < 0 || sender.tag >= (NSInteger)_apps.size()) return;
  _apps[(size_t)sender.tag].selected = !_apps[(size_t)sender.tag].selected;
  [_appsTable reloadData];
  [self refreshUninstall];
}

- (void)ctxToggleSelect:(NSMenuItem*)sender {
  if (_sel < 0) return;
  auto& it = _apps[(size_t)_sel].app.leftovers[(size_t)sender.tag];
  it.selected = !it.selected;
  [_leftTable reloadData];
}

- (void)ctxTrashLeftover:(NSMenuItem*)sender {
  if (_sel < 0) return;
  auto& it = _apps[(size_t)_sel].app.leftovers[(size_t)sender.tag];
  if (!DCConfirmClean(@[ DCNS(it.path) ], it.bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applyClean(_engine, {it.path}, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    return;
  }
  DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
  [self reloadApps];
}

@end

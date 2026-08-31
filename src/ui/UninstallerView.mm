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
  std::vector<dcmm::InstalledApp> _apps;
  NSInteger _sel;
  NSButton* _reload;
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
    _remove = DCDestructiveButton(@"Uninstall", self, @selector(uninstall));
    _remove.enabled = NO;
    NSStackView* actions = DCTrailingButtons(@[ _reload, _remove ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(
        @"Select an app to uninstall. Related files are optional — check only what you want removed.");
    [page addArrangedSubview:_status];

    _appsTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_appsTable);
    _appsTable.dataSource = self;
    _appsTable.delegate = self;
    DCAttachTableMenu(_appsTable, self);
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
      s->_apps = std::move(apps);
      s->_sel = -1;
      [s->_appsTable reloadData];
      [s->_leftTable reloadData];
      s->_status.stringValue = [NSString stringWithFormat:@"%lu apps", (unsigned long)s->_apps.size()];
    });
  });
}

- (void)tableViewSelectionDidChange:(NSNotification*)n {
  if (n.object != _appsTable) return;
  _sel = _appsTable.selectedRow;
  if (_sel >= 0 && _sel < (NSInteger)_apps.size()) {
    _engine.attachLeftovers(_apps[(size_t)_sel]);
    _remove.enabled = YES;
  } else {
    _remove.enabled = NO;
  }
  [_leftTable reloadData];
}

- (void)uninstall {
  if (_sel < 0 || _sel >= (NSInteger)_apps.size()) return;
  auto& app = _apps[(size_t)_sel];
  auto paths = ui::uninstallPaths(app);
  if (paths.empty()) {
    DCInformNothingToClean(@"Select an application in the list first.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  uint64_t bytes = ui::uninstallBytes(app);
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
  return (NSInteger)_apps[(size_t)_sel].leftovers.size();
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  if (tv == _appsTable) {
    auto& a = _apps[(size_t)row];
    NSTextField* t = DCLabel(@"");
    if ([col.identifier isEqualToString:@"app"])
      t.stringValue = DCNS(a.name);
    else {
      t.stringValue = DCNS(dcmm::formatBytes(a.appBytes));
      t.alignment = NSTextAlignmentRight;
      t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
    }
    return DCCenteredTextCell(t);
  }
  auto& it = _apps[(size_t)_sel].leftovers[(size_t)row];
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

- (void)tog:(NSButton*)s {
  if (_sel < 0) return;
  auto& it = _apps[(size_t)_sel].leftovers[(size_t)s.tag];
  it.selected = s.state == NSControlStateValueOn;
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  if (menu == _appsTable.menu) {
    NSInteger row = _appsTable.clickedRow;
    if (row < 0 || row >= (NSInteger)_apps.size()) return;
    DCAddPathMenuItems(menu, DCNS(_apps[(size_t)row].appPath));
    return;
  }
  NSInteger row = _leftTable.clickedRow;
  if (_sel < 0 || row < 0) return;
  auto& leftovers = _apps[(size_t)_sel].leftovers;
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

- (void)ctxToggleSelect:(NSMenuItem*)sender {
  if (_sel < 0) return;
  auto& it = _apps[(size_t)_sel].leftovers[(size_t)sender.tag];
  it.selected = !it.selected;
  [_leftTable reloadData];
}

- (void)ctxTrashLeftover:(NSMenuItem*)sender {
  if (_sel < 0) return;
  auto& it = _apps[(size_t)_sel].leftovers[(size_t)sender.tag];
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

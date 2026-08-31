#import "ui/ResultsView.h"
#import "ui/Theme.h"

#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "Modules.h"
#include "dcmm/dcmm.hpp"

#include <vector>

namespace {
struct FlatRow {
  bool group = false;
  int g = -1;
  int i = -1;
};
}  // namespace

@interface DCResultsView () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

@implementation DCResultsView {
  DCResultsMode _mode;
  dcmm::Engine _engine;
  dcmm::ScanReport _report;
  std::vector<FlatRow> _rows;
  NSInteger _state;

  NSButton* _scanBtn;
  NSButton* _cleanBtn;
  NSButton* _selAll;
  NSProgressIndicator* _spin;
  NSTextField* _status;
  NSTableView* _table;
}

- (instancetype)initWithMode:(DCResultsMode)mode {
  NSString* title = @"Smart Scan";
  NSString* sub = @"Recommended caches and logs. Clean whole groups, not individual files.";
  if (mode == DCResultsModePrivacy) {
    title = @"Privacy";
    sub = @"Browser caches and tracking leftovers. Cookies stay off unless you opt in.";
  } else if (mode == DCResultsModeJunk) {
    title = @"System Wide Scan";
    sub = @"Item-by-item scan — review before cleaning. Not everything here is safe to remove";
  }
  return [self initWithMode:mode title:title subtitle:sub];
}

- (instancetype)initWithMode:(DCResultsMode)mode title:(NSString*)title subtitle:(NSString*)subtitle {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _mode = mode;
    _state = 0;

    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(title, subtitle);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);

    _scanBtn = DCDefaultButton(@"Scan", self, @selector(startScan));
    _cleanBtn = DCDestructiveButton(@"Move to Trash", self, @selector(cleanSelected));
    _cleanBtn.hidden = YES;
    _selAll = DCPushButton(@"Select All", self, @selector(toggleAll));
    _selAll.hidden = YES;
    NSStackView* actions = DCTrailingButtons(@[ _selAll, _cleanBtn, _scanBtn ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);

    _spin = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    _spin.style = NSProgressIndicatorStyleSpinning;
    _spin.displayedWhenStopped = NO;
    _spin.controlSize = NSControlSizeSmall;
    _status = DCCaptionLabel(@"Ready when you are.");
    NSStackView* statusRow = [NSStackView stackViewWithViews:@[ _spin, _status ]];
    statusRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    statusRow.alignment = NSLayoutAttributeCenterY;
    statusRow.spacing = 8;
    [page addArrangedSubview:statusRow];

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_table);
    _table.dataSource = self;
    _table.delegate = self;
    DCAttachTableMenu(_table, self);

    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 24;
    c0.minWidth = 24;
    c0.maxWidth = 32;
    c0.title = @"";
    [_table addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"Item";
    c1.minWidth = 160;
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"files"];
    c2.title = @"Files";
    c2.width = 72;
    [_table addTableColumn:c2];
    NSTableColumn* c3 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c3.title = @"Size";
    c3.width = 90;
    [_table addTableColumn:c3];

    DCStackExpand(page, DCWrapTable(_table));
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshCleanTitle)
                                                 name:DCSettingsDidChangeNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)rebuildRows {
  _rows.clear();
  for (int g = 0; g < (int)_report.groups.size(); ++g) {
    if (_mode != DCResultsModeSmart) _rows.push_back({true, g, -1});
    for (int i = 0; i < (int)_report.groups[g].items.size(); ++i) _rows.push_back({false, g, i});
  }
}

- (void)startScan {
  if (_state == 1) {
    _engine.cancel();
    return;
  }
  _state = 1;
  _scanBtn.title = @"Cancel";
  _scanBtn.keyEquivalent = @".";
  _scanBtn.keyEquivalentModifierMask = NSEventModifierFlagCommand;
  _cleanBtn.hidden = YES;
  _selAll.hidden = YES;
  [_spin startAnimation:nil];
  _status.stringValue = @"Scanning…";
  __weak DCResultsView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCResultsView* strong = weakSelf;
    if (!strong) return;
    dcmm::ProgressFn cb = [weakSelf](const std::string& p, uint64_t vis, uint64_t) {
      dispatch_async(dispatch_get_main_queue(), ^{
        DCResultsView* s = weakSelf;
        if (!s) return;
        s->_status.stringValue =
            [NSString stringWithFormat:@"Scanning %@ — %llu items", DCNS(dcmm::displayName(p)),
                                       (unsigned long long)vis];
      });
    };
    ui::Module page = ui::Module::SystemJunk;
    if (strong->_mode == DCResultsModePrivacy)
      page = ui::Module::Privacy;
    else if (strong->_mode == DCResultsModeSmart)
      page = ui::Module::SmartScan;
    auto r = ui::runScan(strong->_engine, page, cb);
    dispatch_async(dispatch_get_main_queue(), ^{
      DCResultsView* s = weakSelf;
      if (s) [s finishWithReport:r];
    });
  });
}

- (void)finishWithReport:(const dcmm::ScanReport&)r {
  _report = r;
  [self rebuildRows];
  _state = 2;
  [_spin stopAnimation:nil];
  _scanBtn.title = @"Scan Again";
  _scanBtn.keyEquivalent = @"\r";
  _scanBtn.keyEquivalentModifierMask = 0;
  _cleanBtn.hidden = NO;
  _selAll.hidden = NO;
  NSString* verb = _mode == DCResultsModeSmart ? @"Recommended" : @"Found";
  _status.stringValue =
      [NSString stringWithFormat:@"%@ %@ in %lu groups (%.1f s)", verb,
                                 DCNS(dcmm::formatBytes(_report.totalBytes())),
                                 (unsigned long)_report.groups.size(), _report.elapsedMs / 1000.0];
  [_table reloadData];
  [self refreshCleanTitle];
  [self refreshSelectAllTitle];
}

- (BOOL)allItemsSelected {
  return ui::allScanItemsSelected(_report) ? YES : NO;
}

- (void)refreshSelectAllTitle {
  _selAll.title = [self allItemsSelected] ? @"Unselect All" : @"Select All";
}

- (void)refreshCleanTitle {
  uint64_t b = _report.selectedBytes();
  _cleanBtn.title = DCNS(ui::cleanButtonTitleWithBytes(DCCleanPref(), b));
  _cleanBtn.enabled = b > 0;
}

- (void)toggleAll {
  ui::setAllScanItemsSelected(_report, ![self allItemsSelected]);
  [_table reloadData];
  [self refreshCleanTitle];
  [self refreshSelectAllTitle];
}

- (void)cleanSelected {
  auto paths = _report.selectedPaths();
  if (paths.empty()) {
    DCInformNothingToClean(@"Select items in the list first. Nothing was deleted.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray arrayWithCapacity:paths.size()];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  if (!DCConfirmClean(list, _report.selectedBytes())) return;
  _cleanBtn.enabled = NO;
  const auto mode = DCCleanPref();
  __weak DCResultsView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCResultsView* strong = weakSelf;
    if (!strong) return;
    auto result = ui::applyClean(strong->_engine, paths, mode);
    dispatch_async(dispatch_get_main_queue(), ^{
      DCResultsView* s = weakSelf;
      if (!s) return;
      if (result.trashedItems == 0 && result.trashedBytes == 0) {
        DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
      } else {
        DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, result)));
      }
      [s startScan];
    });
  });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_rows.size();
}

- (BOOL)tableView:(NSTableView*)tableView isGroupRow:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)_rows.size()) return NO;
  return _rows[(size_t)row].group;
}

- (NSView*)tableView:(NSTableView*)tableView
    viewForTableColumn:(NSTableColumn*)column
                   row:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)_rows.size()) return nil;
  FlatRow fr = _rows[(size_t)row];
  NSString* ident = column.identifier;
  if (fr.group) {
    const auto& g = _report.groups[fr.g];
    NSTextField* t = DCLabel(@"");
    t.font = [NSFont preferredFontForTextStyle:NSFontTextStyleHeadline options:@{}];
    if (!column || [ident isEqualToString:@"name"]) {
      t.stringValue = [NSString stringWithFormat:@"%@ — %@", DCNS(g.title),
                                                 DCNS(dcmm::formatBytes(g.totalBytes()))];
      t.toolTip = DCNS(g.subtitle);
      if (g.id == "native_system") return DCCenteredDangerTextCell(t);
    } else {
      t.stringValue = @"";
    }
    return DCCenteredTextCell(t);
  }
  auto& it = _report.groups[fr.g].items[fr.i];
  const bool native = _report.groups[fr.g].id == "native_system";
  if ([ident isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(checkToggled:)];
    b.state = it.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([ident isEqualToString:@"name"]) {
    if (_mode == DCResultsModeSmart) {
      const auto& g = _report.groups[fr.g];
      t.stringValue = g.id == "installers" ? DCNS(it.displayName) : DCNS(g.title);
      t.toolTip = [NSString stringWithFormat:@"%s\n%s", g.subtitle.c_str(), it.path.c_str()];
    } else {
      t.stringValue = DCNS(it.displayName);
      t.toolTip = DCNS(it.path);
      if (native) return DCCenteredDangerTextCell(t);
    }
  } else if ([ident isEqualToString:@"files"]) {
    t.stringValue = [NSString stringWithFormat:@"%llu", (unsigned long long)it.fileCount];
    t.alignment = NSTextAlignmentRight;
  } else if ([ident isEqualToString:@"size"]) {
    t.stringValue = DCNS(dcmm::formatBytes(it.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

- (void)checkToggled:(NSButton*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) return;
  _report.groups[fr.g].items[fr.i].selected = sender.state == NSControlStateValueOn;
  [self refreshCleanTitle];
  [self refreshSelectAllTitle];
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSInteger row = _table.clickedRow;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) {
    NSMenuItem* all = [[NSMenuItem alloc] initWithTitle:@"Select Group"
                                                 action:@selector(ctxSelectGroup:)
                                          keyEquivalent:@""];
    all.target = self;
    all.tag = row;
    [menu addItem:all];
    NSMenuItem* none = [[NSMenuItem alloc] initWithTitle:@"Unselect Group"
                                                  action:@selector(ctxUnselectGroup:)
                                           keyEquivalent:@""];
    none.target = self;
    none.tag = row;
    [menu addItem:none];
    return;
  }
  const auto& it = _report.groups[fr.g].items[fr.i];
  DCAddPathMenuItems(menu, DCNS(it.path));
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* sel = [[NSMenuItem alloc] initWithTitle:it.selected ? @"Unselect" : @"Select"
                                               action:@selector(ctxToggleSelect:)
                                        keyEquivalent:@""];
  sel.target = self;
  sel.tag = row;
  [menu addItem:sel];
  NSMenuItem* trash = [[NSMenuItem alloc] initWithTitle:DCNS(ui::cleanMenuTitle(DCCleanPref()))
                                                 action:@selector(ctxTrashRow:)
                                          keyEquivalent:@""];
  trash.target = self;
  trash.tag = row;
  [menu addItem:trash];
}

- (void)ctxSelectGroup:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  int g = _rows[(size_t)row].g;
  for (auto& it : _report.groups[g].items) it.selected = true;
  [_table reloadData];
  [self refreshCleanTitle];
  [self refreshSelectAllTitle];
}

- (void)ctxUnselectGroup:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  int g = _rows[(size_t)row].g;
  for (auto& it : _report.groups[g].items) it.selected = false;
  [_table reloadData];
  [self refreshCleanTitle];
  [self refreshSelectAllTitle];
}

- (void)ctxToggleSelect:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) return;
  auto& it = _report.groups[fr.g].items[fr.i];
  it.selected = !it.selected;
  [_table reloadData];
  [self refreshCleanTitle];
  [self refreshSelectAllTitle];
}

- (void)ctxTrashRow:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) return;
  auto& it = _report.groups[fr.g].items[fr.i];
  NSArray<NSString*>* list = @[ DCNS(it.path) ];
  if (!DCConfirmClean(list, it.bytes)) return;
  const auto mode = DCCleanPref();
  auto result = ui::applyClean(_engine, {it.path}, mode);
  if (result.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    return;
  }
  DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, result)));
  [self startScan];
}

@end

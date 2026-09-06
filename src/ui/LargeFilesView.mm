#import "ui/LargeFilesView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCLargeFilesView () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

namespace {
struct FlatRow {
  bool group = false;
  int g = -1;
  int i = -1;
};
}  // namespace

@implementation DCLargeFilesView {
  dcmm::Engine _engine;
  std::vector<ui::LargeFileGroup> _groups;
  std::vector<FlatRow> _rows;
  NSButton* _scan;
  NSButton* _clean;
  NSTextField* _status;
  NSTableView* _table;
  uint64_t _job;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Large Files", [NSString stringWithUTF8String:ui::subtitle(ui::Module::LargeFiles)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _scan = DCDefaultButton(@"Scan", self, @selector(startScan));
    _clean = DCDestructiveButton(@"Move to Trash", self, @selector(cleanSelected));
    _clean.hidden = YES;
    NSStackView* actions = DCTrailingButtons(@[ _clean, _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(
        @"Looks in Desktop, Documents, Downloads, Pictures, Movies, Music, iCloud Drive, and Bin for files of 50 MB or more.");
    [page addArrangedSubview:_status];

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
    c1.title = @"File";
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 100;
    [_table addTableColumn:c2];
    DCStackExpand(page, DCWrapTable(_table));
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshClean)
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
  for (int g = 0; g < (int)_groups.size(); ++g) {
    _rows.push_back({true, g, -1});
    for (int i = 0; i < (int)_groups[(size_t)g].files.size(); ++i) _rows.push_back({false, g, i});
  }
}

- (void)startScan {
  if (!_scan.enabled) return;
  _status.stringValue = @"Scanning…";
  _scan.enabled = NO;
  _clean.hidden = YES;
  __weak DCLargeFilesView* weakSelf = self;
  __block std::vector<dcmm::LargeFile> files;
  DCRunBackground(&_job, ^{
    DCLargeFilesView* strong = weakSelf;
    if (!strong) return;
    files = strong->_engine.findLargeFiles(ui::largeFileOptions());
  }, ^{
    DCLargeFilesView* s = weakSelf;
    if (!s) return;
    s->_groups = ui::groupLargeFiles(files);
    [s rebuildRows];
    [s->_table reloadData];
    s->_scan.enabled = YES;
    std::size_t n = 0;
    for (const auto& g : s->_groups) n += g.files.size();
    s->_status.stringValue =
        [NSString stringWithFormat:@"%lu files of 50 MB or more in %lu folders", (unsigned long)n,
                                   (unsigned long)s->_groups.size()];
    [s refreshClean];
  });
}

- (void)refreshClean {
  auto paths = ui::selectedLargeFilePaths(_groups);
  uint64_t b = ui::selectedLargeFileBytes(_groups);
  _clean.hidden = paths.empty();
  _clean.title = DCNS(ui::cleanButtonTitleWithBytes(DCCleanPref(), paths.empty() ? 0 : b));
}

- (void)cleanSelected {
  auto paths = ui::selectedLargeFilePaths(_groups);
  if (paths.empty()) {
    DCInformNothingToClean(@"Select files in the list first. Nothing was deleted.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray arrayWithCapacity:paths.size()];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  uint64_t bytes = ui::selectedLargeFileBytes(_groups);
  if (!DCConfirmClean(list, bytes)) return;
  const auto mode = DCCleanPref();
  _scan.enabled = NO;
  _clean.hidden = YES;
  __weak DCLargeFilesView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCLargeFilesView* strong = weakSelf;
    if (!strong) return;
    r = ui::applyClean(strong->_engine, paths, mode);
  }, ^{
    DCLargeFilesView* s = weakSelf;
    if (!s) return;
    s->_scan.enabled = YES;
    if (r.trashedItems == 0) {
      DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    } else {
      NSString* msg = DCNS(ui::cleanFinishedDetail(mode, r));
      s->_status.stringValue = msg;
      DCInformCleaned(@"Clean finished", msg);
    }
    [s startScan];
  });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_rows.size();
}

- (BOOL)tableView:(NSTableView*)tableView isGroupRow:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)_rows.size()) return NO;
  return _rows[(size_t)row].group;
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)_rows.size()) return nil;
  FlatRow fr = _rows[(size_t)row];
  NSString* ident = col.identifier;
  if (fr.group) {
    const auto& g = _groups[(size_t)fr.g];
    auto groupCheck = ^{
      NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
      b.allowsMixedState = YES;
      switch (ui::largeFileGroupCheck(g)) {
        case ui::GroupCheck::On:
          b.state = NSControlStateValueOn;
          break;
        case ui::GroupCheck::Mixed:
          b.state = NSControlStateValueMixed;
          break;
        case ui::GroupCheck::Off:
          b.state = NSControlStateValueOff;
          break;
      }
      b.tag = row;
      b.toolTip = @"Select or unselect every file in this folder";
      return b;
    };
    NSTextField* t = DCLabel(@"");
    t.font = [NSFont preferredFontForTextStyle:NSFontTextStyleHeadline options:@{}];
    t.stringValue = [NSString stringWithFormat:@"%@ — %@", DCNS(g.title),
                                               DCNS(dcmm::formatBytes(g.totalBytes()))];
    if (!col) {
      NSStackView* rowView = [NSStackView stackViewWithViews:@[ groupCheck(), t ]];
      rowView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
      rowView.alignment = NSLayoutAttributeCenterY;
      rowView.spacing = 6;
      return DCCenteredFillCell(rowView);
    }
    if ([ident isEqualToString:@"check"]) return DCCenteredCheckCell(groupCheck());
    if ([ident isEqualToString:@"name"]) return DCCenteredTextCell(t);
    t.stringValue = @"";
    return DCCenteredTextCell(t);
  }
  auto& f = _groups[(size_t)fr.g].files[(size_t)fr.i];
  if ([ident isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.state = f.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([ident isEqualToString:@"name"]) {
    t.stringValue = DCNS(dcmm::displayName(f.path));
    t.toolTip = DCNS(f.path);
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(f.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

- (void)tog:(NSButton*)s {
  NSInteger row = s.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) {
    ui::setLargeFileGroupSelected(_groups[(size_t)fr.g],
                                  ui::largeFileGroupCheck(_groups[(size_t)fr.g]) != ui::GroupCheck::On);
  } else {
    _groups[(size_t)fr.g].files[(size_t)fr.i].selected = s.state == NSControlStateValueOn;
  }
  [_table reloadData];
  [self refreshClean];
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
  auto& f = _groups[(size_t)fr.g].files[(size_t)fr.i];
  DCAddPathMenuItems(menu, DCNS(f.path));
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* sel = [[NSMenuItem alloc] initWithTitle:f.selected ? @"Unselect" : @"Select"
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
  ui::setLargeFileGroupSelected(_groups[(size_t)_rows[(size_t)row].g], true);
  [_table reloadData];
  [self refreshClean];
}

- (void)ctxUnselectGroup:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  ui::setLargeFileGroupSelected(_groups[(size_t)_rows[(size_t)row].g], false);
  [_table reloadData];
  [self refreshClean];
}

- (void)ctxToggleSelect:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) return;
  auto& f = _groups[(size_t)fr.g].files[(size_t)fr.i];
  f.selected = !f.selected;
  [_table reloadData];
  [self refreshClean];
}

- (void)ctxTrashRow:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) return;
  auto& f = _groups[(size_t)fr.g].files[(size_t)fr.i];
  if (!DCConfirmClean(@[ DCNS(f.path) ], f.bytes)) return;
  const auto mode = DCCleanPref();
  std::string path = f.path;
  _scan.enabled = NO;
  __weak DCLargeFilesView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCLargeFilesView* strong = weakSelf;
    if (!strong) return;
    r = ui::applyClean(strong->_engine, {path}, mode);
  }, ^{
    DCLargeFilesView* s = weakSelf;
    if (!s) return;
    s->_scan.enabled = YES;
    if (r.trashedItems == 0) {
      DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
      return;
    }
    DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
    [s startScan];
  });
}

@end

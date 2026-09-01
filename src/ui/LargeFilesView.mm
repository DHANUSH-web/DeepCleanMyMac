#import "ui/LargeFilesView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCLargeFilesView () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

@implementation DCLargeFilesView {
  dcmm::Engine _engine;
  std::vector<dcmm::LargeFile> _files;
  NSButton* _scan;
  NSButton* _clean;
  NSTextField* _status;
  NSTableView* _table;
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
    _status = DCCaptionLabel(@"Looks in Desktop, Documents, Downloads, and Movies for files of 50 MB or more.");
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

- (void)startScan {
  _status.stringValue = @"Scanning…";
  _scan.enabled = NO;
  __weak DCLargeFilesView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCLargeFilesView* strong = weakSelf;
    if (!strong) return;
    auto files = strong->_engine.findLargeFiles(ui::largeFileOptions());
    dispatch_async(dispatch_get_main_queue(), ^{
      DCLargeFilesView* s = weakSelf;
      if (!s) return;
      s->_files = std::move(files);
      [s->_table reloadData];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu files of 50 MB or more", (unsigned long)s->_files.size()];
      [s refreshClean];
    });
  });
}

- (void)refreshClean {
  uint64_t n = 0, b = 0;
  for (auto& f : _files)
    if (f.selected) {
      n++;
      b += f.bytes;
    }
  _clean.hidden = n == 0;
  _clean.title = DCNS(ui::cleanButtonTitleWithBytes(DCCleanPref(), n ? b : 0));
}

- (void)cleanSelected {
  auto paths = ui::selectedLargeFilePaths(_files);
  if (paths.empty()) {
    DCInformNothingToClean(@"Select files in the list first. Nothing was deleted.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray arrayWithCapacity:paths.size()];
  uint64_t bytes = 0;
  for (auto& f : _files)
    if (f.selected) {
      [list addObject:DCNS(f.path)];
      bytes += f.bytes;
    }
  if (!DCConfirmClean(list, bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applyClean(_engine, paths, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
  } else {
    NSString* msg = DCNS(ui::cleanFinishedDetail(mode, r));
    _status.stringValue = msg;
    DCInformCleaned(@"Clean finished", msg);
  }
  [self startScan];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_files.size();
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto& f = _files[(size_t)row];
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.state = f.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) {
    t.stringValue = DCNS(f.path);
    t.toolTip = t.stringValue;
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(f.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

- (void)tog:(NSButton*)s {
  if (s.tag >= 0 && s.tag < (NSInteger)_files.size()) {
    _files[(size_t)s.tag].selected = s.state == NSControlStateValueOn;
    [self refreshClean];
  }
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSInteger row = _table.clickedRow;
  if (row < 0 || row >= (NSInteger)_files.size()) return;
  auto& f = _files[(size_t)row];
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

- (void)ctxToggleSelect:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_files.size()) return;
  _files[(size_t)row].selected = !_files[(size_t)row].selected;
  [_table reloadData];
  [self refreshClean];
}

- (void)ctxTrashRow:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_files.size()) return;
  auto& f = _files[(size_t)row];
  if (!DCConfirmClean(@[ DCNS(f.path) ], f.bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applyClean(_engine, {f.path}, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    return;
  }
  DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
  [self startScan];
}

@end

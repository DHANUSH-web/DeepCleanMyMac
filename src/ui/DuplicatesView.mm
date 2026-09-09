#import "ui/DuplicatesView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCDuplicatesView () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

@implementation DCDuplicatesView {
  dcmm::Engine _engine;
  std::vector<dcmm::DuplicateGroup> _groups;
  struct Row {
    int g;
    int f;
  };
  std::vector<Row> _rows;
  NSButton* _scan;
  NSButton* _clean;
  NSTextField* _status;
  NSTableView* _table;
  NSStackView* _content;
  DCStartScreen* _startScreen;
  uint64_t _job;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSStackView* page = DCPageStack(self);
    _content = page;
    NSStackView* header = DCHeaderStack(
        @"Duplicates", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Duplicates)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _scan = DCDefaultButton(@"Scan", self, @selector(startScan));
    _clean = DCDestructiveButton(@"Move Copies to Trash", self, @selector(cleanSelected));
    _clean.hidden = YES;
    NSStackView* actions = DCTrailingButtons(@[ _clean, _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(
        @"Matches identical files in Home, Desktop, Documents, Downloads, Pictures, Movies, and Music (256 KB or larger).");
    [page addArrangedSubview:_status];

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_table);
    _table.dataSource = self;
    _table.delegate = self;
    DCAttachTableMenu(_table, self);
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"keep"];
    c0.width = 48;
    c0.title = @"Keep";
    [_table addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"File";
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 90;
    [_table addTableColumn:c2];
    DCStackExpand(page, DCWrapTable(_table));
    __weak DCDuplicatesView* weakSelf = self;
    _startScreen = [[DCStartScreen alloc]
        initWithTitle:@"Duplicates"
             subtitle:[NSString stringWithUTF8String:ui::subtitle(ui::Module::Duplicates)]
               symbol:[NSString stringWithUTF8String:ui::sidebarSymbol(ui::Module::Duplicates)]
        iconPointSize:250
              colored:NO
          buttonTitle:@"Scan"
             onAction:^{
               [weakSelf startScan];
             }];
    _startScreen.subtitleMaxWidth = 360;
    _startScreen.buttonControlSize = NSControlSizeLarge;
    _startScreen.buttonMinWidth = 100;
    _startScreen.buttonFont = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    _startScreen.defaultButton = YES;
    [self addSubview:_startScreen];
    DCPinEdges(_startScreen, self);
    _content.hidden = YES;
    _scan.keyEquivalent = @"";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshCleanTitle)
                                                 name:DCSettingsDidChangeNotification
                                               object:nil];
    [self refreshCleanTitle];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refreshCleanTitle {
  _clean.title = DCCleanPref() == ui::CleanPref::DeletePermanently ? @"Delete Copies Permanently"
                                                                   : @"Move Copies to Trash";
  _clean.hidden = ui::duplicatePathsToTrash(_groups).empty();
}

- (void)rebuild {
  _rows.clear();
  for (int g = 0; g < (int)_groups.size(); ++g)
    for (int f = 0; f < (int)_groups[g].files.size(); ++f) _rows.push_back({g, f});
}

- (void)showContent {
  if (!_startScreen || _startScreen.hidden) return;
  _startScreen.hidden = YES;
  _content.hidden = NO;
  _scan.keyEquivalent = @"\r";
}

- (void)setScanEnabled:(BOOL)on {
  _scan.enabled = on;
  _startScreen.actionButton.enabled = on;
}

- (void)startScan {
  if (!_scan.enabled) return;
  _status.stringValue = @"Hashing…";
  [self setScanEnabled:NO];
  _clean.hidden = YES;
  __weak DCDuplicatesView* weakSelf = self;
  __block std::vector<dcmm::DuplicateGroup> g;
  DCRunBackground(&_job, ^{
    DCDuplicatesView* strong = weakSelf;
    if (!strong) return;
    g = strong->_engine.findDuplicates(ui::duplicateOptions());
  }, ^{
    DCDuplicatesView* s = weakSelf;
    if (!s) return;
    s->_groups = std::move(g);
    [s rebuild];
    [s->_table reloadData];
    [s setScanEnabled:YES];
    s->_status.stringValue =
        [NSString stringWithFormat:@"%lu duplicate groups", (unsigned long)s->_groups.size()];
    [s refreshCleanTitle];
    [s showContent];
  });
}

- (void)cleanSelected {
  auto paths = ui::duplicatePathsToTrash(_groups);
  if (paths.empty()) {
    DCInformNothingToClean(@"Every copy is marked Keep. Nothing was deleted.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  uint64_t bytes = 0;
  for (auto& g : _groups)
    for (auto& f : g.files)
      if (!f.keep) {
        [list addObject:DCNS(f.path)];
        bytes += f.bytes;
      }
  if (!DCConfirmClean(list, bytes)) return;
  const auto mode = DCCleanPref();
  [self setScanEnabled:NO];
  _clean.hidden = YES;
  __weak DCDuplicatesView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCDuplicatesView* strong = weakSelf;
    if (!strong) return;
    r = ui::applyClean(strong->_engine, paths, mode);
  }, ^{
    DCDuplicatesView* s = weakSelf;
    if (!s) return;
    [s setScanEnabled:YES];
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

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto rr = _rows[(size_t)row];
  auto& f = _groups[rr.g].files[rr.f];
  if ([col.identifier isEqualToString:@"keep"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(keep:)];
    b.state = f.keep ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"])
    t.stringValue = DCNS(f.path);
  else {
    t.stringValue = DCNS(dcmm::formatBytes(f.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

- (void)keep:(NSButton*)s {
  if (s.tag < 0 || s.tag >= (NSInteger)_rows.size()) return;
  auto rr = _rows[(size_t)s.tag];
  _groups[rr.g].files[rr.f].keep = s.state == NSControlStateValueOn;
  [self refreshCleanTitle];
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSInteger row = _table.clickedRow;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  auto rr = _rows[(size_t)row];
  auto& f = _groups[rr.g].files[rr.f];
  DCAddPathMenuItems(menu, DCNS(f.path));
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* keep = [[NSMenuItem alloc] initWithTitle:f.keep ? @"Don't Keep This Copy" : @"Keep This Copy"
                                                action:@selector(ctxToggleKeep:)
                                         keyEquivalent:@""];
  keep.target = self;
  keep.tag = row;
  [menu addItem:keep];
  NSMenuItem* trash = [[NSMenuItem alloc] initWithTitle:DCNS(ui::cleanMenuTitle(DCCleanPref()))
                                                 action:@selector(ctxTrashRow:)
                                          keyEquivalent:@""];
  trash.target = self;
  trash.tag = row;
  [menu addItem:trash];
}

- (void)ctxToggleKeep:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  auto rr = _rows[(size_t)row];
  auto& f = _groups[rr.g].files[rr.f];
  f.keep = !f.keep;
  [_table reloadData];
  [self refreshCleanTitle];
}

- (void)ctxTrashRow:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  auto rr = _rows[(size_t)row];
  auto& f = _groups[rr.g].files[rr.f];
  if (!DCConfirmClean(@[ DCNS(f.path) ], f.bytes)) return;
  const auto mode = DCCleanPref();
  std::string path = f.path;
  [self setScanEnabled:NO];
  __weak DCDuplicatesView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCDuplicatesView* strong = weakSelf;
    if (!strong) return;
    r = ui::applyClean(strong->_engine, {path}, mode);
  }, ^{
    DCDuplicatesView* s = weakSelf;
    if (!s) return;
    [s setScanEnabled:YES];
    if (r.trashedItems == 0) {
      DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
      return;
    }
    DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
    [s startScan];
  });
}

@end

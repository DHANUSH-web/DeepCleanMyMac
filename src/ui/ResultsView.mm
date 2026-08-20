#import "ui/ResultsView.h"
#import "ui/Theme.h"

#include "dcmm/dcmm.hpp"

#include <vector>

namespace {
struct FlatRow {
  bool group = false;
  int g = -1;
  int i = -1;
};
}  // namespace

@interface DCResultsView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation DCResultsView {
  DCResultsMode _mode;
  dcmm::Engine _engine;
  dcmm::ScanReport _report;
  std::vector<FlatRow> _rows;
  NSInteger _state;

  NSTextField* _title;
  NSTextField* _sub;
  DCButton* _scanBtn;
  DCButton* _cleanBtn;
  DCButton* _selAll;
  NSProgressIndicator* _spin;
  NSTextField* _status;
  NSScrollView* _scroll;
  NSTableView* _table;
  NSTextField* _hero;
}

- (instancetype)initWithMode:(DCResultsMode)mode {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _mode = mode;
    _state = 0;
    const char* t = mode == DCResultsModePrivacy ? "Privacy" : "Smart Scan";
    const char* s = mode == DCResultsModePrivacy
                        ? "Browser caches and tracking leftovers. Cookies stay off unless you opt in."
                        : "Caches, logs, developer leftovers, and Trash — review, then move to Trash.";
    _title = DCLabel([NSString stringWithUTF8String:t], th::title(), th::text());
    _sub = DCLabel([NSString stringWithUTF8String:s], th::body(), th::muted());
    _sub.usesSingleLineMode = NO;
    _sub.cell.wraps = YES;
    [self addSubview:_title];
    [self addSubview:_sub];

    _scanBtn = [[DCButton alloc] initWithFrame:NSMakeRect(0, 0, 140, 36)];
    _scanBtn.title = @"Scan";
    _scanBtn.target = self;
    _scanBtn.action = @selector(startScan);
    [self addSubview:_scanBtn];

    _cleanBtn = [[DCButton alloc] initWithFrame:NSMakeRect(0, 0, 160, 36)];
    _cleanBtn.title = @"Move to Trash";
    _cleanBtn.destructive = YES;
    _cleanBtn.target = self;
    _cleanBtn.action = @selector(cleanSelected);
    _cleanBtn.hidden = YES;
    [self addSubview:_cleanBtn];

    _selAll = [[DCButton alloc] initWithFrame:NSMakeRect(0, 0, 110, 36)];
    _selAll.title = @"Select All";
    _selAll.primary = NO;
    _selAll.target = self;
    _selAll.action = @selector(toggleAll);
    _selAll.hidden = YES;
    [self addSubview:_selAll];

    _spin = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    _spin.style = NSProgressIndicatorStyleSpinning;
    _spin.displayedWhenStopped = NO;
    _spin.controlSize = NSControlSizeSmall;
    [self addSubview:_spin];
    _status = DCLabel(@"Ready when you are.", th::body(), th::muted());
    [self addSubview:_status];
    _hero = DCLabel(@"", [NSFont systemFontOfSize:42 weight:NSFontWeightBold], th::accent());
    _hero.hidden = YES;
    [self addSubview:_hero];

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _table.headerView = [[NSTableHeaderView alloc] init];
    _table.rowHeight = 28;
    _table.backgroundColor = th::card();
    _table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    _table.dataSource = self;
    _table.delegate = self;

    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 36;
    c0.title = @"";
    [_table addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"Item";
    c1.width = 420;
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"files"];
    c2.title = @"Files";
    c2.width = 80;
    [_table addTableColumn:c2];
    NSTableColumn* c3 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c3.title = @"Size";
    c3.width = 100;
    [_table addTableColumn:c3];

    _scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _scroll.documentView = _table;
    _scroll.hasVerticalScroller = YES;
    _scroll.drawsBackground = YES;
    _scroll.backgroundColor = th::card();
    _scroll.wantsLayer = YES;
    _scroll.layer.cornerRadius = 12;
    _scroll.hidden = YES;
    [self addSubview:_scroll];
  }
  return self;
}
- (BOOL)isFlipped {
  return YES;
}
- (void)rebuildRows {
  _rows.clear();
  for (int g = 0; g < (int)_report.groups.size(); ++g) {
    _rows.push_back({true, g, -1});
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
  _scanBtn.primary = NO;
  _cleanBtn.hidden = YES;
  _selAll.hidden = YES;
  _scroll.hidden = YES;
  _hero.hidden = YES;
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
            [NSString stringWithFormat:@"Scanning %@  ·  %llu items", DCNS(dcmm::displayName(p)),
                                       (unsigned long long)vis];
      });
    };
    auto r = (strong->_mode == DCResultsModePrivacy) ? strong->_engine.scanPrivacy(cb)
                                                     : strong->_engine.scanJunk(cb);
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
  _scanBtn.primary = NO;
  _cleanBtn.hidden = NO;
  _selAll.hidden = NO;
  _scroll.hidden = NO;
  _hero.hidden = NO;
  _hero.stringValue = DCNS(dcmm::formatBytes(_report.totalBytes()));
  _status.stringValue =
      [NSString stringWithFormat:@"Found %@ in %lu groups  ·  %.1f s",
                                 DCNS(dcmm::formatBytes(_report.totalBytes())),
                                 (unsigned long)_report.groups.size(), _report.elapsedMs / 1000.0];
  [_table reloadData];
  [self refreshCleanTitle];
  self.needsLayout = YES;
}
- (void)refreshCleanTitle {
  uint64_t b = _report.selectedBytes();
  _cleanBtn.title = [NSString stringWithFormat:@"Move %@ to Trash", DCNS(dcmm::formatBytes(b))];
  _cleanBtn.enabled = b > 0;
}
- (void)toggleAll {
  bool anyOff = false;
  for (auto& g : _report.groups)
    for (auto& it : g.items)
      if (!it.selected && !it.reviewFirst) anyOff = true;
  for (auto& g : _report.groups)
    for (auto& it : g.items)
      if (!it.reviewFirst) it.selected = anyOff;
  [_table reloadData];
  [self refreshCleanTitle];
}
- (void)cleanSelected {
  auto paths = _report.selectedPaths();
  if (paths.empty()) return;
  NSAlert* a = [[NSAlert alloc] init];
  a.messageText = @"Move selected items to Trash?";
  a.informativeText = [NSString
      stringWithFormat:@"%@ across %lu items will be moved to Trash. Protected system locations are never "
                       @"touched.",
                       DCNS(dcmm::formatBytes(_report.selectedBytes())), (unsigned long)paths.size()];
  a.alertStyle = NSAlertStyleWarning;
  [a addButtonWithTitle:@"Move to Trash"];
  [a addButtonWithTitle:@"Cancel"];
  if ([a runModal] != NSAlertFirstButtonReturn) return;
  _cleanBtn.enabled = NO;
  __weak DCResultsView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCResultsView* strong = weakSelf;
    if (!strong) return;
    auto result = strong->_engine.trashPaths(paths);
    dispatch_async(dispatch_get_main_queue(), ^{
      DCResultsView* weak = weakSelf;
      if (!weak) return;
      NSAlert* done = [[NSAlert alloc] init];
      done.messageText = @"Clean finished";
      done.informativeText =
          [NSString stringWithFormat:@"Moved %llu items (%@) to Trash. %llu skipped.",
                                     (unsigned long long)result.trashedItems,
                                     DCNS(dcmm::formatBytes(result.trashedBytes)),
                                     (unsigned long long)result.failedItems];
      [done addButtonWithTitle:@"OK"];
      [done runModal];
      [weak startScan];
    });
  });
}
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_rows.size();
}
- (NSView*)tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)column row:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)_rows.size()) return nil;
  FlatRow fr = _rows[(size_t)row];
  NSString* ident = column.identifier;
  if (fr.group) {
    const auto& g = _report.groups[fr.g];
    NSTextField* t = DCLabel(@"", th::heading(), th::text());
    if ([ident isEqualToString:@"name"]) t.stringValue = DCNS(g.title);
    else if ([ident isEqualToString:@"size"]) {
      t.stringValue = DCNS(dcmm::formatBytes(g.totalBytes()));
      t.textColor = th::accent();
      t.font = th::mono();
    } else
      t.stringValue = @"";
    return t;
  }
  auto& it = _report.groups[fr.g].items[fr.i];
  if ([ident isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(checkToggled:)];
    b.state = it.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return b;
  }
  NSTextField* t = DCLabel(@"", th::body(), th::text());
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([ident isEqualToString:@"name"]) {
    t.stringValue = DCNS(it.displayName);
    t.textColor = it.reviewFirst ? th::warn() : th::text();
    t.toolTip = DCNS(it.path);
  } else if ([ident isEqualToString:@"files"]) {
    t.stringValue = [NSString stringWithFormat:@"%llu", (unsigned long long)it.fileCount];
    t.textColor = th::muted();
  } else if ([ident isEqualToString:@"size"]) {
    t.stringValue = DCNS(dcmm::formatBytes(it.bytes));
    t.font = th::mono();
  }
  return t;
}
- (void)checkToggled:(NSButton*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_rows.size()) return;
  FlatRow fr = _rows[(size_t)row];
  if (fr.group) return;
  _report.groups[fr.g].items[fr.i].selected = sender.state == NSControlStateValueOn;
  [self refreshCleanTitle];
}
- (CGFloat)tableView:(NSTableView*)tableView heightOfRow:(NSInteger)row {
  if (row >= 0 && row < (NSInteger)_rows.size() && _rows[(size_t)row].group) return 34;
  return 26;
}
- (void)layout {
  [super layout];
  NSRect b = self.bounds;
  _title.frame = NSMakeRect(8, 8, b.size.width - 320, 34);
  _sub.frame = NSMakeRect(8, 44, b.size.width - 320, 36);
  _scanBtn.frame = NSMakeRect(b.size.width - 156, 10, 140, 36);
  _cleanBtn.frame = NSMakeRect(b.size.width - 330, 10, 164, 36);
  _selAll.frame = NSMakeRect(b.size.width - 450, 10, 110, 36);
  _spin.frame = NSMakeRect(8, 88, 16, 16);
  _status.frame = NSMakeRect(28, 86, b.size.width - 40, 20);
  _hero.frame = NSMakeRect(8, 112, 400, 48);
  CGFloat tableY = _hero.hidden ? 116 : 168;
  _scroll.frame = NSMakeRect(8, tableY, b.size.width - 16, b.size.height - tableY - 8);
}
@end

#import "ui/DuplicatesView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"
#include <vector>

@interface DCDuplicatesView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation DCDuplicatesView {
  dcmm::Engine _engine;
  std::vector<dcmm::DuplicateGroup> _groups;
  struct Row { int g; int f; };
  std::vector<Row> _rows;
  NSTextField* _title;
  NSTextField* _status;
  DCButton* _scan;
  DCButton* _clean;
  NSTableView* _table;
  NSScrollView* _scroll;
}
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _title = DCLabel(@"Duplicates", th::title(), th::text());
    [self addSubview:_title];
    _status = DCLabel(@"SHA-256 matched copies under Downloads, Desktop, and Documents (≥ 256 KB).",
                      th::body(), th::muted());
    [self addSubview:_status];
    _scan = [[DCButton alloc] initWithFrame:NSZeroRect];
    _scan.title = @"Scan";
    _scan.target = self;
    _scan.action = @selector(startScan);
    [self addSubview:_scan];
    _clean = [[DCButton alloc] initWithFrame:NSZeroRect];
    _clean.title = @"Trash copies";
    _clean.destructive = YES;
    _clean.target = self;
    _clean.action = @selector(cleanSelected);
    [self addSubview:_clean];
    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _table.backgroundColor = th::card();
    _table.dataSource = self;
    _table.delegate = self;
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"keep"];
    c0.width = 70;
    c0.title = @"Keep";
    [_table addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"File";
    c1.width = 520;
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 90;
    [_table addTableColumn:c2];
    _scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _scroll.documentView = _table;
    _scroll.hasVerticalScroller = YES;
    _scroll.backgroundColor = th::card();
    _scroll.wantsLayer = YES;
    _scroll.layer.cornerRadius = 12;
    [self addSubview:_scroll];
  }
  return self;
}
- (BOOL)isFlipped { return YES; }
- (void)rebuild {
  _rows.clear();
  for (int g = 0; g < (int)_groups.size(); ++g)
    for (int f = 0; f < (int)_groups[g].files.size(); ++f) _rows.push_back({g, f});
}
- (void)startScan {
  _status.stringValue = @"Hashing…";
  _scan.enabled = NO;
  __weak DCDuplicatesView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCDuplicatesView* strong = weakSelf;
    if (!strong) return;
    dcmm::DuplicateOptions opt;
    auto home = dcmm::homeDirectory();
    opt.roots = {dcmm::joinPath(home, "Downloads"), dcmm::joinPath(home, "Desktop"),
                 dcmm::joinPath(home, "Documents")};
    auto g = strong->_engine.findDuplicates(opt);
    dispatch_async(dispatch_get_main_queue(), ^{
      DCDuplicatesView* s = weakSelf;
      if (!s) return;
      s->_groups = std::move(g);
      [s rebuild];
      [s->_table reloadData];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu duplicate groups", (unsigned long)s->_groups.size()];
    });
  });
}
- (void)cleanSelected {
  std::vector<std::string> paths;
  for (auto& g : _groups)
    for (auto& f : g.files)
      if (!f.keep) paths.push_back(f.path);
  if (paths.empty()) return;
  NSAlert* a = [[NSAlert alloc] init];
  a.messageText = @"Move duplicate copies to Trash? (kept files stay)";
  [a addButtonWithTitle:@"Move copies to Trash"];
  [a addButtonWithTitle:@"Cancel"];
  if ([a runModal] != NSAlertFirstButtonReturn) return;
  auto r = _engine.trashPaths(paths);
  _status.stringValue = [NSString stringWithFormat:@"Moved %llu copies.", (unsigned long long)r.trashedItems];
  [self startScan];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv { return (NSInteger)_rows.size(); }
- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto rr = _rows[(size_t)row];
  auto& f = _groups[rr.g].files[rr.f];
  if ([col.identifier isEqualToString:@"keep"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(keep:)];
    b.state = f.keep ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return b;
  }
  NSTextField* t = DCLabel(@"", th::body(), th::text());
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) t.stringValue = DCNS(f.path);
  else {
    t.stringValue = DCNS(dcmm::formatBytes(f.bytes));
    t.font = th::mono();
  }
  return t;
}
- (void)keep:(NSButton*)s {
  if (s.tag < 0 || s.tag >= (NSInteger)_rows.size()) return;
  auto rr = _rows[(size_t)s.tag];
  _groups[rr.g].files[rr.f].keep = s.state == NSControlStateValueOn;
}
- (void)layout {
  [super layout];
  NSRect b = self.bounds;
  _title.frame = NSMakeRect(8, 8, 400, 34);
  _status.frame = NSMakeRect(8, 44, b.size.width - 300, 20);
  _scan.frame = NSMakeRect(b.size.width - 140, 10, 120, 36);
  _clean.frame = NSMakeRect(b.size.width - 310, 10, 160, 36);
  _scroll.frame = NSMakeRect(8, 76, b.size.width - 16, b.size.height - 84);
}
@end

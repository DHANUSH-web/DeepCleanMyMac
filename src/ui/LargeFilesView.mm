#import "ui/LargeFilesView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"
#include <vector>

@interface DCLargeFilesView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation DCLargeFilesView {
  dcmm::Engine _engine;
  std::vector<dcmm::LargeFile> _files;
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
    _title = DCLabel(@"Large Files", th::title(), th::text());
    [self addSubview:_title];
    _status = DCLabel(@"Scan Desktop, Documents, Downloads, and Movies for files ≥ 50 MB.", th::body(),
                      th::muted());
    [self addSubview:_status];
    _scan = [[DCButton alloc] initWithFrame:NSMakeRect(0, 0, 120, 36)];
    _scan.title = @"Scan";
    _scan.target = self;
    _scan.action = @selector(startScan);
    [self addSubview:_scan];
    _clean = [[DCButton alloc] initWithFrame:NSMakeRect(0, 0, 160, 36)];
    _clean.title = @"Move to Trash";
    _clean.destructive = YES;
    _clean.target = self;
    _clean.action = @selector(cleanSelected);
    _clean.enabled = NO;
    [self addSubview:_clean];
    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _table.backgroundColor = th::card();
    _table.dataSource = self;
    _table.delegate = self;
    _table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 36;
    c0.title = @"";
    [_table addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"File";
    c1.width = 520;
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 100;
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
- (void)startScan {
  _status.stringValue = @"Scanning…";
  _scan.enabled = NO;
  __weak DCLargeFilesView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCLargeFilesView* strong = weakSelf;
    if (!strong) return;
    dcmm::LargeFileOptions opt;
    auto home = dcmm::homeDirectory();
    opt.roots = {dcmm::joinPath(home, "Desktop"), dcmm::joinPath(home, "Documents"),
                 dcmm::joinPath(home, "Downloads"), dcmm::joinPath(home, "Movies")};
    auto files = strong->_engine.findLargeFiles(opt);
    dispatch_async(dispatch_get_main_queue(), ^{
      DCLargeFilesView* s = weakSelf;
      if (!s) return;
      s->_files = std::move(files);
      [s->_table reloadData];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu files ≥ 50 MB", (unsigned long)s->_files.size()];
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
  _clean.enabled = n > 0;
  _clean.title = n ? [NSString stringWithFormat:@"Move %@ to Trash", DCNS(dcmm::formatBytes(b))]
                   : @"Move to Trash";
}
- (void)cleanSelected {
  std::vector<std::string> paths;
  for (auto& f : _files)
    if (f.selected) paths.push_back(f.path);
  if (paths.empty()) return;
  NSAlert* a = [[NSAlert alloc] init];
  a.messageText = @"Move selected large files to Trash?";
  [a addButtonWithTitle:@"Move to Trash"];
  [a addButtonWithTitle:@"Cancel"];
  if ([a runModal] != NSAlertFirstButtonReturn) return;
  auto r = _engine.trashPaths(paths);
  _status.stringValue = [NSString stringWithFormat:@"Moved %llu items.", (unsigned long long)r.trashedItems];
  [self startScan];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv { return (NSInteger)_files.size(); }
- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto& f = _files[(size_t)row];
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.state = f.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return b;
  }
  NSTextField* t = DCLabel(@"", th::body(), th::text());
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) {
    t.stringValue = DCNS(f.path);
    t.toolTip = t.stringValue;
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(f.bytes));
    t.font = th::mono();
  }
  return t;
}
- (void)tog:(NSButton*)s {
  if (s.tag >= 0 && s.tag < (NSInteger)_files.size()) {
    _files[(size_t)s.tag].selected = s.state == NSControlStateValueOn;
    [self refreshClean];
  }
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

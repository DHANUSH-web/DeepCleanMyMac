#import "ui/SpaceLensView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"
#include <algorithm>
#include <vector>

@interface DCSpaceLensView () <NSTableViewDataSource>
@end

@implementation DCSpaceLensView {
  dcmm::Engine _engine;
  std::vector<dcmm::SpaceNode> _nodes;
  uint64_t _max;
  NSTextField* _title;
  NSTextField* _status;
  DCButton* _scan;
  NSTableView* _table;
  NSScrollView* _scroll;
}
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _max = 1;
    _title = DCLabel(@"Space Lens", th::title(), th::text());
    [self addSubview:_title];
    _status = DCLabel(@"Where space went inside your home folder.", th::body(), th::muted());
    [self addSubview:_status];
    _scan = [[DCButton alloc] initWithFrame:NSZeroRect];
    _scan.title = @"Analyze";
    _scan.target = self;
    _scan.action = @selector(startScan);
    [self addSubview:_scan];
    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _table.backgroundColor = th::card();
    _table.dataSource = self;
    _table.rowHeight = 28;
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"Folder";
    c1.width = 280;
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 100;
    [_table addTableColumn:c2];
    NSTableColumn* c3 = [[NSTableColumn alloc] initWithIdentifier:@"bar"];
    c3.title = @"Share";
    c3.width = 320;
    [_table addTableColumn:c3];
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
  _status.stringValue = @"Walking home folder…";
  _scan.enabled = NO;
  __weak DCSpaceLensView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCSpaceLensView* strong = weakSelf;
    if (!strong) return;
    auto n = strong->_engine.spaceLens();
    dispatch_async(dispatch_get_main_queue(), ^{
      DCSpaceLensView* s = weakSelf;
      if (!s) return;
      s->_nodes = std::move(n);
      s->_max = 1;
      for (auto& x : s->_nodes) s->_max = std::max(s->_max, x.bytes);
      [s->_table reloadData];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu folders", (unsigned long)s->_nodes.size()];
    });
  });
}
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv { return (NSInteger)_nodes.size(); }
- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto& n = _nodes[(size_t)row];
  if ([col.identifier isEqualToString:@"bar"]) {
    NSLevelIndicator* lv = [[NSLevelIndicator alloc] initWithFrame:NSMakeRect(0, 0, 200, 16)];
    lv.levelIndicatorStyle = NSLevelIndicatorStyleContinuousCapacity;
    lv.minValue = 0;
    lv.maxValue = 100;
    lv.doubleValue = _max ? (100.0 * n.bytes / _max) : 0;
    return lv;
  }
  NSTextField* t = DCLabel(@"", th::body(), th::text());
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) t.stringValue = DCNS(n.name);
  else {
    t.stringValue = DCNS(dcmm::formatBytes(n.bytes));
    t.font = th::mono();
  }
  return t;
}
- (void)layout {
  [super layout];
  NSRect b = self.bounds;
  _title.frame = NSMakeRect(8, 8, 400, 34);
  _status.frame = NSMakeRect(8, 44, b.size.width - 180, 20);
  _scan.frame = NSMakeRect(b.size.width - 140, 10, 120, 36);
  _scroll.frame = NSMakeRect(8, 76, b.size.width - 16, b.size.height - 84);
}
@end

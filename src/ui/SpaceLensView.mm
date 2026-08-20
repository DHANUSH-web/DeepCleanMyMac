#import "ui/SpaceLensView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <algorithm>
#include <vector>

@interface DCSpaceLensView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation DCSpaceLensView {
  dcmm::Engine _engine;
  std::vector<dcmm::SpaceNode> _nodes;
  uint64_t _max;
  NSButton* _scan;
  NSTextField* _status;
  NSTableView* _table;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _max = 1;
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Space Lens", [NSString stringWithUTF8String:ui::subtitle(ui::Module::SpaceLens)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _scan = DCDefaultButton(@"Analyze", self, @selector(startScan));
    NSStackView* actions = DCTrailingButtons(@[ _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(@"Measures folders in your home directory.");
    [page addArrangedSubview:_status];

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_table);
    _table.dataSource = self;
    _table.delegate = self;
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"Folder";
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 100;
    [_table addTableColumn:c2];
    NSTableColumn* c3 = [[NSTableColumn alloc] initWithIdentifier:@"bar"];
    c3.title = @"Share";
    c3.width = 180;
    [_table addTableColumn:c3];
    DCStackExpand(page, DCWrapTable(_table));
  }
  return self;
}

- (void)startScan {
  _status.stringValue = @"Measuring…";
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

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_nodes.size();
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto& n = _nodes[(size_t)row];
  if ([col.identifier isEqualToString:@"bar"]) {
    NSLevelIndicator* lv = [[NSLevelIndicator alloc] initWithFrame:NSZeroRect];
    lv.levelIndicatorStyle = NSLevelIndicatorStyleContinuousCapacity;
    lv.minValue = 0;
    lv.maxValue = 100;
    lv.doubleValue = _max ? (100.0 * n.bytes / _max) : 0;
    return DCCenteredFillCell(lv);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"])
    t.stringValue = DCNS(n.name);
  else {
    t.stringValue = DCNS(dcmm::formatBytes(n.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

@end

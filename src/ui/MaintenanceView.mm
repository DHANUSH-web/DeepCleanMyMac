#import "ui/MaintenanceView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"

@implementation DCMaintenanceView {
  dcmm::Engine _engine;
  NSTextField* _title;
  NSTextField* _log;
  NSMutableArray<NSView*>* _rows;
}
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _title = DCLabel(@"Maintenance", th::title(), th::text());
    [self addSubview:_title];
    NSTextField* sub = DCLabel(@"Housekeeping tasks exposed by dcmmlib. Each action is explicit.",
                               th::body(), th::muted());
    sub.tag = 2;
    [self addSubview:sub];
    _rows = [NSMutableArray new];
    int i = 0;
    for (const auto& t : _engine.maintenanceTasks()) {
      NSView* card = [[NSView alloc] initWithFrame:NSZeroRect];
      DCRoundLayer(card, 12, th::card(), th::stroke());
      NSTextField* h = DCLabel(DCNS(t.title), th::heading(), th::text());
      h.frame = NSMakeRect(16, 36, 520, 22);
      [card addSubview:h];
      NSTextField* d = DCLabel(DCNS(t.detail), th::body(), th::muted());
      d.frame = NSMakeRect(16, 12, 520, 20);
      [card addSubview:d];
      DCButton* run = [[DCButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 32)];
      run.title = @"Run";
      run.tag = i++;
      run.target = self;
      run.action = @selector(runTask:);
      [card addSubview:run];
      card.identifier = DCNS(t.id);
      [_rows addObject:card];
      [self addSubview:card];
    }
    _log = DCLabel(@"", th::body(), th::muted());
    _log.usesSingleLineMode = NO;
    _log.cell.wraps = YES;
    [self addSubview:_log];
  }
  return self;
}
- (BOOL)isFlipped { return YES; }
- (void)runTask:(DCButton*)sender {
  auto tasks = _engine.maintenanceTasks();
  if (sender.tag < 0 || sender.tag >= (NSInteger)tasks.size()) return;
  auto id = tasks[(size_t)sender.tag].id;
  if (id == "empty_trash") {
    NSAlert* a = [[NSAlert alloc] init];
    a.messageText = @"Empty Trash permanently?";
    a.informativeText = @"This cannot be undone.";
    [a addButtonWithTitle:@"Empty Trash"];
    [a addButtonWithTitle:@"Cancel"];
    if ([a runModal] != NSAlertFirstButtonReturn) return;
  }
  auto msg = _engine.runMaintenance(id);
  _log.stringValue = DCNS(msg);
}
- (void)layout {
  [super layout];
  NSRect b = self.bounds;
  _title.frame = NSMakeRect(8, 8, 400, 34);
  [self viewWithTag:2].frame = NSMakeRect(8, 44, b.size.width - 16, 20);
  CGFloat y = 80;
  for (NSView* card in _rows) {
    card.frame = NSMakeRect(8, y, b.size.width - 16, 72);
    for (NSView* sv in card.subviews)
      if ([sv isKindOfClass:[DCButton class]])
        sv.frame = NSMakeRect(card.bounds.size.width - 116, 20, 100, 32);
    y += 84;
  }
  _log.frame = NSMakeRect(8, y + 8, b.size.width - 16, 80);
}
@end

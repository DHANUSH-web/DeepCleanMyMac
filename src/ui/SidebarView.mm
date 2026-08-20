#import "ui/SidebarView.h"
#import "ui/Theme.h"
#include <cstdio>

static NSArray<NSString*>* DCSymbols() {
  return @[
    @"square.grid.2x2.fill", @"sparkles", @"internaldrive", @"doc.badge.ellipsis",
    @"doc.on.doc.fill", @"shippingbox.fill", @"eye.slash.fill", @"chart.bar.fill",
    @"wrench.and.screwdriver.fill"
  ];
}

@interface DCNavRow : NSView
@property(nonatomic) ui::Module module;
@property(nonatomic) BOOL selectedRow;
@property(nonatomic) BOOL hover;
@property(nonatomic, copy) void (^onClick)(ui::Module);
@end

@implementation DCNavRow
- (BOOL)isFlipped {
  return YES;
}
- (void)drawRect:(NSRect)dirty {
  NSRect b = NSInsetRect(self.bounds, 12, 2);
  if (self.selectedRow) {
    [[NSBezierPath bezierPathWithRoundedRect:b xRadius:10 yRadius:10] fill];
    [th::accentDim() setFill];
    [[NSBezierPath bezierPathWithRoundedRect:b xRadius:10 yRadius:10] fill];
  } else if (self.hover) {
    [th::rgb(1, 1, 1, 0.04) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:b xRadius:10 yRadius:10] fill];
  }
  NSImage* img = [NSImage imageWithSystemSymbolName:DCSymbols()[(int)self.module]
                           accessibilityDescription:nil];
  img = [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14
                                                                                         weight:NSFontWeightMedium]];
  NSRect ir = NSMakeRect(b.origin.x + 12, b.origin.y + (b.size.height - 16) / 2, 16, 16);
  [img drawInRect:ir];
  NSString* title = [NSString stringWithUTF8String:ui::title(self.module)];
  [title drawAtPoint:NSMakePoint(b.origin.x + 38, b.origin.y + (b.size.height - 18) / 2)
      withAttributes:@{
        NSFontAttributeName : [NSFont systemFontOfSize:13
                                                weight:self.selectedRow ? NSFontWeightSemibold
                                                                        : NSFontWeightMedium],
        NSForegroundColorAttributeName : self.selectedRow ? th::text() : th::muted()
      }];
}
- (void)mouseDown:(NSEvent*)event {
  if (self.onClick) self.onClick(self.module);
}
- (void)updateTrackingAreas {
  [super updateTrackingAreas];
  for (NSTrackingArea* a in self.trackingAreas) [self removeTrackingArea:a];
  [self addTrackingArea:[[NSTrackingArea alloc]
                            initWithRect:self.bounds
                                 options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                   owner:self
                                userInfo:nil]];
}
- (void)mouseEntered:(NSEvent*)event {
  self.hover = YES;
  self.needsDisplay = YES;
}
- (void)mouseExited:(NSEvent*)event {
  self.hover = NO;
  self.needsDisplay = YES;
}
- (void)resetCursorRects {
  [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
}
@end

@implementation DCSidebarView {
  NSMutableArray<DCNavRow*>* _rows;
  DCRingView* _ring;
  NSTextField* _freeLabel;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _selected = ui::Module::Overview;
    _diskUsedFraction = 0.5;
    _rows = [NSMutableArray new];
    self.wantsLayer = YES;
    self.layer.backgroundColor = th::sidebar().CGColor;

    NSTextField* brand = DCLabel(@"DeepClean", th::heading(), th::text());
    brand.tag = 10;
    [self addSubview:brand];
    NSTextField* brand2 = DCLabel(@"My Mac", th::heading(), th::accent());
    brand2.tag = 11;
    [self addSubview:brand2];

    _ring = [[DCRingView alloc] initWithFrame:NSZeroRect];
    [self addSubview:_ring];
    _freeLabel = DCLabel(@"", th::small(), th::muted());
    _freeLabel.alignment = NSTextAlignmentCenter;
    [self addSubview:_freeLabel];

    for (int i = 0; i < (int)ui::Module::Count; ++i) {
      DCNavRow* row = [[DCNavRow alloc] initWithFrame:NSZeroRect];
      row.module = (ui::Module)i;
      __weak DCSidebarView* weak = self;
      row.onClick = ^(ui::Module m) {
        weak.selected = m;
        [weak reload];
        if (weak.onSelect) weak.onSelect(m);
      };
      [_rows addObject:row];
      [self addSubview:row];
    }
    NSTextField* ver = DCLabel(@"v1.0.0  ·  powered by dcmmlib", th::small(), th::dim());
    ver.tag = 99;
    [self addSubview:ver];
  }
  return self;
}
- (BOOL)isFlipped {
  return YES;
}
- (void)setSelected:(ui::Module)selected {
  _selected = selected;
  [self reload];
}
- (void)setFreeCaption:(NSString*)freeCaption {
  _freeCaption = [freeCaption copy];
  _freeLabel.stringValue = _freeCaption ?: @"";
}
- (void)setDiskUsedFraction:(double)diskUsedFraction {
  _diskUsedFraction = diskUsedFraction;
  _ring.progress = diskUsedFraction;
}
- (void)reload {
  for (DCNavRow* r in _rows) {
    r.selectedRow = (r.module == self.selected);
    r.needsDisplay = YES;
  }
}
- (void)layout {
  [super layout];
  NSRect b = self.bounds;
  [self viewWithTag:10].frame = NSMakeRect(24, 24, 200, 22);
  [self viewWithTag:11].frame = NSMakeRect(24, 44, 200, 22);
  [self viewWithTag:99].frame = NSMakeRect(24, b.size.height - 36, 200, 18);
  _ring.frame = NSMakeRect((b.size.width - 130) / 2, 78, 130, 130);
  char usedPct[32];
  snprintf(usedPct, sizeof(usedPct), "%.0f%% used", self.diskUsedFraction * 100.0);
  _ring.centerText = [NSString stringWithUTF8String:usedPct];
  _freeLabel.frame = NSMakeRect(16, 210, b.size.width - 32, 18);
  CGFloat y = 248;
  for (DCNavRow* r in _rows) {
    r.frame = NSMakeRect(0, y, b.size.width, 38);
    y += 40;
  }
}
@end

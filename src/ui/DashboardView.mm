#import "ui/DashboardView.h"
#import "ui/Theme.h"

#include "dcmm/dcmm.hpp"

@interface DCDashCard : NSView
@property(nonatomic) ui::Module module;
@property(nonatomic, copy) NSString* titleStr;
@property(nonatomic, copy) NSString* bodyStr;
@property(nonatomic, copy) NSString* symbol;
@property(nonatomic, copy) void (^onOpen)(ui::Module);
@property(nonatomic) BOOL hover;
@end

@implementation DCDashCard
- (BOOL)isFlipped {
  return YES;
}
- (void)drawRect:(NSRect)dirty {
  NSRect b = self.bounds;
  NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect:b xRadius:14 yRadius:14];
  [(self.hover ? th::cardHi() : th::card()) setFill];
  [p fill];
  [th::stroke() setStroke];
  p.lineWidth = 1;
  [p stroke];
  NSImage* img = [NSImage imageWithSystemSymbolName:self.symbol accessibilityDescription:nil];
  img = [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:22
                                                                                         weight:NSFontWeightMedium]];
  [img drawInRect:NSMakeRect(18, 18, 28, 28)];
  [self.titleStr drawAtPoint:NSMakePoint(18, 56)
              withAttributes:@{NSFontAttributeName : th::heading(), NSForegroundColorAttributeName : th::text()}];
  [self.bodyStr drawInRect:NSMakeRect(18, 80, b.size.width - 36, 48)
            withAttributes:@{NSFontAttributeName : th::body(), NSForegroundColorAttributeName : th::muted()}];
}
- (void)mouseDown:(NSEvent*)event {
  if (self.onOpen) self.onOpen(self.module);
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

@implementation DCDashboardView {
  DCRingView* _ring;
  NSTextField* _vol;
  NSTextField* _free;
  NSTextField* _total;
  NSTextField* _mem;
  NSTextField* _hint;
  NSView* _diskCard;
  NSMutableArray<DCDashCard*>* _cards;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSTextField* h = DCLabel(@"Overview", th::title(), th::text());
    h.tag = 1;
    [self addSubview:h];
    NSTextField* s = DCLabel(@"Local engine (dcmmlib). Nothing leaves this Mac.", th::body(), th::muted());
    s.tag = 2;
    [self addSubview:s];

    _diskCard = [[NSView alloc] initWithFrame:NSZeroRect];
    DCRoundLayer(_diskCard, 16, th::card(), th::stroke());
    [self addSubview:_diskCard];
    _ring = [[DCRingView alloc] initWithFrame:NSZeroRect];
    [_diskCard addSubview:_ring];
    _vol = DCLabel(@"Disk", th::heading(), th::text());
    [_diskCard addSubview:_vol];
    _free = DCLabel(@"", [NSFont systemFontOfSize:28 weight:NSFontWeightBold], th::text());
    [_diskCard addSubview:_free];
    _total = DCLabel(@"", th::body(), th::muted());
    [_diskCard addSubview:_total];
    _mem = DCLabel(@"", th::body(), th::muted());
    [_diskCard addSubview:_mem];
    _hint = DCLabel(@"Grant Full Disk Access in System Settings → Privacy for a deeper scan.",
                    th::small(), th::dim());
    _hint.usesSingleLineMode = NO;
    _hint.cell.wraps = YES;
    [_diskCard addSubview:_hint];

    _cards = [NSMutableArray new];
    struct Spec {
      ui::Module m;
      const char* t;
      const char* b;
      const char* sy;
    } specs[] = {
        {ui::Module::SmartScan, "Smart Scan", "Caches, logs, and leftover junk in one pass.", "sparkles"},
        {ui::Module::LargeFiles, "Large Files", "Oversized files you can review and trash.", "doc.badge.ellipsis"},
        {ui::Module::Duplicates, "Duplicates", "Hash-matched copies under common folders.", "doc.on.doc.fill"},
        {ui::Module::Uninstaller, "Uninstaller", "Apps together with leftover files.", "shippingbox.fill"},
        {ui::Module::Privacy, "Privacy", "Browser caches — you choose what goes.", "eye.slash.fill"},
        {ui::Module::Maintenance, "Maintenance", "Empty Trash, flush DNS, rebuild Launch Services.",
         "wrench.and.screwdriver.fill"},
    };
    for (auto& sp : specs) {
      DCDashCard* c = [[DCDashCard alloc] initWithFrame:NSZeroRect];
      c.module = sp.m;
      c.titleStr = [NSString stringWithUTF8String:sp.t];
      c.bodyStr = [NSString stringWithUTF8String:sp.b];
      c.symbol = [NSString stringWithUTF8String:sp.sy];
      __weak DCDashboardView* weak = self;
      c.onOpen = ^(ui::Module m) {
        if (weak.onOpen) weak.onOpen(m);
      };
      [_cards addObject:c];
      [self addSubview:c];
    }
    [self refreshStats];
  }
  return self;
}
- (BOOL)isFlipped {
  return YES;
}
- (void)refreshStats {
  dcmm::Engine e;
  auto d = e.disk("/");
  auto m = e.memory();
  double used = d.totalBytes ? 1.0 - (double)d.availableBytes / (double)d.totalBytes : 0;
  _ring.progress = used;
  _ring.centerText = DCNS(dcmm::formatBytes(d.availableBytes));
  _vol.stringValue = DCNS(d.volumeName.empty() ? "System Disk" : d.volumeName);
  _free.stringValue = [NSString stringWithFormat:@"%@ free", DCNS(dcmm::formatBytes(d.availableBytes))];
  _total.stringValue = [NSString
      stringWithFormat:@"%@ total  ·  %@ used", DCNS(dcmm::formatBytes(d.totalBytes)),
                       DCNS(dcmm::formatBytes(d.totalBytes > d.availableBytes ? d.totalBytes - d.availableBytes
                                                                             : 0))];
  _mem.stringValue = [NSString stringWithFormat:@"Memory  %@ used of %@",
                                                DCNS(dcmm::formatBytes(m.usedBytes)),
                                                DCNS(dcmm::formatBytes(m.totalBytes))];
}
- (void)layout {
  [super layout];
  NSRect b = self.bounds;
  CGFloat x = 8, w = b.size.width - 16;
  [self viewWithTag:1].frame = NSMakeRect(x, 8, w, 34);
  [self viewWithTag:2].frame = NSMakeRect(x, 44, w, 20);
  _diskCard.frame = NSMakeRect(x, 72, w, 200);
  _ring.frame = NSMakeRect(16, 16, 168, 168);
  _vol.frame = NSMakeRect(200, 28, w - 220, 22);
  _free.frame = NSMakeRect(200, 52, w - 220, 34);
  _total.frame = NSMakeRect(200, 92, w - 220, 20);
  _mem.frame = NSMakeRect(200, 116, w - 220, 20);
  _hint.frame = NSMakeRect(200, 148, w - 230, 36);
  CGFloat gridY = 292, gap = 14, cw = (w - gap) / 2.0, ch = 140;
  for (NSUInteger i = 0; i < _cards.count; ++i) {
    _cards[i].frame = NSMakeRect(x + (i % 2) * (cw + gap), gridY + (i / 2) * (ch + gap), cw, ch);
  }
}
@end

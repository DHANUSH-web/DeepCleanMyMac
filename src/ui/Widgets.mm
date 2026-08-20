#import "ui/Theme.h"

#include <algorithm>
#include <cmath>

@implementation DCButton {
  BOOL _hover;
}
@synthesize primary = _primary;
@synthesize destructive = _destructive;

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.bordered = NO;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 10;
    self.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    _primary = YES;
    [self refresh];
  }
  return self;
}
- (void)setPrimary:(BOOL)primary {
  _primary = primary;
  [self refresh];
}
- (void)setDestructive:(BOOL)destructive {
  _destructive = destructive;
  [self refresh];
}
- (void)setEnabled:(BOOL)enabled {
  [super setEnabled:enabled];
  [self refresh];
}
- (void)refresh {
  NSColor* bg;
  NSColor* fg;
  if (_destructive) {
    bg = th::danger();
    fg = [NSColor whiteColor];
  } else if (_primary) {
    bg = th::accent();
    fg = th::rgb(0.05, 0.12, 0.10);
  } else {
    bg = th::cardHi();
    fg = th::text();
  }
  if (!self.isEnabled) bg = [bg colorWithAlphaComponent:0.35];
  if (_hover && self.isEnabled) bg = [bg blendedColorWithFraction:0.12 ofColor:[NSColor whiteColor]];
  self.layer.backgroundColor = bg.CGColor;
  NSMutableAttributedString* a = [[NSMutableAttributedString alloc] initWithString:self.title ?: @""];
  [a addAttribute:NSForegroundColorAttributeName value:fg range:NSMakeRange(0, a.length)];
  [a addAttribute:NSFontAttributeName value:self.font range:NSMakeRange(0, a.length)];
  NSMutableParagraphStyle* p = [NSMutableParagraphStyle new];
  p.alignment = NSTextAlignmentCenter;
  [a addAttribute:NSParagraphStyleAttributeName value:p range:NSMakeRange(0, a.length)];
  self.attributedTitle = a;
}
- (void)setTitle:(NSString*)title {
  [super setTitle:title];
  [self refresh];
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
  _hover = YES;
  [self refresh];
}
- (void)mouseExited:(NSEvent*)event {
  _hover = NO;
  [self refresh];
}
- (void)resetCursorRects {
  [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
}
@end

@implementation DCRingView
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _progress = 0.4;
    _centerText = @"—";
    _ringColor = th::accent();
  }
  return self;
}
- (BOOL)isFlipped {
  return YES;
}
- (void)setProgress:(double)progress {
  _progress = std::max(0.0, std::min(1.0, progress));
  self.needsDisplay = YES;
}
- (void)setCenterText:(NSString*)centerText {
  _centerText = [centerText copy];
  self.needsDisplay = YES;
}
- (void)drawRect:(NSRect)dirty {
  NSRect b = self.bounds;
  CGFloat size = std::min(b.size.width, b.size.height) - 8;
  NSRect ring = NSMakeRect((b.size.width - size) / 2, 4, size, size);
  CGFloat w = 10;
  NSBezierPath* track = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(ring, w, w)];
  track.lineWidth = w;
  [th::rgb(1, 1, 1, 0.08) setStroke];
  [track stroke];
  NSPoint c = NSMakePoint(NSMidX(ring), NSMidY(ring));
  CGFloat r = (size / 2) - w;
  if (self.progress > 0.001) {
    NSBezierPath* val = [NSBezierPath bezierPath];
    val.lineWidth = w;
    val.lineCapStyle = NSLineCapStyleRound;
    [val appendBezierPathWithArcWithCenter:c
                                    radius:r
                                startAngle:90.0
                                  endAngle:90.0 - self.progress * 360.0
                                 clockwise:YES];
    [self.ringColor setStroke];
    [val stroke];
  }
  NSDictionary* attrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:size * 0.16 weight:NSFontWeightBold],
    NSForegroundColorAttributeName : th::text()
  };
  NSSize ts = [self.centerText sizeWithAttributes:attrs];
  [self.centerText drawAtPoint:NSMakePoint(c.x - ts.width / 2, c.y - ts.height / 2 - 4)
                withAttributes:attrs];
}
@end

NSTextField* DCLabel(NSString* text, NSFont* font, NSColor* color) {
  NSTextField* t = [NSTextField labelWithString:text ?: @""];
  t.font = font;
  t.textColor = color;
  t.backgroundColor = [NSColor clearColor];
  t.bordered = NO;
  t.editable = NO;
  t.selectable = NO;
  t.drawsBackground = NO;
  return t;
}

void DCRoundLayer(NSView* v, CGFloat radius, NSColor* fill, NSColor* border) {
  v.wantsLayer = YES;
  v.layer.cornerRadius = radius;
  v.layer.backgroundColor = fill.CGColor;
  if (border) {
    v.layer.borderColor = border.CGColor;
    v.layer.borderWidth = 1;
  }
}

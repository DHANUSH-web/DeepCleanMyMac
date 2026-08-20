#pragma once

#import <Cocoa/Cocoa.h>

#include <string>

inline NSString* DCNS(const std::string& s) {
  if (s.empty()) return @"";
  return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding] ?: @"";
}

namespace th {

inline NSColor* rgb(double r, double g, double b, double a = 1.0) {
  return [NSColor colorWithSRGBRed:r green:g blue:b alpha:a];
}
inline NSColor* bg() { return rgb(0.051, 0.063, 0.082); }
inline NSColor* sidebar() { return rgb(0.062, 0.074, 0.098); }
inline NSColor* card() { return rgb(0.098, 0.114, 0.149); }
inline NSColor* cardHi() { return rgb(0.122, 0.141, 0.184); }
inline NSColor* stroke() { return rgb(1, 1, 1, 0.08); }
inline NSColor* accent() { return rgb(0.239, 0.863, 0.592); }
inline NSColor* accentDim() { return rgb(0.239, 0.863, 0.592, 0.16); }
inline NSColor* danger() { return rgb(1.0, 0.361, 0.478); }
inline NSColor* warn() { return rgb(1.0, 0.757, 0.318); }
inline NSColor* text() { return rgb(0.910, 0.925, 0.945); }
inline NSColor* muted() { return rgb(0.545, 0.576, 0.655); }
inline NSColor* dim() { return rgb(0.373, 0.404, 0.478); }
inline NSFont* title() { return [NSFont systemFontOfSize:26 weight:NSFontWeightBold]; }
inline NSFont* heading() { return [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold]; }
inline NSFont* body() { return [NSFont systemFontOfSize:13 weight:NSFontWeightRegular]; }
inline NSFont* small() { return [NSFont systemFontOfSize:11 weight:NSFontWeightMedium]; }
inline NSFont* mono() { return [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightMedium]; }

}  // namespace th

@interface DCButton : NSButton
@property(nonatomic) BOOL primary;
@property(nonatomic) BOOL destructive;
@end

@interface DCRingView : NSView
@property(nonatomic) double progress;
@property(nonatomic, copy) NSString* centerText;
@property(nonatomic, strong) NSColor* ringColor;
@end

NSTextField* DCLabel(NSString* text, NSFont* font, NSColor* color);
void DCRoundLayer(NSView* v, CGFloat radius, NSColor* fill, NSColor* border);

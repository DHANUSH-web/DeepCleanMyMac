#import "ui/DashboardView.h"
#import "ui/Theme.h"

#include "AppFeatures.hpp"
#include "dcmm/dcmm.hpp"

#import <QuartzCore/QuartzCore.h>

namespace {

NSString* VolumeDisplayName() {
  NSURL* url = [NSURL fileURLWithPath:@"/"];
  NSString* name = nil;
  [url getResourceValue:&name forKey:NSURLVolumeNameKey error:nil];
  if (name.length) return name;
  return @"Macintosh HD";
}

void DCApplyFill(NSView* v, NSColor* color) {
  v.wantsLayer = YES;
  v.layer.backgroundColor = color.CGColor;
}

}  // namespace

@interface DCToolRowView : NSView
@property(nonatomic) ui::Module module;
@property(nonatomic, copy) void (^onOpen)(ui::Module);
@end

@implementation DCToolRowView {
  NSView* _well;
  NSImageView* _icon;
  NSTextField* _title;
  NSTextField* _sub;
  NSImageView* _chev;
  BOOL _hover;
}

- (instancetype)initWithTool:(const ui::DashboardTool&)tool {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _module = tool.module;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 8;

    _well = [[NSView alloc] initWithFrame:NSZeroRect];
    _well.translatesAutoresizingMaskIntoConstraints = NO;
    _well.wantsLayer = YES;
    _well.layer.cornerRadius = 7;
    [self addSubview:_well];

    _icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _icon.translatesAutoresizingMaskIntoConstraints = NO;
    _icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    NSImage* img =
        [NSImage imageWithSystemSymbolName:[NSString stringWithUTF8String:tool.symbol]
                  accessibilityDescription:[NSString stringWithUTF8String:tool.title]];
    img = [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13
                                                                                           weight:NSFontWeightMedium]];
    _icon.image = img;
    [_well addSubview:_icon];

    _title = DCLabel([NSString stringWithUTF8String:tool.title]);
    _title.translatesAutoresizingMaskIntoConstraints = NO;
    _title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [self addSubview:_title];

    _sub = DCCaptionLabel([NSString stringWithUTF8String:tool.subtitle]);
    _sub.translatesAutoresizingMaskIntoConstraints = NO;
    _sub.maximumNumberOfLines = 2;
    [self addSubview:_sub];

    _chev = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _chev.translatesAutoresizingMaskIntoConstraints = NO;
    _chev.image = [NSImage imageWithSystemSymbolName:@"chevron.right" accessibilityDescription:nil];
    _chev.contentTintColor = [NSColor tertiaryLabelColor];
    [self addSubview:_chev];

    [NSLayoutConstraint activateConstraints:@[
      [self.heightAnchor constraintEqualToConstant:52],
      [_well.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
      [_well.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_well.widthAnchor constraintEqualToConstant:28],
      [_well.heightAnchor constraintEqualToConstant:28],
      [_icon.centerXAnchor constraintEqualToAnchor:_well.centerXAnchor],
      [_icon.centerYAnchor constraintEqualToAnchor:_well.centerYAnchor],
      [_icon.widthAnchor constraintEqualToConstant:16],
      [_icon.heightAnchor constraintEqualToConstant:16],
      [_chev.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
      [_chev.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_chev.widthAnchor constraintEqualToConstant:8],
      [_title.leadingAnchor constraintEqualToAnchor:_well.trailingAnchor constant:10],
      [_title.trailingAnchor constraintEqualToAnchor:_chev.leadingAnchor constant:-8],
      [_title.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
      [_sub.leadingAnchor constraintEqualToAnchor:_title.leadingAnchor],
      [_sub.trailingAnchor constraintEqualToAnchor:_title.trailingAnchor],
      [_sub.topAnchor constraintEqualToAnchor:_title.bottomAnchor constant:1],
    ]];
    [self applyColors];
  }
  return self;
}

- (void)applyColors {
  DCApplyFill(_well, [[NSColor controlAccentColor] colorWithAlphaComponent:0.14]);
  _icon.contentTintColor = [NSColor controlAccentColor];
  DCApplyFill(self, _hover ? [NSColor unemphasizedSelectedContentBackgroundColor]
                           : [NSColor clearColor]);
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self applyColors];
}

- (void)updateTrackingAreas {
  [super updateTrackingAreas];
  for (NSTrackingArea* a in self.trackingAreas) [self removeTrackingArea:a];
  [self addTrackingArea:[[NSTrackingArea alloc]
                            initWithRect:self.bounds
                                 options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow |
                                         NSTrackingInVisibleRect
                                   owner:self
                                userInfo:nil]];
}

- (void)mouseEntered:(NSEvent*)event {
  _hover = YES;
  [self applyColors];
}

- (void)mouseExited:(NSEvent*)event {
  _hover = NO;
  [self applyColors];
}

- (void)mouseDown:(NSEvent*)event {
  if (self.onOpen) self.onOpen(self.module);
}

- (void)resetCursorRects {
  [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
}

@end

@implementation DCDashboardView {
  NSTextField* _volumeTitle;
  NSTextField* _capacityLine;
  NSTextField* _availableLine;
  NSProgressIndicator* _bar;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSStackView* column = [NSStackView stackViewWithViews:@[]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.distribution = NSStackViewDistributionFill;
    column.spacing = 18;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:column];
    NSLayoutConstraint* preferred = [column.widthAnchor constraintEqualToConstant:480];
    preferred.priority = 749;
    [NSLayoutConstraint activateConstraints:@[
      [column.topAnchor constraintEqualToAnchor:self.topAnchor constant:24],
      [column.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:28],
      [column.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-24],
      preferred,
      [column.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-56],
      [column.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-28],
    ]];

    NSStackView* header = DCHeaderStack(
        @"Overview", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Overview)]);
    [column addArrangedSubview:header];
    [header.widthAnchor constraintEqualToAnchor:column.widthAnchor].active = YES;

    NSImageView* diskIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    diskIcon.image = [NSImage imageWithSystemSymbolName:@"internaldrive.fill"
                               accessibilityDescription:@"Disk"];
    diskIcon.contentTintColor = [NSColor controlAccentColor];
    diskIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [diskIcon.widthAnchor constraintEqualToConstant:28].active = YES;
    [diskIcon.heightAnchor constraintEqualToConstant:28].active = YES;

    _volumeTitle = DCLabel(@"—");
    _volumeTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    _capacityLine = DCCaptionLabel(@"—");
    NSStackView* volText = [NSStackView stackViewWithViews:@[ _volumeTitle, _capacityLine ]];
    volText.orientation = NSUserInterfaceLayoutOrientationVertical;
    volText.alignment = NSLayoutAttributeLeading;
    volText.spacing = 1;
    NSStackView* volRow = [NSStackView stackViewWithViews:@[ diskIcon, volText ]];
    volRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    volRow.alignment = NSLayoutAttributeCenterY;
    volRow.spacing = 10;

    _bar = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    _bar.style = NSProgressIndicatorStyleBar;
    _bar.indeterminate = NO;
    _bar.minValue = 0;
    _bar.maxValue = 1;
    _bar.controlSize = NSControlSizeSmall;
    _bar.translatesAutoresizingMaskIntoConstraints = NO;
    [_bar.widthAnchor constraintEqualToConstant:220].active = YES;
    [_bar.heightAnchor constraintEqualToConstant:8].active = YES;
    [_bar setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationHorizontal];

    _availableLine = DCCaptionLabel(@"—");
    NSStackView* barRow = [NSStackView stackViewWithViews:@[ _bar, _availableLine ]];
    barRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    barRow.alignment = NSLayoutAttributeCenterY;
    barRow.spacing = 10;

    NSStackView* cardBody = [NSStackView stackViewWithViews:@[ volRow, barRow ]];
    cardBody.orientation = NSUserInterfaceLayoutOrientationVertical;
    cardBody.alignment = NSLayoutAttributeLeading;
    cardBody.spacing = 10;
    cardBody.edgeInsets = NSEdgeInsetsMake(14, 14, 14, 14);

    NSVisualEffectView* card = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    card.material = NSVisualEffectMaterialContentBackground;
    card.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    card.state = NSVisualEffectStateFollowsWindowActiveState;
    card.wantsLayer = YES;
    card.layer.cornerRadius = 10;
    card.layer.masksToBounds = YES;
    [card addSubview:cardBody];
    DCPinEdges(cardBody, card);
    [card setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];
    [column addArrangedSubview:card];
    [card.widthAnchor constraintEqualToAnchor:column.widthAnchor].active = YES;

    NSTextField* hint = DCCaptionLabel(
        @"Grant Full Disk Access in System Settings → Privacy & Security for a deeper scan.");
    [column addArrangedSubview:hint];
    [hint.widthAnchor constraintEqualToAnchor:column.widthAnchor].active = YES;

    NSTextField* toolsLabel = DCLabel(@"Tools");
    toolsLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [column addArrangedSubview:toolsLabel];

    NSStackView* toolList = [NSStackView stackViewWithViews:@[]];
    toolList.orientation = NSUserInterfaceLayoutOrientationVertical;
    toolList.alignment = NSLayoutAttributeLeading;
    toolList.spacing = 2;
    toolList.edgeInsets = NSEdgeInsetsMake(6, 4, 6, 4);
    __weak DCDashboardView* weakSelf = self;
    for (const auto& tool : ui::dashboardTools()) {
      DCToolRowView* row = [[DCToolRowView alloc] initWithTool:tool];
      row.onOpen = ^(ui::Module m) {
        DCDashboardView* s = weakSelf;
        if (s.onOpen) s.onOpen(m);
      };
      [toolList addArrangedSubview:row];
      [row.widthAnchor constraintEqualToAnchor:toolList.widthAnchor
                                      constant:-(toolList.edgeInsets.left + toolList.edgeInsets.right)]
          .active = YES;
    }

    NSVisualEffectView* toolsCard = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    toolsCard.material = NSVisualEffectMaterialContentBackground;
    toolsCard.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    toolsCard.state = NSVisualEffectStateFollowsWindowActiveState;
    toolsCard.wantsLayer = YES;
    toolsCard.layer.cornerRadius = 10;
    toolsCard.layer.masksToBounds = YES;
    [toolsCard addSubview:toolList];
    DCPinEdges(toolList, toolsCard);
    [column addArrangedSubview:toolsCard];
    [toolsCard.widthAnchor constraintEqualToAnchor:column.widthAnchor].active = YES;

    [self refreshStats];
  }
  return self;
}

- (void)refreshStats {
  dcmm::Engine e;
  auto d = e.disk("/");
  double used = d.totalBytes ? 1.0 - (double)d.availableBytes / (double)d.totalBytes : 0;
  _bar.doubleValue = used;
  _volumeTitle.stringValue = VolumeDisplayName();
  uint64_t usedBytes = d.totalBytes > d.availableBytes ? d.totalBytes - d.availableBytes : 0;
  _capacityLine.stringValue =
      [NSString stringWithFormat:@"%@ of %@ used", DCNS(dcmm::formatBytes(usedBytes)),
                                 DCNS(dcmm::formatBytes(d.totalBytes))];
  _availableLine.stringValue =
      [NSString stringWithFormat:@"%@ available", DCNS(dcmm::formatBytes(d.availableBytes))];
}

@end

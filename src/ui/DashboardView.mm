#import "ui/DashboardView.h"
#import "ui/Theme.h"

#include "AppFeatures.hpp"
#include "SystemInfo.hpp"
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

@interface DCFlippedDoc : NSView
@end
@implementation DCFlippedDoc
- (BOOL)isFlipped {
  return YES;
}
@end

namespace {

NSStackView* DCFactRow(NSString* label, NSString* value) {
  NSTextField* l = DCCaptionLabel(label);
  l.font = [NSFont systemFontOfSize:12];
  l.alignment = NSTextAlignmentRight;
  [l.widthAnchor constraintEqualToConstant:96].active = YES;
  [l setContentHuggingPriority:NSLayoutPriorityRequired
                forOrientation:NSLayoutConstraintOrientationHorizontal];
  [l setContentCompressionResistancePriority:NSLayoutPriorityRequired
                              forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSTextField* v = DCLabel(value);
  v.font = [NSFont systemFontOfSize:12];
  v.selectable = YES;
  v.lineBreakMode = NSLineBreakByTruncatingMiddle;
  NSStackView* row = [NSStackView stackViewWithViews:@[ l, v ]];
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeFirstBaseline;
  row.spacing = 10;
  [row setContentHuggingPriority:NSLayoutPriorityRequired
                  forOrientation:NSLayoutConstraintOrientationVertical];
  return row;
}

void DCSetFacts(NSStackView* stack, const std::vector<std::pair<std::string, std::string>>& facts) {
  NSArray<NSView*>* old = [stack.arrangedSubviews copy];
  for (NSView* v in old) {
    [stack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  for (const auto& f : facts) [stack addArrangedSubview:DCFactRow(DCNS(f.first), DCNS(f.second))];
}

NSVisualEffectView* DCOverviewCard(NSView* body) {
  body.translatesAutoresizingMaskIntoConstraints = NO;
  NSVisualEffectView* card = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
  card.material = NSVisualEffectMaterialContentBackground;
  card.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  card.state = NSVisualEffectStateFollowsWindowActiveState;
  card.wantsLayer = YES;
  card.layer.cornerRadius = 10;
  card.layer.masksToBounds = YES;
  [card addSubview:body];
  DCPinEdges(body, card);
  [card setContentHuggingPriority:NSLayoutPriorityRequired
                   forOrientation:NSLayoutConstraintOrientationVertical];
  return card;
}

NSImageView* DCCardSymbol(NSString* name, NSString* a11y) {
  NSImageView* icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  icon.image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:a11y];
  icon.contentTintColor = [NSColor controlAccentColor];
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  [icon.widthAnchor constraintEqualToConstant:28].active = YES;
  [icon.heightAnchor constraintEqualToConstant:28].active = YES;
  return icon;
}

}  // namespace

@implementation DCDashboardView {
  NSScrollView* _scroll;
  DCFlippedDoc* _doc;
  NSStackView* _column;
  NSTextField* _machineTitle;
  NSTextField* _machineSub;
  NSStackView* _machineFacts;
  NSTextField* _volumeTitle;
  NSTextField* _capacityLine;
  NSTextField* _availableLine;
  NSProgressIndicator* _bar;
  NSStackView* _storageFacts;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _scroll.drawsBackground = NO;
    _scroll.hasVerticalScroller = YES;
    _scroll.hasHorizontalScroller = NO;
    _scroll.autohidesScrollers = YES;
    _scroll.borderType = NSNoBorder;
    _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_scroll];
    DCPinEdges(_scroll, self);

    _doc = [[DCFlippedDoc alloc] initWithFrame:NSZeroRect];
    _column = [NSStackView stackViewWithViews:@[]];
    _column.orientation = NSUserInterfaceLayoutOrientationVertical;
    _column.alignment = NSLayoutAttributeLeading;
    _column.distribution = NSStackViewDistributionFill;
    _column.spacing = 18;
    _column.edgeInsets = NSEdgeInsetsMake(24, 28, 24, 28);
    _column.translatesAutoresizingMaskIntoConstraints = NO;
    [_doc addSubview:_column];
    [NSLayoutConstraint activateConstraints:@[
      [_column.topAnchor constraintEqualToAnchor:_doc.topAnchor],
      [_column.leadingAnchor constraintEqualToAnchor:_doc.leadingAnchor],
      [_column.trailingAnchor constraintEqualToAnchor:_doc.trailingAnchor],
      [_column.bottomAnchor constraintEqualToAnchor:_doc.bottomAnchor],
    ]];
    _scroll.documentView = _doc;

    NSStackView* header = DCHeaderStack(
        @"Overview", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Overview)]);
    [_column addArrangedSubview:header];
    DCStackFullWidth(_column, header);

    NSImageView* macIcon = DCCardSymbol(@"laptopcomputer", @"This Mac");
    _machineTitle = DCLabel(@"—");
    _machineTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    _machineSub = DCCaptionLabel(@"—");
    NSStackView* macText = [NSStackView stackViewWithViews:@[ _machineTitle, _machineSub ]];
    macText.orientation = NSUserInterfaceLayoutOrientationVertical;
    macText.alignment = NSLayoutAttributeLeading;
    macText.spacing = 1;
    NSStackView* macRow = [NSStackView stackViewWithViews:@[ macIcon, macText ]];
    macRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    macRow.alignment = NSLayoutAttributeCenterY;
    macRow.spacing = 10;

    _machineFacts = [NSStackView stackViewWithViews:@[]];
    _machineFacts.orientation = NSUserInterfaceLayoutOrientationVertical;
    _machineFacts.alignment = NSLayoutAttributeLeading;
    _machineFacts.spacing = 5;

    NSStackView* macBody = [NSStackView stackViewWithViews:@[ macRow, _machineFacts ]];
    macBody.orientation = NSUserInterfaceLayoutOrientationVertical;
    macBody.alignment = NSLayoutAttributeLeading;
    macBody.spacing = 10;
    macBody.edgeInsets = NSEdgeInsetsMake(14, 14, 14, 14);
    NSVisualEffectView* macCard = DCOverviewCard(macBody);
    [_column addArrangedSubview:macCard];
    DCStackFullWidth(_column, macCard);
    [_machineFacts.widthAnchor constraintEqualToAnchor:macBody.widthAnchor
                                              constant:-(macBody.edgeInsets.left + macBody.edgeInsets.right)]
        .active = YES;

    NSImageView* diskIcon = DCCardSymbol(@"internaldrive.fill", @"Disk");
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
    [_bar.heightAnchor constraintEqualToConstant:8].active = YES;

    _availableLine = DCCaptionLabel(@"—");
    NSStackView* barRow = [NSStackView stackViewWithViews:@[ _bar, _availableLine ]];
    barRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    barRow.alignment = NSLayoutAttributeCenterY;
    barRow.spacing = 10;
    [_bar setContentHuggingPriority:1
                     forOrientation:NSLayoutConstraintOrientationHorizontal];

    _storageFacts = [NSStackView stackViewWithViews:@[]];
    _storageFacts.orientation = NSUserInterfaceLayoutOrientationVertical;
    _storageFacts.alignment = NSLayoutAttributeLeading;
    _storageFacts.spacing = 5;

    NSStackView* diskBody = [NSStackView stackViewWithViews:@[ volRow, barRow, _storageFacts ]];
    diskBody.orientation = NSUserInterfaceLayoutOrientationVertical;
    diskBody.alignment = NSLayoutAttributeLeading;
    diskBody.spacing = 10;
    diskBody.edgeInsets = NSEdgeInsetsMake(14, 14, 14, 14);
    NSVisualEffectView* diskCard = DCOverviewCard(diskBody);
    [_column addArrangedSubview:diskCard];
    DCStackFullWidth(_column, diskCard);
    [_storageFacts.widthAnchor constraintEqualToAnchor:diskBody.widthAnchor
                                              constant:-(diskBody.edgeInsets.left + diskBody.edgeInsets.right)]
        .active = YES;
    [barRow.widthAnchor constraintEqualToAnchor:_storageFacts.widthAnchor].active = YES;

    NSTextField* hint = DCCaptionLabel(
        @"Grant Full Disk Access in System Settings → Privacy & Security for a deeper scan.");
    [_column addArrangedSubview:hint];
    DCStackFullWidth(_column, hint);

    NSTextField* toolsLabel = DCLabel(@"Tools");
    toolsLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [_column addArrangedSubview:toolsLabel];

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

    NSVisualEffectView* toolsCard = DCOverviewCard(toolList);
    [_column addArrangedSubview:toolsCard];
    DCStackFullWidth(_column, toolsCard);

    [self refreshStats];
  }
  return self;
}

- (void)layout {
  [super layout];
  CGFloat w = NSWidth(_scroll.contentView.bounds);
  if (w < 1) return;
  CGFloat h = MAX(_column.fittingSize.height, 1);
  _doc.frame = NSMakeRect(0, 0, w, h);
}

- (void)refreshStats {
  ui::HostInfo host = ui::hostInfo();
  ui::VolumeInfo vol = ui::volumeInfo("/");

  _machineTitle.stringValue =
      host.computerName.empty() ? @"This Mac" : DCNS(host.computerName);
  NSString* model = host.modelName.empty() ? DCNS(host.modelId) : DCNS(host.modelName);
  _machineSub.stringValue = model.length ? model : @"Mac";
  DCSetFacts(_machineFacts, ui::machineFacts(host));

  _volumeTitle.stringValue =
      vol.volumeName.empty() ? VolumeDisplayName() : DCNS(vol.volumeName);
  uint64_t avail = vol.importantAvailableBytes ? vol.importantAvailableBytes : vol.availableBytes;
  uint64_t total = vol.totalBytes;
  uint64_t usedBytes = total > avail ? total - avail : 0;
  _bar.doubleValue = total ? (double)usedBytes / (double)total : 0;
  _capacityLine.stringValue =
      [NSString stringWithFormat:@"%@ of %@ used", DCNS(dcmm::formatBytes(usedBytes)),
                                 DCNS(dcmm::formatBytes(total))];
  _availableLine.stringValue =
      [NSString stringWithFormat:@"%@ available", DCNS(dcmm::formatBytes(avail))];
  DCSetFacts(_storageFacts, ui::storageFacts(vol));
  [self setNeedsLayout:YES];
}

@end

#import "ui/DashboardView.h"
#import "ui/Theme.h"

#include "AppFeatures.hpp"
#include "SystemInfo.hpp"
#include "dcmm/dcmm.hpp"

#import <LocalAuthentication/LocalAuthentication.h>
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
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
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

@interface DCSerialFactCard : NSVisualEffectView
- (instancetype)initWithSerial:(NSString*)serial;
@end

@implementation DCSerialFactCard {
  NSTextField* _value;
  NSString* _secret;
  BOOL _revealed;
  BOOL _busy;
}

- (instancetype)initWithSerial:(NSString*)serial {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _secret = [serial copy];
    self.material = NSVisualEffectMaterialContentBackground;
    self.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    self.state = NSVisualEffectStateFollowsWindowActiveState;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 10;
    self.layer.masksToBounds = YES;
    [self setContentHuggingPriority:NSLayoutPriorityDefaultLow
                     forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];

    NSTextField* l = DCCaptionLabel(@"Serial Number");
    l.font = [NSFont systemFontOfSize:11];
    _value = DCLabel(@(ui::kMaskedSerial));
    _value.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightSemibold];
    _value.selectable = NO;
    NSStackView* body = [NSStackView stackViewWithViews:@[ l, _value ]];
    body.orientation = NSUserInterfaceLayoutOrientationVertical;
    body.alignment = NSLayoutAttributeLeading;
    body.spacing = 2;
    body.edgeInsets = NSEdgeInsetsMake(10, 12, 10, 12);
    [self addSubview:body];
    DCPinEdges(body, self);
    self.toolTip = @"Click to reveal with Touch ID or your password.";
    self.accessibilityRole = NSAccessibilityButtonRole;
    self.accessibilityLabel = @"Serial number, hidden. Click to reveal with Touch ID.";
  }
  return self;
}

- (void)resetCursorRects {
  if (!_revealed) [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
}

- (void)mouseUp:(NSEvent*)event {
  NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
  if (!NSPointInRect(p, self.bounds)) return;
  if (_revealed || _busy || _secret.length == 0) return;
  [self revealAfterAuth];
}

- (BOOL)accessibilityPerformPress {
  if (_revealed || _busy || _secret.length == 0) return NO;
  [self revealAfterAuth];
  return YES;
}

- (void)revealAfterAuth {
  LAContext* ctx = [[LAContext alloc] init];
  NSError* err = nil;
  if (![ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&err]) return;
  _busy = YES;
  __weak DCSerialFactCard* weakSelf = self;
  [ctx evaluatePolicy:LAPolicyDeviceOwnerAuthentication
      localizedReason:@"Reveal the Mac serial number."
                reply:^(BOOL success, NSError* error) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    DCSerialFactCard* s = weakSelf;
                    if (!s) return;
                    s->_busy = NO;
                    if (!success) return;
                    s->_revealed = YES;
                    s->_value.stringValue = s->_secret;
                    s->_value.selectable = YES;
                    s.toolTip = nil;
                    s.accessibilityRole = NSAccessibilityGroupRole;
                    s.accessibilityLabel = @"Serial number";
                    [s.window invalidateCursorRectsForView:s];
                  });
                }];
}

@end

namespace {

NSVisualEffectView* DCMyMacCard(NSView* body) {
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

NSView* DCMiniFactCard(NSString* label, NSString* value) {
  NSTextField* l = DCCaptionLabel(label);
  l.font = [NSFont systemFontOfSize:11];
  NSTextField* v = DCLabel(value);
  v.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  v.selectable = YES;
  v.maximumNumberOfLines = 3;
  v.lineBreakMode = NSLineBreakByWordWrapping;
  NSStackView* body = [NSStackView stackViewWithViews:@[ l, v ]];
  body.orientation = NSUserInterfaceLayoutOrientationVertical;
  body.alignment = NSLayoutAttributeLeading;
  body.spacing = 2;
  body.edgeInsets = NSEdgeInsetsMake(10, 12, 10, 12);
  NSVisualEffectView* card = DCMyMacCard(body);
  [card setContentHuggingPriority:NSLayoutPriorityDefaultLow
                   forOrientation:NSLayoutConstraintOrientationHorizontal];
  return card;
}

void DCClearStack(NSStackView* stack) {
  NSArray<NSView*>* old = [stack.arrangedSubviews copy];
  for (NSView* v in old) {
    [stack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
}

NSView* DCFactCard(const std::pair<std::string, std::string>& fact) {
  if (fact.first == "Serial Number")
    return [[DCSerialFactCard alloc] initWithSerial:DCNS(fact.second)];
  return DCMiniFactCard(DCNS(fact.first), DCNS(fact.second));
}

void DCSetFactCards(NSStackView* stack,
                    const std::vector<std::pair<std::string, std::string>>& facts) {
  DCClearStack(stack);
  for (size_t i = 0; i < facts.size();) {
    NSMutableArray<NSView*>* views = [NSMutableArray array];
    [views addObject:DCFactCard(facts[i])];
    ++i;
    if (i < facts.size()) {
      [views addObject:DCFactCard(facts[i])];
      ++i;
    } else {
      [views addObject:[[NSView alloc] initWithFrame:NSZeroRect]];
    }
    NSStackView* row = [NSStackView stackViewWithViews:views];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeTop;
    row.distribution = NSStackViewDistributionFillEqually;
    row.spacing = 8;
    [stack addArrangedSubview:row];
    [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
  }
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
    _scroll.automaticallyAdjustsContentInsets = NO;
    _scroll.contentInsets = NSEdgeInsetsZero;
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
        @"My Mac", [NSString stringWithUTF8String:ui::subtitle(ui::Module::MyMac)]);
    [_column addArrangedSubview:header];
    DCStackFullWidth(_column, header);

    NSImage* macSymbol = [NSImage imageWithSystemSymbolName:@"macbook" accessibilityDescription:@"MacBook"];
    if (!macSymbol)
      macSymbol = [NSImage imageWithSystemSymbolName:@"laptopcomputer" accessibilityDescription:@"MacBook"];
    macSymbol = [macSymbol imageWithSymbolConfiguration:[NSImageSymbolConfiguration
                                                            configurationWithPointSize:32
                                                                                weight:NSFontWeightRegular
                                                                                 scale:NSImageSymbolScaleMedium]];
    NSImageView* macIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    macIcon.image = macSymbol;
    macIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    macIcon.contentTintColor = NSColor.labelColor;
    macIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [macIcon.widthAnchor constraintEqualToConstant:128].active = YES;
    [macIcon.heightAnchor constraintEqualToConstant:128].active = YES;
    NSView* macIconRow = [[NSView alloc] initWithFrame:NSZeroRect];
    macIconRow.translatesAutoresizingMaskIntoConstraints = NO;
    [macIconRow addSubview:macIcon];
    [NSLayoutConstraint activateConstraints:@[
      [macIcon.centerXAnchor constraintEqualToAnchor:macIconRow.centerXAnchor],
      [macIcon.topAnchor constraintEqualToAnchor:macIconRow.topAnchor],
      [macIcon.bottomAnchor constraintEqualToAnchor:macIconRow.bottomAnchor],
    ]];
    [_column addArrangedSubview:macIconRow];
    DCStackFullWidth(_column, macIconRow);

    _machineFacts = [NSStackView stackViewWithViews:@[]];
    _machineFacts.orientation = NSUserInterfaceLayoutOrientationVertical;
    _machineFacts.alignment = NSLayoutAttributeLeading;
    _machineFacts.spacing = 8;
    [_column addArrangedSubview:_machineFacts];
    DCStackFullWidth(_column, _machineFacts);

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

    NSStackView* usageBody = [NSStackView stackViewWithViews:@[ volRow, barRow ]];
    usageBody.orientation = NSUserInterfaceLayoutOrientationVertical;
    usageBody.alignment = NSLayoutAttributeLeading;
    usageBody.spacing = 10;
    usageBody.edgeInsets = NSEdgeInsetsMake(12, 12, 12, 12);
    NSVisualEffectView* usageCard = DCMyMacCard(usageBody);
    [_column addArrangedSubview:usageCard];
    DCStackFullWidth(_column, usageCard);
    [barRow.widthAnchor constraintEqualToAnchor:usageBody.widthAnchor
                                       constant:-(usageBody.edgeInsets.left + usageBody.edgeInsets.right)]
        .active = YES;

    _storageFacts = [NSStackView stackViewWithViews:@[]];
    _storageFacts.orientation = NSUserInterfaceLayoutOrientationVertical;
    _storageFacts.alignment = NSLayoutAttributeLeading;
    _storageFacts.spacing = 8;
    [_column addArrangedSubview:_storageFacts];
    DCStackFullWidth(_column, _storageFacts);

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

    NSVisualEffectView* toolsCard = DCMyMacCard(toolList);
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

  auto mac = ui::machineFacts(host);
  if (!host.modelName.empty()) mac.insert(mac.begin(), {"Mac", host.modelName});
  if (!host.computerName.empty()) mac.insert(mac.begin(), {"Name", host.computerName});
  DCSetFactCards(_machineFacts, mac);

  _volumeTitle.stringValue =
      vol.volumeName.empty() ? VolumeDisplayName() : DCNS(vol.volumeName);
  uint64_t avail = vol.importantAvailableBytes ? vol.importantAvailableBytes : vol.availableBytes;
  uint64_t total = vol.totalBytes;
  uint64_t usedBytes = total > avail ? total - avail : 0;
  _bar.doubleValue = total ? (double)usedBytes / (double)total : 0;
  _capacityLine.stringValue =
      [NSString stringWithFormat:@"%@ of %@ used", DCNS(ui::formatDiskBytes(usedBytes)),
                                 DCNS(ui::formatDiskBytes(total))];
  _availableLine.stringValue =
      [NSString stringWithFormat:@"%@ available", DCNS(ui::formatDiskBytes(avail))];
  DCSetFactCards(_storageFacts, ui::storageFacts(vol));
  [self setNeedsLayout:YES];
}

@end

#import "ui/DevCornerView.h"
#import "ui/Theme.h"

#import <objc/runtime.h>

#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"

#include <tuple>
#include <vector>

static char kDCDevUninstallRowKey;
static char kDCDevCheckRowKey;

typedef NS_ENUM(NSInteger, DCDevKind) { DCDevKindApp, DCDevKindFolder, DCDevKindExtension };

@interface DCDevRow : NSObject
@property(nonatomic) DCDevKind kind;
@property(nonatomic, copy) NSString* title;
@property(nonatomic, copy) NSString* path;
@property(nonatomic, copy) NSString* appPath;
@property(nonatomic, copy) NSString* iconPath;
@property(nonatomic) uint64_t bytes;
@property(nonatomic) dcmm::VsCodeEdition edition;
@property(nonatomic) BOOL cursorApp;
@property(nonatomic) BOOL extensions;
@property(nonatomic) BOOL selected;
@property(nonatomic) BOOL loaded;
@property(nonatomic) BOOL loading;
@property(nonatomic, strong) NSMutableArray<DCDevRow*>* children;
@property(nonatomic, weak) DCDevRow* parent;
@end

@implementation DCDevRow
- (instancetype)init {
  self = [super init];
  if (self) _children = [NSMutableArray array];
  return self;
}
@end

@interface DCDevFlippedDoc : NSView
@end
@implementation DCDevFlippedDoc
- (BOOL)isFlipped {
  return YES;
}
@end

static void DCDevClearStack(NSStackView* stack) {
  NSArray<NSView*>* old = [stack.arrangedSubviews copy];
  for (NSView* v in old) {
    [stack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
}

static NSVisualEffectView* DCDevWrapCard(NSView* body, CGFloat radius) {
  body.translatesAutoresizingMaskIntoConstraints = NO;
  NSVisualEffectView* card = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
  card.material = NSVisualEffectMaterialContentBackground;
  card.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  card.state = NSVisualEffectStateFollowsWindowActiveState;
  card.wantsLayer = YES;
  card.layer.cornerRadius = radius;
  card.layer.masksToBounds = YES;
  card.translatesAutoresizingMaskIntoConstraints = NO;
  [card addSubview:body];
  DCPinEdges(body, card);
  [card setContentHuggingPriority:NSLayoutPriorityRequired
                   forOrientation:NSLayoutConstraintOrientationVertical];
  [card setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                 forOrientation:NSLayoutConstraintOrientationVertical];
  return card;
}

static NSImageView* DCDevAppIcon(NSString* appPath, CGFloat size) {
  NSImageView* icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  NSImage* img = nil;
  if (appPath.length) img = [[[NSWorkspace sharedWorkspace] iconForFile:appPath] copy];
  if (!img) img = [NSImage imageWithSystemSymbolName:@"app" accessibilityDescription:nil];
  img.size = NSMakeSize(size, size);
  icon.image = img;
  icon.imageScaling = NSImageScaleProportionallyUpOrDown;
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  [icon.widthAnchor constraintEqualToConstant:size].active = YES;
  [icon.heightAnchor constraintEqualToConstant:size].active = YES;
  return icon;
}

static NSImage* DCDevExtensionImage(NSString* iconPath) {
  NSImage* img = nil;
  if (iconPath.length) img = [[NSImage alloc] initWithContentsOfFile:iconPath];
  if (img) return img;
  NSImage* symbol =
      [NSImage imageWithSystemSymbolName:@"puzzlepiece.extension.fill" accessibilityDescription:nil];
  if (symbol) {
    return [symbol imageWithSymbolConfiguration:[NSImageSymbolConfiguration
                                                    configurationWithPointSize:28
                                                                        weight:NSFontWeightRegular
                                                                         scale:NSImageSymbolScaleMedium]];
  }
  img = [[NSImage alloc] initWithSize:NSMakeSize(28, 28)];
  [img lockFocus];
  [@"📦" drawInRect:NSMakeRect(0, 0, 28, 28)
      withAttributes:@{NSFontAttributeName : [NSFont systemFontOfSize:20]}];
  [img unlockFocus];
  return img;
}

static NSColor* DCDevSizeTint(uint64_t bytes) {
  if (bytes >= ui::kSpaceTooBigBytes) return NSColor.systemRedColor;
  if (bytes >= ui::kSpaceBigBytes) return NSColor.systemOrangeColor;
  return nil;
}

@interface DCDevSizeBadge : NSView
- (instancetype)initWithBytes:(uint64_t)bytes;
- (void)setBytes:(uint64_t)bytes;
@end

@implementation DCDevSizeBadge {
  NSTextField* _label;
  uint64_t _bytes;
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (void)updateLayer {
  NSAppearanceName match =
      [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameDarkAqua ]];
  const BOOL dark = [match isEqualToString:NSAppearanceNameDarkAqua];
  NSColor* tint = DCDevSizeTint(_bytes);
  if (tint) {
    self.layer.backgroundColor = [tint colorWithAlphaComponent:dark ? 0.22 : 0.12].CGColor;
    _label.textColor = tint;
  } else {
    self.layer.backgroundColor =
        [[NSColor labelColor] colorWithAlphaComponent:dark ? 0.10 : 0.06].CGColor;
    _label.textColor = NSColor.secondaryLabelColor;
  }
  self.layer.cornerRadius = MAX(NSHeight(self.bounds) / 2.0, 8);
  self.layer.masksToBounds = YES;
}

- (instancetype)initWithBytes:(uint64_t)bytes {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    self.wantsLayer = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    _label = DCLabel(@"");
    _label.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
    _label.alignment = NSTextAlignmentCenter;
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_label];
    [NSLayoutConstraint activateConstraints:@[
      [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:7],
      [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-7],
      [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:2],
      [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
    ]];
    [self setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];
    [self setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                   forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self setBytes:bytes];
  }
  return self;
}

- (void)setBytes:(uint64_t)bytes {
  _bytes = bytes;
  _label.stringValue = DCNS(dcmm::formatBytes(bytes));
  [self setNeedsDisplay:YES];
}

@end

@interface DCDevExtensionCard : NSView
- (instancetype)initWithRow:(DCDevRow*)row;
@end

@implementation DCDevExtensionCard

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (void)updateLayer {
  self.layer.cornerRadius = 8;
  self.layer.masksToBounds = YES;
  self.layer.borderWidth = 1;
  self.layer.borderColor = NSColor.separatorColor.CGColor;
  NSAppearanceName match =
      [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameDarkAqua ]];
  const BOOL dark = [match isEqualToString:NSAppearanceNameDarkAqua];
  self.layer.backgroundColor = [[NSColor labelColor] colorWithAlphaComponent:dark ? 0.10 : 0.05].CGColor;
}

- (instancetype)initWithRow:(DCDevRow*)row {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    self.wantsLayer = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    NSImageView* icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.image = DCDevExtensionImage(row.iconPath);
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon.widthAnchor constraintEqualToConstant:36].active = YES;
    [icon.heightAnchor constraintEqualToConstant:36].active = YES;

    NSTextField* name = DCLabel(row.title.length ? row.title : row.path.lastPathComponent);
    name.font = [NSFont systemFontOfSize:11];
    name.alignment = NSTextAlignmentCenter;
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    name.usesSingleLineMode = YES;
    name.maximumNumberOfLines = 1;
    name.preferredMaxLayoutWidth = 70;
    [name setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [name setContentCompressionResistancePriority:1
                                   forOrientation:NSLayoutConstraintOrientationHorizontal];

    DCDevSizeBadge* size = [[DCDevSizeBadge alloc] initWithBytes:row.bytes];

    NSStackView* line = [NSStackView stackViewWithViews:@[ name, size ]];
    line.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    line.alignment = NSLayoutAttributeCenterY;
    line.spacing = 4;

    NSStackView* col = [NSStackView stackViewWithViews:@[ icon, line ]];
    col.orientation = NSUserInterfaceLayoutOrientationVertical;
    col.alignment = NSLayoutAttributeCenterX;
    col.spacing = 8;
    col.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:col];
    [NSLayoutConstraint activateConstraints:@[
      [col.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
      [col.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [col.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:8],
      [col.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-8],
      [col.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:8],
      [col.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-8],
    ]];
    [self.widthAnchor constraintEqualToConstant:128].active = YES;
    [self.heightAnchor constraintEqualToConstant:100].active = YES;
    NSString* title = row.title.length ? row.title : row.path.lastPathComponent;
    if (title.length) [DCHoverPopover attachToView:self rows:@[ @[ @"Name", title ] ]];
  }
  return self;
}

@end

@interface DCDevVsCodeCard : NSView
@property(nonatomic) BOOL uninstallEnabled;
@property(nonatomic, readonly) DCDevRow* appRow;
- (instancetype)initWithApp:(DCDevRow*)app target:(id)target tog:(SEL)tog uninstall:(SEL)uninstall;
- (DCDevRow*)extensionsFolder;
- (void)reloadCarousel;
@end

@implementation DCDevVsCodeCard {
  DCDevRow* _app;
  NSButton* _uninstall;
  DCDevSizeBadge* _extSize;
  NSStackView* _extStrip;
  NSScrollView* _extScroll;
  NSView* _extBlock;
  NSStackView* _leftovers;
  NSView* _leftoverBlock;
}

- (DCDevRow*)extensionsFolder {
  for (DCDevRow* r in _app.children)
    if (r.extensions) return r;
  return nil;
}

- (instancetype)initWithApp:(DCDevRow*)app
                     target:(id)target
                        tog:(SEL)tog
                  uninstall:(SEL)uninstall {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _app = app;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    NSImageView* icon = DCDevAppIcon(app.appPath, 32);
    NSTextField* name = DCLabel(app.title);
    name.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    name.usesSingleLineMode = YES;
    [name setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [name setContentCompressionResistancePriority:1
                                   forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* identity = [NSStackView stackViewWithViews:@[ icon, name ]];
    identity.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    identity.alignment = NSLayoutAttributeCenterY;
    identity.spacing = 10;
    [identity setContentHuggingPriority:1
                         forOrientation:NSLayoutConstraintOrientationHorizontal];

    _uninstall = DCDestructiveButton(@"Uninstall", target, uninstall);
    objc_setAssociatedObject(_uninstall, &kDCDevUninstallRowKey, app, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_uninstall setContentHuggingPriority:NSLayoutPriorityRequired
                           forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSView* spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* header = [NSStackView stackViewWithViews:@[ identity, spacer, _uninstall ]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;
    header.spacing = 8;

    NSMutableArray<NSView*>* sections = [NSMutableArray arrayWithObject:header];

    DCDevRow* ext = [self extensionsFolder];
    if (ext) {
      NSButton* check = [NSButton checkboxWithTitle:@"Extensions" target:target action:tog];
      check.state = ext.selected ? NSControlStateValueOn : NSControlStateValueOff;
      objc_setAssociatedObject(check, &kDCDevCheckRowKey, ext, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      [check setContentHuggingPriority:NSLayoutPriorityRequired
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
      _extSize = [[DCDevSizeBadge alloc] initWithBytes:ext.bytes];
      NSView* extSpacer = [[NSView alloc] initWithFrame:NSZeroRect];
      [extSpacer setContentHuggingPriority:1
                            forOrientation:NSLayoutConstraintOrientationHorizontal];
      NSStackView* extHeader = [NSStackView stackViewWithViews:@[ check, extSpacer, _extSize ]];
      extHeader.orientation = NSUserInterfaceLayoutOrientationHorizontal;
      extHeader.alignment = NSLayoutAttributeCenterY;
      extHeader.spacing = 8;

      _extScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
      _extScroll.drawsBackground = NO;
      _extScroll.hasHorizontalScroller = NO;
      _extScroll.hasVerticalScroller = NO;
      _extScroll.autohidesScrollers = YES;
      _extScroll.borderType = NSNoBorder;
      _extScroll.horizontalScrollElasticity = NSScrollElasticityAllowed;
      _extScroll.verticalScrollElasticity = NSScrollElasticityNone;
      _extScroll.translatesAutoresizingMaskIntoConstraints = NO;
      [_extScroll.heightAnchor constraintEqualToConstant:108].active = YES;

      _extStrip = [NSStackView stackViewWithViews:@[]];
      _extStrip.orientation = NSUserInterfaceLayoutOrientationHorizontal;
      _extStrip.alignment = NSLayoutAttributeCenterY;
      _extStrip.spacing = 8;
      _extScroll.documentView = _extStrip;

      _extBlock = [NSStackView stackViewWithViews:@[ extHeader, _extScroll ]];
      ((NSStackView*)_extBlock).orientation = NSUserInterfaceLayoutOrientationVertical;
      ((NSStackView*)_extBlock).alignment = NSLayoutAttributeLeading;
      ((NSStackView*)_extBlock).spacing = 8;
      [sections addObject:_extBlock];
    }

    NSMutableArray<DCDevRow*>* leftoverRows = [NSMutableArray array];
    for (DCDevRow* r in app.children)
      if (!r.extensions) [leftoverRows addObject:r];
    if (leftoverRows.count) {
      _leftovers = [NSStackView stackViewWithViews:@[]];
      _leftovers.orientation = NSUserInterfaceLayoutOrientationVertical;
      _leftovers.alignment = NSLayoutAttributeLeading;
      _leftovers.spacing = 6;
      for (DCDevRow* folder in leftoverRows) {
        NSButton* check = [NSButton checkboxWithTitle:folder.title target:target action:tog];
        check.state = folder.selected ? NSControlStateValueOn : NSControlStateValueOff;
        objc_setAssociatedObject(check, &kDCDevCheckRowKey, folder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [check setContentHuggingPriority:1
                          forOrientation:NSLayoutConstraintOrientationHorizontal];
        [check setContentCompressionResistancePriority:1
                                        forOrientation:NSLayoutConstraintOrientationHorizontal];
        DCDevSizeBadge* size = [[DCDevSizeBadge alloc] initWithBytes:folder.bytes];
        NSView* rowSpacer = [[NSView alloc] initWithFrame:NSZeroRect];
        [rowSpacer setContentHuggingPriority:1
                              forOrientation:NSLayoutConstraintOrientationHorizontal];
        NSStackView* row = [NSStackView stackViewWithViews:@[ check, rowSpacer, size ]];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.alignment = NSLayoutAttributeCenterY;
        row.spacing = 8;
        [_leftovers addArrangedSubview:row];
      }
      _leftoverBlock = _leftovers;
      [sections addObject:_leftoverBlock];
    }

    NSStackView* body = [NSStackView stackViewWithViews:sections];
    body.orientation = NSUserInterfaceLayoutOrientationVertical;
    body.alignment = NSLayoutAttributeLeading;
    body.spacing = 12;
    body.edgeInsets = NSEdgeInsetsMake(14, 14, 14, 14);
    NSVisualEffectView* card = DCDevWrapCard(body, 10);
    [self addSubview:card];
    DCPinEdges(card, self);
    [self setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];
    DCStackFullWidth((NSStackView*)body, header);
    if (_extBlock) DCStackFullWidth((NSStackView*)body, _extBlock);
    if (_leftoverBlock) DCStackFullWidth((NSStackView*)body, _leftoverBlock);
    if (_extBlock) {
      DCStackFullWidth((NSStackView*)_extBlock, _extScroll);
      NSStackView* extHeader = (NSStackView*)((NSStackView*)_extBlock).arrangedSubviews.firstObject;
      if (extHeader) DCStackFullWidth((NSStackView*)_extBlock, extHeader);
    }
    for (NSView* row in _leftovers.arrangedSubviews) DCStackFullWidth(_leftovers, row);
  }
  return self;
}

- (DCDevRow*)appRow {
  return _app;
}

- (void)setUninstallEnabled:(BOOL)uninstallEnabled {
  _uninstallEnabled = uninstallEnabled;
  _uninstall.enabled = uninstallEnabled;
}

- (void)layout {
  [super layout];
  if (!_extScroll || !_extStrip) return;
  CGFloat clipH = NSHeight(_extScroll.contentView.bounds);
  if (clipH < 1) clipH = 100;
  NSSize fit = _extStrip.fittingSize;
  CGFloat w = MAX(fit.width, 1);
  CGFloat h = MAX(fit.height, 1);
  CGFloat y = clipH > h ? (clipH - h) / 2.0 : 0;
  _extStrip.frame = NSMakeRect(0, y, w, h);
}

- (void)reloadCarousel {
  if (!_extStrip) return;
  DCDevClearStack(_extStrip);
  DCDevRow* ext = [self extensionsFolder];
  if (!ext) return;
  [_extSize setBytes:ext.bytes];
  [ext.children sortUsingComparator:^NSComparisonResult(DCDevRow* a, DCDevRow* b) {
    if (a.bytes != b.bytes)
      return a.bytes > b.bytes ? NSOrderedAscending : NSOrderedDescending;
    return [a.title compare:b.title options:NSCaseInsensitiveSearch];
  }];
  for (DCDevRow* e in ext.children) {
    if (e.kind != DCDevKindExtension) continue;
    [_extStrip addArrangedSubview:[[DCDevExtensionCard alloc] initWithRow:e]];
  }
  [self setNeedsLayout:YES];
}

@end

@implementation DCDevCornerView {
  dcmm::Engine _engine;
  NSMutableArray<DCDevRow*>* _roots;
  NSMutableArray<DCDevVsCodeCard*>* _cards;
  NSScrollView* _appsScroll;
  DCDevFlippedDoc* _appsDoc;
  NSStackView* _appsList;
  DCGlowButton* _clean;
  DCGlowButton* _scanApps;
  BOOL _scanning;
  BOOL _uninstalling;
  NSStackView* _actions;
  NSSegmentedControl* _tabs;
  NSView* _appsWrap;
  NSView* _placeholder;
  uint64_t _job;
  uint64_t _extGen;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _roots = [NSMutableArray array];
    _cards = [NSMutableArray array];
    NSStackView* page = DCPageStack(self);
    page.edgeInsets = NSEdgeInsetsMake(24, 0, 24, 0);
    _scanApps = [DCGlowButton defaultButtonWithTitle:@"Scan Applications"
                                              target:self
                                              action:@selector(reload)
                                           glowColor:NSColor.controlAccentColor
                                       glowLineWidth:2.5
                                          clockwise:YES];
    _clean = [DCGlowButton buttonWithTitle:DCNS(ui::cleanButtonTitle(DCCleanPref()))
                                    target:self
                                    action:@selector(cleanSelected)
                                 glowColor:NSColor.systemRedColor
                             glowLineWidth:2.5
                                clockwise:YES];
    _clean.buttonColor = NSColor.systemRedColor;
    _clean.titleColor = NSColor.whiteColor;
    _clean.hasDestructiveAction = YES;
    _clean.hidden = YES;
    _actions = DCTrailingButtons(@[ _scanApps, _clean ]);
    _actions.edgeInsets = NSEdgeInsetsMake(0, 28, 0, 28);

    _appsScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _appsScroll.drawsBackground = NO;
    _appsScroll.hasVerticalScroller = YES;
    _appsScroll.hasHorizontalScroller = NO;
    _appsScroll.autohidesScrollers = YES;
    _appsScroll.borderType = NSNoBorder;
    _appsScroll.automaticallyAdjustsContentInsets = NO;
    _appsScroll.contentInsets = NSEdgeInsetsZero;

    _appsDoc = [[DCDevFlippedDoc alloc] initWithFrame:NSZeroRect];
    _appsList = [NSStackView stackViewWithViews:@[]];
    _appsList.orientation = NSUserInterfaceLayoutOrientationVertical;
    _appsList.alignment = NSLayoutAttributeLeading;
    _appsList.distribution = NSStackViewDistributionFill;
    _appsList.spacing = 12;
    _appsList.translatesAutoresizingMaskIntoConstraints = NO;
    [_appsDoc addSubview:_appsList];
    [NSLayoutConstraint activateConstraints:@[
      [_appsList.topAnchor constraintEqualToAnchor:_appsDoc.topAnchor],
      [_appsList.leadingAnchor constraintEqualToAnchor:_appsDoc.leadingAnchor],
      [_appsList.trailingAnchor constraintEqualToAnchor:_appsDoc.trailingAnchor],
      [_appsList.bottomAnchor constraintEqualToAnchor:_appsDoc.bottomAnchor],
    ]];
    _appsScroll.documentView = _appsDoc;
    _appsWrap = _appsScroll;

    NSTextField* soon = DCSecondaryLabel(@"Under development");
    soon.alignment = NSTextAlignmentCenter;
    soon.translatesAutoresizingMaskIntoConstraints = NO;
    _placeholder = [[NSView alloc] initWithFrame:NSZeroRect];
    [_placeholder addSubview:soon];
    [NSLayoutConstraint activateConstraints:@[
      [soon.centerXAnchor constraintEqualToAnchor:_placeholder.centerXAnchor],
      [soon.centerYAnchor constraintEqualToAnchor:_placeholder.centerYAnchor],
    ]];
    _placeholder.hidden = YES;
    NSView* body = [[NSView alloc] initWithFrame:NSZeroRect];
    _appsWrap.translatesAutoresizingMaskIntoConstraints = NO;
    _placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [body addSubview:_appsWrap];
    [body addSubview:_placeholder];
    DCPinEdges(_appsWrap, body);
    DCPinEdges(_placeholder, body);

    _tabs = [NSSegmentedControl segmentedControlWithLabels:@[ @"Applications", @"Toolchains", @"Others" ]
                                              trackingMode:NSSegmentSwitchTrackingSelectOne
                                                    target:self
                                                    action:@selector(tabChanged:)];
    _tabs.segmentStyle = NSSegmentStyleRounded;
    _tabs.selectedSegment = 0;
    DCStackCentered(page, _tabs);
    DCStackExpand(page, body);
    [page addArrangedSubview:_actions];
    DCStackFullWidth(page, _actions);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshClean)
                                                 name:DCSettingsDidChangeNotification
                                               object:nil];
    [self reload];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layout {
  [super layout];
  CGFloat w = NSWidth(_appsScroll.contentView.bounds);
  if (w < 1) return;
  CGFloat h = MAX(_appsList.fittingSize.height, 1);
  _appsDoc.frame = NSMakeRect(0, 0, w, h);
}

- (BOOL)applicationTabSelected {
  return _tabs.selectedSegment == 0;
}

- (void)tabChanged:(NSSegmentedControl*)sender {
  const BOOL apps = sender.selectedSegment == 0;
  _appsWrap.hidden = !apps;
  _placeholder.hidden = apps;
  [self refreshClean];
}

- (void)rebuildCards {
  _extGen++;
  DCDevClearStack(_appsList);
  [_cards removeAllObjects];
  for (DCDevRow* app in _roots) {
    DCDevVsCodeCard* card = [[DCDevVsCodeCard alloc] initWithApp:app
                                                         target:self
                                                            tog:@selector(tog:)
                                                      uninstall:@selector(uninstall:)];
    card.uninstallEnabled = !_uninstalling;
    [_appsList addArrangedSubview:card];
    DCStackFullWidth(_appsList, card);
    [_cards addObject:card];
    [self loadExtensionsForCard:card];
  }
  [self setNeedsLayout:YES];
}

- (void)loadExtensionsForCard:(DCDevVsCodeCard*)card {
  DCDevRow* row = [card extensionsFolder];
  if (!row || row.loaded || row.loading) return;
  row.loading = YES;
  const BOOL cursor = card.appRow.cursorApp;
  dcmm::VsCodeEdition edition = card.appRow.edition;
  __weak DCDevCornerView* weakSelf = self;
  __weak DCDevRow* weakRow = row;
  __weak DCDevVsCodeCard* weakCard = card;
  const uint64_t gen = _extGen;
  __block std::vector<std::tuple<std::string, std::string, std::string, uint64_t>> exts;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    if (cursor) {
      for (auto& e : strong->_engine.listCursorExtensions())
        exts.emplace_back(e.name, e.path, e.iconPath, e.bytes);
    } else {
      for (auto& e : strong->_engine.listVsCodeExtensions(edition))
        exts.emplace_back(e.name, e.path, e.iconPath, e.bytes);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      DCDevCornerView* s = weakSelf;
      DCDevRow* parent = weakRow;
      DCDevVsCodeCard* host = weakCard;
      if (!s || !parent || !host || s->_extGen != gen) return;
      [parent.children removeAllObjects];
      for (auto& e : exts) {
        DCDevRow* child = [[DCDevRow alloc] init];
        child.kind = DCDevKindExtension;
        child.title = DCNS(std::get<0>(e));
        child.path = DCNS(std::get<1>(e));
        child.iconPath = DCNS(std::get<2>(e));
        child.bytes = std::get<3>(e);
        child.parent = parent;
        [parent.children addObject:child];
      }
      parent.loaded = YES;
      parent.loading = NO;
      [host reloadCarousel];
      [s refreshClean];
    });
  });
}

- (void)reload {
  if (_scanning) return;
  _scanning = YES;
  _scanApps.enabled = NO;
  [_scanApps beginGlow];
  __weak DCDevCornerView* weakSelf = self;
  __block std::vector<dcmm::VsCodeInstall> vscode;
  __block std::vector<dcmm::CursorInstall> cursor;
  DCRunBackground(&_job, ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    vscode = strong->_engine.listVsCode();
    cursor = strong->_engine.listCursor();
  }, ^{
    DCDevCornerView* s = weakSelf;
    if (!s) return;
    [s->_roots removeAllObjects];
    for (auto& inst : vscode) {
      DCDevRow* app = [[DCDevRow alloc] init];
      app.kind = DCDevKindApp;
      app.title = DCNS(inst.displayName);
      app.appPath = DCNS(inst.appPath);
      app.bytes = inst.bytes;
      app.edition = inst.edition;
      app.cursorApp = NO;
      for (auto& it : inst.items) {
        DCDevRow* child = [[DCDevRow alloc] init];
        child.kind = DCDevKindFolder;
        child.title = DCNS(it.label);
        child.path = DCNS(it.path);
        child.bytes = it.bytes;
        child.edition = inst.edition;
        child.cursorApp = NO;
        child.extensions = it.extensions;
        child.loaded = !it.extensions;
        child.parent = app;
        [app.children addObject:child];
      }
      [s->_roots addObject:app];
    }
    for (auto& inst : cursor) {
      DCDevRow* app = [[DCDevRow alloc] init];
      app.kind = DCDevKindApp;
      app.title = DCNS(inst.displayName);
      app.appPath = DCNS(inst.appPath);
      app.bytes = inst.bytes;
      app.cursorApp = YES;
      for (auto& it : inst.items) {
        DCDevRow* child = [[DCDevRow alloc] init];
        child.kind = DCDevKindFolder;
        child.title = DCNS(it.label);
        child.path = DCNS(it.path);
        child.bytes = it.bytes;
        child.cursorApp = YES;
        child.extensions = it.extensions;
        child.loaded = !it.extensions;
        child.parent = app;
        [app.children addObject:child];
      }
      [s->_roots addObject:app];
    }
    [s rebuildCards];
    [s->_scanApps endGlow];
    s->_scanApps.enabled = YES;
    s->_scanning = NO;
    [s refreshClean];
  });
}

- (DCDevRow*)findRow:(NSString*)path in:(NSArray<DCDevRow*>*)rows {
  for (DCDevRow* r in rows) {
    if (r.path.length && [r.path isEqualToString:path]) return r;
    DCDevRow* hit = [self findRow:path in:r.children];
    if (hit) return hit;
  }
  return nil;
}

- (void)collectSelected:(NSArray<DCDevRow*>*)rows into:(std::vector<std::string>&)out {
  for (DCDevRow* r in rows) {
    if (r.kind != DCDevKindApp && r.selected && r.path.length)
      out.push_back(r.path.UTF8String);
    [self collectSelected:r.children into:out];
  }
}

- (std::vector<std::string>)selectedCleanPaths {
  std::vector<std::string> paths;
  [self collectSelected:_roots into:paths];
  ui::pruneNestedSpaceLensPaths(paths);
  return paths;
}

- (uint64_t)bytesForPaths:(const std::vector<std::string>&)paths {
  uint64_t n = 0;
  for (const auto& p : paths) {
    DCDevRow* row = [self findRow:DCNS(p) in:_roots];
    if (row) n += row.bytes;
  }
  return n;
}

- (void)refreshClean {
  std::vector<std::string> paths = [self selectedCleanPaths];
  uint64_t bytes = [self bytesForPaths:paths];
  _clean.title = DCNS(ui::cleanButtonTitleWithBytes(DCCleanPref(), bytes));
  _clean.hidden = paths.empty();
  _actions.hidden = ![self applicationTabSelected];
}

- (void)cleanSelected {
  std::vector<std::string> paths = [self selectedCleanPaths];
  if (paths.empty()) {
    DCInformNothingToClean(@"Check the items you want to remove.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  uint64_t bytes = [self bytesForPaths:paths];
  if (!DCConfirmSpaceLensClean(list, bytes)) return;
  const auto mode = DCCleanPref();
  _clean.enabled = NO;
  [_clean beginGlow];
  __weak DCDevCornerView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    r = ui::applySpaceLensClean(strong->_engine, paths, mode);
  }, ^{
    DCDevCornerView* s = weakSelf;
    if (!s) return;
    [s->_clean endGlow];
    s->_clean.enabled = YES;
    if (r.trashedItems == 0)
      DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    else
      DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
    [s reload];
  });
}

- (void)setUninstallEnabled:(BOOL)on {
  for (DCDevVsCodeCard* c in _cards) c.uninstallEnabled = on;
}

- (void)uninstall:(NSButton*)sender {
  if (_uninstalling) return;
  DCDevRow* row = objc_getAssociatedObject(sender, &kDCDevUninstallRowKey);
  if (!row || row.kind != DCDevKindApp) return;
  std::vector<std::string> paths =
      row.cursorApp ? dcmm::cursorNukePaths() : dcmm::vsCodeNukePaths(row.edition);
  if (paths.empty()) {
    DCInformNothingToClean(@"Nothing to remove.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  if (!DCConfirmSpaceLensClean(list, row.bytes)) return;
  const auto mode = DCCleanPref();
  _uninstalling = YES;
  [self setUninstallEnabled:NO];
  __weak DCDevCornerView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    r = ui::applySpaceLensClean(strong->_engine, paths, mode);
  }, ^{
    DCDevCornerView* s = weakSelf;
    if (!s) return;
    s->_uninstalling = NO;
    [s setUninstallEnabled:YES];
    if (r.trashedItems == 0)
      DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    else
      DCInformCleaned(@"Uninstalled", DCNS(ui::cleanFinishedDetail(mode, r)));
    [s reload];
  });
}

- (void)tog:(NSButton*)s {
  DCDevRow* item = objc_getAssociatedObject(s, &kDCDevCheckRowKey);
  if (!item) return;
  item.selected = s.state == NSControlStateValueOn;
  [self refreshClean];
}

@end

#import "ui/Theme.h"

#include "dcmm/path.hpp"

#import <Quartz/Quartz.h>

NSNotificationName const DCSettingsDidChangeNotification = @"DCSettingsDidChangeNotification";

static NSString* const kDCAppearanceKey = @"DCAppearance";
static NSString* const kDCCleanPrefKey = @"DCCleanPref";

ui::AppearancePref DCAppearancePref(void) {
  NSString* id = [[NSUserDefaults standardUserDefaults] stringForKey:kDCAppearanceKey];
  return ui::appearancePrefFromId(id ? id.UTF8String : "");
}

void DCApplyStoredAppearance(void) {
  switch (DCAppearancePref()) {
    case ui::AppearancePref::Light:
      NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
      break;
    case ui::AppearancePref::Dark:
      NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
      break;
    case ui::AppearancePref::System:
    default:
      NSApp.appearance = nil;
      break;
  }
}

void DCSetAppearancePref(ui::AppearancePref pref) {
  [[NSUserDefaults standardUserDefaults]
      setObject:[NSString stringWithUTF8String:ui::appearancePrefId(pref)]
         forKey:kDCAppearanceKey];
  DCApplyStoredAppearance();
  [[NSNotificationCenter defaultCenter] postNotificationName:DCSettingsDidChangeNotification
                                                      object:nil];
}

ui::CleanPref DCCleanPref(void) {
  NSString* id = [[NSUserDefaults standardUserDefaults] stringForKey:kDCCleanPrefKey];
  return ui::cleanPrefFromId(id ? id.UTF8String : "");
}

void DCSetCleanPref(ui::CleanPref pref) {
  [[NSUserDefaults standardUserDefaults]
      setObject:[NSString stringWithUTF8String:ui::cleanPrefId(pref)]
         forKey:kDCCleanPrefKey];
  [[NSNotificationCenter defaultCenter] postNotificationName:DCSettingsDidChangeNotification
                                                      object:nil];
}

NSTextField* DCLabel(NSString* text) {
  NSTextField* t = [NSTextField labelWithString:text ?: @""];
  t.lineBreakMode = NSLineBreakByTruncatingTail;
  t.maximumNumberOfLines = 1;
  return t;
}

NSTextField* DCSecondaryLabel(NSString* text) {
  NSTextField* t = [NSTextField wrappingLabelWithString:text ?: @""];
  t.font = [NSFont preferredFontForTextStyle:NSFontTextStyleBody options:@{}];
  t.textColor = [NSColor secondaryLabelColor];
  t.selectable = NO;
  return t;
}

NSTextField* DCCaptionLabel(NSString* text) {
  NSTextField* t = [NSTextField wrappingLabelWithString:text ?: @""];
  t.font = [NSFont preferredFontForTextStyle:NSFontTextStyleCaption1 options:@{}];
  t.textColor = [NSColor secondaryLabelColor];
  t.selectable = NO;
  return t;
}

NSTextField* DCTitleLabel(NSString* text) {
  NSTextField* t = [NSTextField labelWithString:text ?: @""];
  NSFont* title1 = [NSFont preferredFontForTextStyle:NSFontTextStyleTitle1 options:@{}];
  t.font = [NSFont systemFontOfSize:title1.pointSize weight:NSFontWeightBold];
  return t;
}

static NSButton* MakePush(NSString* title, id target, SEL action) {
  NSButton* b = [NSButton buttonWithTitle:title ?: @"" target:target action:action];
  b.bezelStyle = NSBezelStyleRounded;
  b.controlSize = NSControlSizeRegular;
  return b;
}

NSButton* DCPushButton(NSString* title, id target, SEL action) {
  return MakePush(title, target, action);
}

NSButton* DCDefaultButton(NSString* title, id target, SEL action) {
  NSButton* b = MakePush(title, target, action);
  b.keyEquivalent = @"\r";
  return b;
}

NSButton* DCDestructiveButton(NSString* title, id target, SEL action) {
  NSButton* b = MakePush(title, target, action);
  b.hasDestructiveAction = YES;
  return b;
}

void DCStyleTable(NSTableView* table) {
  table.style = NSTableViewStyleInset;
  table.rowSizeStyle = NSTableViewRowSizeStyleDefault;
  table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
  table.allowsColumnReordering = YES;
  table.allowsEmptySelection = YES;
  table.usesAutomaticRowHeights = NO;
}

NSTableCellView* DCCenteredFillCell(NSView* content) {
  NSTableCellView* cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [cell addSubview:content];
  [content setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                      forOrientation:NSLayoutConstraintOrientationVertical];
  [NSLayoutConstraint activateConstraints:@[
    [content.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
    [content.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor],
    [content.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
  ]];
  return cell;
}

NSTableCellView* DCCenteredTextCell(NSTextField* field) {
  NSTableCellView* cell = DCCenteredFillCell(field);
  cell.textField = field;
  return cell;
}

NSTableCellView* DCCenteredIconTextCell(NSImageView* icon, NSTextField* field) {
  [icon setContentHuggingPriority:NSLayoutPriorityRequired
                   forOrientation:NSLayoutConstraintOrientationHorizontal];
  [icon setContentHuggingPriority:NSLayoutPriorityRequired
                   forOrientation:NSLayoutConstraintOrientationVertical];
  [icon setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                 forOrientation:NSLayoutConstraintOrientationVertical];
  [field setContentHuggingPriority:NSLayoutPriorityDefaultLow
                    forOrientation:NSLayoutConstraintOrientationHorizontal];
  [field setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView* row = [NSStackView stackViewWithViews:@[ icon, field ]];
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.spacing = 6;
  row.translatesAutoresizingMaskIntoConstraints = NO;
  NSTableCellView* cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
  [cell addSubview:row];
  [NSLayoutConstraint activateConstraints:@[
    [row.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
    [row.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor],
    [row.topAnchor constraintGreaterThanOrEqualToAnchor:cell.topAnchor constant:6],
    [row.bottomAnchor constraintLessThanOrEqualToAnchor:cell.bottomAnchor constant:-6],
    [row.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
  ]];
  cell.textField = field;
  cell.imageView = icon;
  return cell;
}

NSImageView* DCDangerIcon(CGFloat pointSize) {
  NSImageView* warn = [[NSImageView alloc] initWithFrame:NSZeroRect];
  NSImage* img = [NSImage imageWithSystemSymbolName:@"exclamationmark.triangle.fill"
                           accessibilityDescription:@"Not safe to delete"];
  img = [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                         weight:NSFontWeightRegular]];
  warn.image = img;
  warn.contentTintColor = NSColor.systemOrangeColor;
  warn.toolTip = @"Not safe to delete. Please clean this item at your own risk.";
  return warn;
}

NSTableCellView* DCCenteredDangerTextCell(NSTextField* field) {
  NSImageView* warn = DCDangerIcon(12);
  [warn setContentHuggingPriority:NSLayoutPriorityRequired
                   forOrientation:NSLayoutConstraintOrientationHorizontal];
  [field setContentHuggingPriority:NSLayoutPriorityDefaultLow
                    forOrientation:NSLayoutConstraintOrientationHorizontal];
  [field setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView* row = [NSStackView stackViewWithViews:@[ warn, field ]];
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.spacing = 6;
  NSTableCellView* cell = DCCenteredFillCell(row);
  cell.textField = field;
  return cell;
}

@implementation DCLegendView {
  NSImageView* _iconView;
  NSTextField* _text;
  NSView* _divider;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _message = @"";
    _symbolName = @"info.circle.fill";
    _tintColor = NSColor.systemBlueColor;
    _cornerRadius = 14;
    _borderWidth = 1;
    _iconPointSize = 16;
    self.wantsLayer = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    [_iconView setContentHuggingPriority:NSLayoutPriorityRequired
                          forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_iconView setContentHuggingPriority:NSLayoutPriorityRequired
                          forOrientation:NSLayoutConstraintOrientationVertical];
    NSStackView* iconPad = [NSStackView stackViewWithViews:@[ _iconView ]];
    iconPad.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    iconPad.alignment = NSLayoutAttributeCenterY;
    iconPad.edgeInsets = NSEdgeInsetsMake(10, 14, 10, 14);
    [iconPad setContentHuggingPriority:NSLayoutPriorityRequired
                        forOrientation:NSLayoutConstraintOrientationHorizontal];

    _divider = [[NSView alloc] initWithFrame:NSZeroRect];
    _divider.wantsLayer = YES;
    _divider.translatesAutoresizingMaskIntoConstraints = NO;
    [_divider.widthAnchor constraintEqualToConstant:1].active = YES;
    [_divider setContentHuggingPriority:NSLayoutPriorityRequired
                         forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_divider setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                       forOrientation:NSLayoutConstraintOrientationHorizontal];

    _text = [NSTextField wrappingLabelWithString:@""];
    _text.font = [NSFont preferredFontForTextStyle:NSFontTextStyleCallout options:@{}];
    _text.textColor = [NSColor labelColor];
    _text.selectable = NO;
    [_text setContentHuggingPriority:NSLayoutPriorityDefaultLow
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_text setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* textPad = [NSStackView stackViewWithViews:@[ _text ]];
    textPad.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    textPad.alignment = NSLayoutAttributeCenterY;
    textPad.edgeInsets = NSEdgeInsetsMake(10, 12, 10, 14);
    [textPad setContentHuggingPriority:NSLayoutPriorityDefaultLow
                        forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView* row = [NSStackView stackViewWithViews:@[ iconPad, _divider, textPad ]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 0;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:row];
    DCPinEdges(row, self);
    [NSLayoutConstraint activateConstraints:@[
      [_divider.topAnchor constraintEqualToAnchor:row.topAnchor],
      [_divider.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];
    [self setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];
    [self setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                   forOrientation:NSLayoutConstraintOrientationVertical];
    [self refreshIcon];
  }
  return self;
}

- (instancetype)initWithMessage:(NSString*)message {
  self = [self initWithFrame:NSZeroRect];
  if (self) self.message = message ?: @"";
  return self;
}

+ (instancetype)legendWithMessage:(NSString*)message {
  return [[self alloc] initWithMessage:message];
}

+ (instancetype)dangerLegendWithMessage:(NSString*)message {
  DCLegendView* v = [self legendWithMessage:message];
  v.symbolName = @"exclamationmark.triangle.fill";
  v.tintColor = NSColor.systemOrangeColor;
  return v;
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (BOOL)isDark {
  NSAppearanceName match =
      [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameDarkAqua ]];
  return [match isEqualToString:NSAppearanceNameDarkAqua];
}

- (NSColor*)resolvedTint {
  return self.tintColor ?: NSColor.systemBlueColor;
}

- (void)updateLayer {
  const BOOL dark = [self isDark];
  NSColor* tint = [self resolvedTint];
  self.layer.cornerRadius = self.cornerRadius;
  self.layer.masksToBounds = YES;
  self.layer.borderWidth = self.borderWidth;
  NSColor* fill = self.fillColor ?: [tint colorWithAlphaComponent:dark ? 0.18 : 0.10];
  NSColor* border = self.borderColor ?: [tint colorWithAlphaComponent:dark ? 0.38 : 0.22];
  NSColor* divider = self.dividerColor ?: [tint colorWithAlphaComponent:dark ? 0.32 : 0.20];
  self.layer.backgroundColor = fill.CGColor;
  self.layer.borderColor = border.CGColor;
  if (_divider.wantsLayer) _divider.layer.backgroundColor = divider.CGColor;
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self setNeedsDisplay:YES];
}

- (void)refreshIcon {
  NSImage* img = self.icon;
  if (!img && self.symbolName.length) {
    img = [NSImage imageWithSystemSymbolName:self.symbolName
                    accessibilityDescription:self.message];
    img = [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration
                                                configurationWithPointSize:self.iconPointSize
                                                                    weight:NSFontWeightRegular]];
  }
  _iconView.image = img;
  _iconView.contentTintColor = self.iconTintColor ?: [self resolvedTint];
}

- (void)setMessage:(NSString*)message {
  _message = [message copy] ?: @"";
  _text.stringValue = _message;
  self.toolTip = _message;
  [self refreshIcon];
}

- (void)setIcon:(NSImage*)icon {
  _icon = icon;
  [self refreshIcon];
}

- (void)setSymbolName:(NSString*)symbolName {
  _symbolName = [symbolName copy];
  [self refreshIcon];
}

- (void)setTintColor:(NSColor*)tintColor {
  _tintColor = tintColor ?: NSColor.systemBlueColor;
  [self refreshIcon];
  [self setNeedsDisplay:YES];
}

- (void)setFillColor:(NSColor*)fillColor {
  _fillColor = fillColor;
  [self setNeedsDisplay:YES];
}

- (void)setBorderColor:(NSColor*)borderColor {
  _borderColor = borderColor;
  [self setNeedsDisplay:YES];
}

- (void)setDividerColor:(NSColor*)dividerColor {
  _dividerColor = dividerColor;
  [self setNeedsDisplay:YES];
}

- (void)setIconTintColor:(NSColor*)iconTintColor {
  _iconTintColor = iconTintColor;
  [self refreshIcon];
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
  _cornerRadius = cornerRadius;
  [self setNeedsDisplay:YES];
}

- (void)setBorderWidth:(CGFloat)borderWidth {
  _borderWidth = borderWidth;
  [self setNeedsDisplay:YES];
}

- (void)setIconPointSize:(CGFloat)iconPointSize {
  _iconPointSize = iconPointSize;
  [self refreshIcon];
}

@end

NSTableCellView* DCCenteredCheckCell(NSButton* checkbox) {
  NSTableCellView* cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
  checkbox.translatesAutoresizingMaskIntoConstraints = NO;
  [cell addSubview:checkbox];
  [NSLayoutConstraint activateConstraints:@[
    [checkbox.centerXAnchor constraintEqualToAnchor:cell.centerXAnchor],
    [checkbox.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
  ]];
  return cell;
}

NSScrollView* DCWrapTable(NSTableView* table) {
  NSScrollView* s = [[NSScrollView alloc] initWithFrame:NSZeroRect];
  s.documentView = table;
  s.hasVerticalScroller = YES;
  s.hasHorizontalScroller = NO;
  s.autohidesScrollers = YES;
  s.borderType = NSNoBorder;
  s.drawsBackground = NO;
  s.automaticallyAdjustsContentInsets = YES;
  return s;
}

void DCPinEdges(NSView* child, NSView* parent) {
  child.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor],
    [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor],
    [child.topAnchor constraintEqualToAnchor:parent.topAnchor],
    [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor],
  ]];
}

NSStackView* DCPageStack(NSView* host) {
  NSStackView* stack = [NSStackView stackViewWithViews:@[]];
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.alignment = NSLayoutAttributeLeading;
  stack.distribution = NSStackViewDistributionFill;
  stack.spacing = 16;
  stack.edgeInsets = NSEdgeInsetsMake(24, 28, 24, 28);
  [stack setContentHuggingPriority:NSLayoutPriorityDefaultLow
                    forOrientation:NSLayoutConstraintOrientationVertical];
  [host addSubview:stack];
  DCPinEdges(stack, host);
  return stack;
}

NSStackView* DCHeaderStack(NSString* title, NSString* subtitle) {
  NSTextField* t = DCTitleLabel(title);
  NSTextField* s = DCSecondaryLabel(subtitle);
  NSBox* rule = [[NSBox alloc] initWithFrame:NSZeroRect];
  rule.boxType = NSBoxSeparator;
  rule.translatesAutoresizingMaskIntoConstraints = NO;
  [rule.heightAnchor constraintEqualToConstant:1].active = YES;
  NSStackView* header = [NSStackView stackViewWithViews:@[ t, s, rule ]];
  header.orientation = NSUserInterfaceLayoutOrientationVertical;
  header.alignment = NSLayoutAttributeLeading;
  header.spacing = 10;
  [t setContentHuggingPriority:NSLayoutPriorityRequired
                forOrientation:NSLayoutConstraintOrientationVertical];
  [s setContentHuggingPriority:NSLayoutPriorityRequired
                forOrientation:NSLayoutConstraintOrientationVertical];
  [header setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];
  [rule.widthAnchor constraintEqualToAnchor:header.widthAnchor].active = YES;
  return header;
}

NSStackView* DCTrailingButtons(NSArray<NSButton*>* buttons) {
  NSView* spacer = [[NSView alloc] initWithFrame:NSZeroRect];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSMutableArray* views = [NSMutableArray arrayWithObject:spacer];
  [views addObjectsFromArray:buttons];
  NSStackView* row = [NSStackView stackViewWithViews:views];
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.spacing = 8;
  [row setContentHuggingPriority:NSLayoutPriorityRequired
                  forOrientation:NSLayoutConstraintOrientationVertical];
  return row;
}

void DCStackFullWidth(NSStackView* stack, NSView* view) {
  [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor
                                   constant:-(stack.edgeInsets.left + stack.edgeInsets.right)]
      .active = YES;
}

NSStackView* DCEqualButtonRow(NSArray<NSButton*>* buttons) {
  NSStackView* row = [NSStackView stackViewWithViews:buttons];
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.distribution = NSStackViewDistributionFillEqually;
  row.spacing = 12;
  return row;
}

void DCStackExpand(NSStackView* stack, NSView* view) {
  [view setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  [view setContentCompressionResistancePriority:1
                                 forOrientation:NSLayoutConstraintOrientationVertical];
  [stack addArrangedSubview:view];
  DCStackFullWidth(stack, view);
}

NSView* DCFlexibleSpace(void) {
  NSView* spacer = [[NSView alloc] initWithFrame:NSZeroRect];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  [spacer setContentCompressionResistancePriority:1
                                   forOrientation:NSLayoutConstraintOrientationVertical];
  return spacer;
}

NSModalResponse DCPresentAlert(NSAlert* alert) {
  NSWindow* parent = NSApp.mainWindow;
  if (!parent || !parent.isVisible) parent = NSApp.keyWindow;
  if (!parent) {
    for (NSWindow* w in NSApp.windows) {
      if (w.isVisible) {
        parent = w;
        break;
      }
    }
  }

  [alert layout];
  if (!parent) {
    [alert.window center];
    return [alert runModal];
  }

  __block BOOL done = NO;
  __block NSModalResponse result = NSAlertFirstButtonReturn;
  [alert beginSheetModalForWindow:parent completionHandler:^(NSModalResponse code) {
    result = code;
    done = YES;
  }];
  while (!done) {
    NSEvent* e = [NSApp nextEventMatchingMask:NSEventMaskAny
                                    untilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]
                                       inMode:NSDefaultRunLoopMode
                                      dequeue:YES];
    if (e) [NSApp sendEvent:e];
  }
  return result;
}

BOOL DCConfirmDestructive(NSString* title, NSString* info, NSString* proceedTitle) {
  NSAlert* a = [[NSAlert alloc] init];
  a.alertStyle = NSAlertStyleWarning;
  a.messageText = title ?: @"Are you sure?";
  a.informativeText = info ?: @"";
  [a addButtonWithTitle:@"Cancel"];
  NSButton* proceed = [a addButtonWithTitle:proceedTitle ?: @"Continue"];
  proceed.hasDestructiveAction = YES;
  return DCPresentAlert(a) == NSAlertSecondButtonReturn;
}

BOOL DCConfirmClean(NSArray<NSString*>* paths, uint64_t bytes) {
  if (paths.count == 0) return NO;
  const bool perm = DCCleanPref() == ui::CleanPref::DeletePermanently;
  NSMutableString* info = [NSMutableString string];
  if (perm) {
    [info appendFormat:@"%lu item%s (%@) will be deleted permanently. This cannot be undone from "
                       @"Trash.\n\nProtected system files, keys, and personal libraries are never "
                       @"touched.",
                       (unsigned long)paths.count, paths.count == 1 ? "" : "s",
                       DCNS(dcmm::formatBytes(bytes))];
  } else {
    [info appendFormat:@"%lu item%s (%@) will be moved to Trash. You can restore them from Trash "
                       @"until it is emptied.\n\nProtected system files, keys, and personal libraries "
                       @"are never touched.",
                       (unsigned long)paths.count, paths.count == 1 ? "" : "s",
                       DCNS(dcmm::formatBytes(bytes))];
  }
  NSString* title = perm ? @"Delete these items permanently?" : @"Move these items to Trash?";
  NSString* proceed = perm ? @"Delete Permanently" : @"Move to Trash";
  return DCConfirmDestructive(title, info, proceed);
}

BOOL DCConfirmMoveToTrash(NSArray<NSString*>* paths, uint64_t bytes) {
  return DCConfirmClean(paths, bytes);
}

BOOL DCConfirmSpaceLensClean(NSArray<NSString*>* paths, uint64_t bytes) {
  if (paths.count == 0) return NO;
  const bool perm = DCCleanPref() == ui::CleanPref::DeletePermanently;
  NSMutableString* info = [NSMutableString string];
  if (perm) {
    [info appendFormat:@"%lu item%s (%@) will be deleted permanently. This cannot be undone from "
                       @"Trash.\n\nAny folder you checked is removed at your own risk.",
                       (unsigned long)paths.count, paths.count == 1 ? "" : "s",
                       DCNS(dcmm::formatBytes(bytes))];
  } else {
    [info appendFormat:@"%lu item%s (%@) will be moved to Trash. You can restore them from Trash "
                       @"until it is emptied.\n\nAny folder you checked is removed at your own "
                       @"risk.",
                       (unsigned long)paths.count, paths.count == 1 ? "" : "s",
                       DCNS(dcmm::formatBytes(bytes))];
  }
  NSString* title = perm ? @"Delete these items permanently?" : @"Move these items to Trash?";
  NSString* proceed = perm ? @"Delete Permanently" : @"Move to Trash";
  return DCConfirmDestructive(title, info, proceed);
}

void DCInformNothingToClean(NSString* detail) {
  NSAlert* a = [[NSAlert alloc] init];
  a.alertStyle = NSAlertStyleInformational;
  a.messageText = @"Nothing to clean";
  a.informativeText = detail.length ? detail : @"There is nothing here to remove.";
  [a addButtonWithTitle:@"OK"];
  DCPresentAlert(a);
}

void DCInformCleaned(NSString* title, NSString* detail) {
  NSAlert* a = [[NSAlert alloc] init];
  a.alertStyle = NSAlertStyleInformational;
  a.messageText = title ?: @"Clean finished";
  a.informativeText = detail ?: @"";
  [a addButtonWithTitle:@"OK"];
  DCPresentAlert(a);
}

@interface DCQLHost : NSObject <QLPreviewPanelDataSource>
@property(nonatomic, copy) NSURL* url;
@end
@implementation DCQLHost
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel*)panel {
  (void)panel;
  return self.url ? 1 : 0;
}
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel*)panel previewItemAtIndex:(NSInteger)index {
  (void)panel;
  (void)index;
  return self.url;
}
@end

@interface DCPathActions : NSObject
@end
@implementation DCPathActions
+ (instancetype)shared {
  static DCPathActions* s;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ s = [DCPathActions new]; });
  return s;
}
- (void)reveal:(NSMenuItem*)item {
  DCRevealInFinder(item.representedObject);
}
- (void)open:(NSMenuItem*)item {
  NSString* path = item.representedObject;
  if (path.length) [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}
- (void)quickLook:(NSMenuItem*)item {
  NSString* path = item.representedObject;
  if (!path.length) return;
  static DCQLHost* host;
  if (!host) host = [DCQLHost new];
  host.url = [NSURL fileURLWithPath:path];
  QLPreviewPanel* panel = [QLPreviewPanel sharedPreviewPanel];
  panel.dataSource = host;
  [panel reloadData];
  [panel makeKeyAndOrderFront:nil];
}
- (void)copyPath:(NSMenuItem*)item {
  NSString* path = item.representedObject;
  if (!path.length) return;
  NSPasteboard* pb = [NSPasteboard generalPasteboard];
  [pb clearContents];
  [pb setString:path forType:NSPasteboardTypeString];
}
- (void)copyName:(NSMenuItem*)item {
  NSString* path = item.representedObject;
  if (!path.length) return;
  NSPasteboard* pb = [NSPasteboard generalPasteboard];
  [pb clearContents];
  [pb setString:path.lastPathComponent forType:NSPasteboardTypeString];
}
@end

void DCRevealInFinder(NSString* path) {
  if (!path.length) return;
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ [NSURL fileURLWithPath:path] ]];
}

void DCAttachTableMenu(NSTableView* table, id<NSMenuDelegate> delegate) {
  NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
  menu.delegate = delegate;
  menu.autoenablesItems = YES;
  table.menu = menu;
}

void DCAddPathMenuItems(NSMenu* menu, NSString* path) {
  if (!path.length) return;
  DCPathActions* actions = [DCPathActions shared];
  auto add = ^(NSString* title, SEL sel) {
    NSMenuItem* it = [[NSMenuItem alloc] initWithTitle:title action:sel keyEquivalent:@""];
    it.target = actions;
    it.representedObject = path;
    [menu addItem:it];
  };
  add(@"Show in Finder", @selector(reveal:));
  add(@"Quick Look", @selector(quickLook:));
  add(@"Open", @selector(open:));
  [menu addItem:[NSMenuItem separatorItem]];
  add(@"Copy Path", @selector(copyPath:));
  add(@"Copy Name", @selector(copyName:));
}

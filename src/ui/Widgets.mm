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

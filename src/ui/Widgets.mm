#import "ui/Theme.h"

#include "dcmm/path.hpp"

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
  t.font = [NSFont preferredFontForTextStyle:NSFontTextStyleTitle1 options:@{}];
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
  NSStackView* header = [NSStackView stackViewWithViews:@[ t, s ]];
  header.orientation = NSUserInterfaceLayoutOrientationVertical;
  header.alignment = NSLayoutAttributeLeading;
  header.spacing = 3;
  [t setContentHuggingPriority:NSLayoutPriorityRequired
                forOrientation:NSLayoutConstraintOrientationVertical];
  [s setContentHuggingPriority:NSLayoutPriorityRequired
                forOrientation:NSLayoutConstraintOrientationVertical];
  [header setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];
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

BOOL DCConfirmDestructive(NSString* title, NSString* info, NSString* proceedTitle) {
  NSAlert* a = [[NSAlert alloc] init];
  a.alertStyle = NSAlertStyleWarning;
  a.messageText = title ?: @"Are you sure?";
  a.informativeText = info ?: @"";
  [a addButtonWithTitle:@"Cancel"];
  NSButton* proceed = [a addButtonWithTitle:proceedTitle ?: @"Continue"];
  proceed.hasDestructiveAction = YES;
  return [a runModal] == NSAlertSecondButtonReturn;
}

BOOL DCConfirmMoveToTrash(NSArray<NSString*>* paths, uint64_t bytes) {
  if (paths.count == 0) return NO;
  NSMutableString* info = [NSMutableString string];
  [info appendFormat:@"%lu item%s (%@) will be moved to Trash. You can restore them from Trash "
                     @"until it is emptied.\n\nProtected system files, keys, and personal libraries "
                     @"are never touched.\n",
                     (unsigned long)paths.count, paths.count == 1 ? "" : "s",
                     DCNS(dcmm::formatBytes(bytes))];
  NSUInteger shown = MIN((NSUInteger)8, paths.count);
  for (NSUInteger i = 0; i < shown; ++i) {
    [info appendFormat:@"\n• %@", paths[i]];
  }
  if (paths.count > shown) {
    [info appendFormat:@"\n• …and %lu more", (unsigned long)(paths.count - shown)];
  }
  return DCConfirmDestructive(@"Move these items to Trash?", info, @"Move to Trash");
}

void DCInformNothingToClean(NSString* detail) {
  NSAlert* a = [[NSAlert alloc] init];
  a.alertStyle = NSAlertStyleInformational;
  a.messageText = @"Nothing to clean";
  a.informativeText = detail.length ? detail : @"There is nothing here to remove.";
  [a addButtonWithTitle:@"OK"];
  [a runModal];
}

void DCInformCleaned(NSString* title, NSString* detail) {
  NSAlert* a = [[NSAlert alloc] init];
  a.alertStyle = NSAlertStyleInformational;
  a.messageText = title ?: @"Clean finished";
  a.informativeText = detail ?: @"";
  [a addButtonWithTitle:@"OK"];
  [a runModal];
}

#import "ui/SidebarView.h"
#import "ui/Theme.h"

#include "AppFeatures.hpp"

#import <Collaboration/Collaboration.h>

static NSImage* DCUserProfileImage(void) {
  CBIdentity* identity =
      [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]];
  NSImage* image = identity.image;
  if (image && image.size.width > 0) return image;
  NSImage* fallback = [NSImage imageWithSystemSymbolName:@"person.crop.circle.fill"
                                accessibilityDescription:@"User"];
  return fallback ?: [NSImage imageNamed:NSImageNameUser];
}

static NSString* DCHostDisplayName(void) {
  NSString* name = [[NSHost currentHost] localizedName];
  if (name.length) return name;
  name = [[NSProcessInfo processInfo] hostName];
  if (name.length) return name;
  return @"Mac";
}

@interface DCUserFooterView : NSView
@end

@implementation DCUserFooterView

- (void)mouseUp:(NSEvent*)event {
  NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
  if (!NSPointInRect(p, self.bounds)) return;
  [self openUserAccountSettings];
}

- (void)openUserAccountSettings {
  NSArray<NSString*>* urls = @[
    @"x-apple.systempreferences:com.apple.Users-Groups-Settings.extension",
    @"x-apple.systempreferences:com.apple.preferences.users",
    @"x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings",
  ];
  NSWorkspace* ws = [NSWorkspace sharedWorkspace];
  for (NSString* s in urls) {
    NSURL* url = [NSURL URLWithString:s];
    if (url && [ws openURL:url]) return;
  }
  NSURL* app = [ws URLForApplicationWithBundleIdentifier:@"com.apple.systempreferences"];
  if (app) [ws openURL:app];
}

- (void)resetCursorRects {
  [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
}

- (NSView*)hitTest:(NSPoint)point {
  NSView* v = [super hitTest:point];
  return v ? self : nil;
}

@end

@interface DCSidebarView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation DCSidebarView {
  NSTableView* _table;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.material = NSVisualEffectMaterialUnderWindowBackground;
    self.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.state = NSVisualEffectStateFollowsWindowActiveState;

    _selected = ui::Module::Overview;

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _table.backgroundColor = [NSColor clearColor];
    _table.headerView = nil;
    _table.dataSource = self;
    _table.delegate = self;
    _table.allowsEmptySelection = NO;
    _table.allowsMultipleSelection = NO;
    _table.style = NSTableViewStyleSourceList;
    _table.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    _table.floatsGroupRows = NO;
    NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:@"nav"];
    [_table addTableColumn:col];
    _table.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;

    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.documentView = _table;
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    scroll.automaticallyAdjustsContentInsets = YES;

    NSBox* divider = [[NSBox alloc] initWithFrame:NSZeroRect];
    divider.boxType = NSBoxSeparator;

    NSImageView* avatar = [[NSImageView alloc] initWithFrame:NSZeroRect];
    avatar.image = DCUserProfileImage();
    avatar.imageScaling = NSImageScaleProportionallyUpOrDown;
    avatar.wantsLayer = YES;
    avatar.layer.cornerRadius = 16;
    avatar.layer.masksToBounds = YES;
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    [avatar.widthAnchor constraintEqualToConstant:32].active = YES;
    [avatar.heightAnchor constraintEqualToConstant:32].active = YES;

    NSString* fullName = NSFullUserName();
    if (!fullName.length) fullName = NSUserName();
    NSTextField* nameField = DCLabel(fullName);
    nameField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    nameField.lineBreakMode = NSLineBreakByTruncatingTail;

    NSTextField* hostField = DCCaptionLabel(DCHostDisplayName());
    hostField.lineBreakMode = NSLineBreakByTruncatingTail;

    NSStackView* names = [NSStackView stackViewWithViews:@[ nameField, hostField ]];
    names.orientation = NSUserInterfaceLayoutOrientationVertical;
    names.alignment = NSLayoutAttributeLeading;
    names.spacing = 1;

    NSStackView* userRow = [NSStackView stackViewWithViews:@[ avatar, names ]];
    userRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    userRow.alignment = NSLayoutAttributeCenterY;
    userRow.spacing = 10;

    DCUserFooterView* footerHit = [[DCUserFooterView alloc] initWithFrame:NSZeroRect];
    footerHit.translatesAutoresizingMaskIntoConstraints = NO;
    [footerHit addSubview:userRow];
    DCPinEdges(userRow, footerHit);
    [footerHit.heightAnchor constraintGreaterThanOrEqualToConstant:40].active = YES;
    footerHit.toolTip = @"Open Users & Groups in System Settings";

    NSStackView* footer = [NSStackView stackViewWithViews:@[ footerHit ]];
    footer.orientation = NSUserInterfaceLayoutOrientationVertical;
    footer.alignment = NSLayoutAttributeLeading;
    footer.edgeInsets = NSEdgeInsetsMake(10, 10, 12, 10);

    NSStackView* stack = [NSStackView stackViewWithViews:@[ scroll, divider, footer ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 0;
    [self addSubview:stack];
    DCPinEdges(stack, self);

    [scroll setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    [scroll setContentCompressionResistancePriority:1
                                     forOrientation:NSLayoutConstraintOrientationVertical];
    [scroll.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [divider.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [footer.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [footerHit.widthAnchor constraintEqualToAnchor:footer.widthAnchor
                                          constant:-(footer.edgeInsets.left + footer.edgeInsets.right)]
        .active = YES;
    [names setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];

    [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
  }
  return self;
}

- (void)setSelected:(ui::Module)selected {
  _selected = selected;
  [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSInteger)selected] byExtendingSelection:NO];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
  return (NSInteger)ui::Module::Count;
}

- (NSView*)tableView:(NSTableView*)tableView
    viewForTableColumn:(NSTableColumn*)tableColumn
                   row:(NSInteger)row {
  NSTableCellView* cell = [tableView makeViewWithIdentifier:@"NavCell" owner:self];
  if (!cell) {
    cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
    cell.identifier = @"NavCell";
    NSImageView* img = [[NSImageView alloc] initWithFrame:NSZeroRect];
    img.translatesAutoresizingMaskIntoConstraints = NO;
    img.imageScaling = NSImageScaleProportionallyDown;
    cell.imageView = img;
    [cell addSubview:img];
    NSTextField* tf = DCLabel(@"");
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    cell.textField = tf;
    [cell addSubview:tf];
    [NSLayoutConstraint activateConstraints:@[
      [img.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
      [img.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
      [img.widthAnchor constraintEqualToConstant:16],
      [img.heightAnchor constraintEqualToConstant:16],
      [tf.leadingAnchor constraintEqualToAnchor:img.trailingAnchor constant:6],
      [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4],
      [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    ]];
  }
  ui::Module m = (ui::Module)row;
  cell.textField.stringValue = [NSString stringWithUTF8String:ui::title(m)];
  cell.imageView.image =
      [NSImage imageWithSystemSymbolName:[NSString stringWithUTF8String:ui::sidebarSymbol(m)]
                accessibilityDescription:cell.textField.stringValue];
  return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification*)notification {
  NSInteger row = _table.selectedRow;
  if (row < 0) return;
  ui::Module m = (ui::Module)row;
  if (m == _selected) return;
  _selected = m;
  if (self.onSelect) self.onSelect(m);
}

@end

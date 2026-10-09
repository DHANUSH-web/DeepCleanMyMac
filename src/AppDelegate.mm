#import "AppDelegate.h"
#import "ui/MainWindowController.h"
#import "ui/Theme.h"

#include "dcmm/common/dcmm.h"

static NSString* const kDCAboutDocsURL   = @"https://dcmm.dhanushhv.com/docs";
static NSString* const kDCAboutGitHubURL = @"https://github.com/DHANUSH-web/DeepCleanMyMac";

@interface DCAboutBadge : NSView
- (instancetype)initWithText:(NSString*)text;
@end
@implementation DCAboutBadge
{
  NSTextField* _label;
}
- (BOOL)wantsUpdateLayer
{
  return YES;
}
- (void)updateLayer
{
  self.layer.cornerRadius  = MAX(NSHeight(self.bounds) / 2.0, 8);
  self.layer.masksToBounds = YES;
  NSAppearanceName match =
      [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameDarkAqua ]];
  const BOOL dark = [match isEqualToString:NSAppearanceNameDarkAqua];
  self.layer.backgroundColor =
      [[NSColor labelColor] colorWithAlphaComponent:dark ? 0.12 : 0.08].CGColor;
}
- (instancetype)initWithText:(NSString*)text
{
  self = [super initWithFrame:NSZeroRect];
  if (self)
  {
    self.wantsLayer                                = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    _label                                         = DCCaptionLabel(text);
    _label.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_label];
    [NSLayoutConstraint activateConstraints:@[
      [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
      [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
      [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:3],
      [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3],
    ]];
  }
  return self;
}
@end

@interface DCAboutWindow : NSPanel
@end
@implementation DCAboutWindow
- (BOOL)canBecomeKeyWindow
{
  return YES;
}
- (void)cancelOperation:(id)sender
{
  [self orderOut:sender];
}
@end

@implementation AppDelegate
{
  DCMainWindowController* _main;
  NSWindow* _about;
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
  DCApplyStoredAppearance();
  DCRequestNotificationPermission();
  [self buildMenu];
  _main = [[DCMainWindowController alloc] init];
  [_main showWindowAndActivate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
  return YES;
}

- (void)buildMenu
{
  NSMenu* menubar     = [[NSMenu alloc] init];
  NSMenuItem* appItem = [[NSMenuItem alloc] init];
  [menubar addItem:appItem];
  NSMenu* app = [[NSMenu alloc] initWithTitle:@"DeepCleanMyMac"];
  [app addItemWithTitle:@"About DeepCleanMyMac" action:@selector(showAbout:) keyEquivalent:@""];
  [app addItem:[NSMenuItem separatorItem]];
  [app addItemWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];
  [app addItem:[NSMenuItem separatorItem]];
  [app addItemWithTitle:@"Hide DeepCleanMyMac" action:@selector(hide:) keyEquivalent:@"h"];
  NSMenuItem* hideOthers = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                                      action:@selector(hideOtherApplications:)
                                               keyEquivalent:@"h"];
  hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
  [app addItem:hideOthers];
  [app addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
  [app addItem:[NSMenuItem separatorItem]];
  [app addItemWithTitle:@"Quit DeepCleanMyMac" action:@selector(terminate:) keyEquivalent:@"q"];
  appItem.submenu = app;

  NSMenuItem* editItem = [[NSMenuItem alloc] init];
  [menubar addItem:editItem];
  NSMenu* edit = [[NSMenu alloc] initWithTitle:@"Edit"];
  [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  editItem.submenu = edit;

  NSMenuItem* winItem = [[NSMenuItem alloc] init];
  [menubar addItem:winItem];
  NSMenu* win = [[NSMenu alloc] initWithTitle:@"Window"];
  [win addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
  winItem.submenu   = win;
  NSApp.windowsMenu = win;
  NSApp.mainMenu    = menubar;
}

- (void)showSettings:(id)sender
{
  [_main showSettings];
}

- (void)showAbout:(id)sender
{
  if (!_about)
  {
    NSImageView* icon                              = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.image                                     = NSApp.applicationIconImage;
    icon.imageScaling                              = NSImageScaleProportionallyUpOrDown;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon.widthAnchor constraintEqualToConstant:96].active  = YES;
    [icon.heightAnchor constraintEqualToConstant:96].active = YES;

    NSTextField* app = DCTitleLabel(@"DeepCleanMyMac");
    app.alignment    = NSTextAlignmentLeft;

    NSString* ver = @(dcmm_version());
    NSView* versionBadge =
        [[DCAboutBadge alloc] initWithText:[NSString stringWithFormat:@"v%@", ver]];
    NSView* engineBadge =
        [[DCAboutBadge alloc] initWithText:[NSString stringWithFormat:@"Engine %@", ver]];
    NSStackView* badges = [NSStackView stackViewWithViews:@[ versionBadge, engineBadge ]];
    badges.orientation  = NSUserInterfaceLayoutOrientationHorizontal;
    badges.alignment    = NSLayoutAttributeCenterY;
    badges.spacing      = 6;

    NSTextField* caption = DCSecondaryLabel(@"Native, fast and open-source Mac SSD cleaner");
    caption.alignment    = NSTextAlignmentLeft;

    NSTextField* credits = DCSecondaryLabel(@"Designed and Developed by Dhanush H V");
    credits.alignment    = NSTextAlignmentLeft;

    NSStackView* text = [NSStackView stackViewWithViews:@[ app, badges, caption, credits ]];
    text.orientation  = NSUserInterfaceLayoutOrientationVertical;
    text.alignment    = NSLayoutAttributeLeading;
    text.spacing      = 0;
    [text setCustomSpacing:8 afterView:app];
    [text setCustomSpacing:12 afterView:badges];
    [text setCustomSpacing:8 afterView:caption];

    NSStackView* row = [NSStackView stackViewWithViews:@[ icon, text ]];
    row.orientation  = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment    = NSLayoutAttributeCenterY;
    row.spacing      = 35;
    row.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton* docs = DCDefaultButton(@"Docs", self, @selector(openAboutLink:));
    docs.tag       = 0;

    NSButton* github = DCPushButton(@"GitHub", self, @selector(openAboutLink:));
    github.tag       = 1;

    NSStackView* buttons = [NSStackView stackViewWithViews:@[ docs, github ]];
    buttons.orientation  = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.alignment    = NSLayoutAttributeCenterY;
    buttons.spacing      = 8;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    const NSSize aboutSize            = NSMakeSize(450, 260);
    _about                            = [[DCAboutWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, aboutSize.width, aboutSize.height)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered
                      defer:NO];
    _about.title                      = @"About DeepCleanMyMac";
    _about.titleVisibility            = NSWindowTitleHidden;
    _about.titlebarAppearsTransparent = YES;
    _about.opaque                     = YES;
    _about.backgroundColor            = NSColor.clearColor;
    _about.hasShadow                  = YES;
    _about.movableByWindowBackground  = YES;
    _about.releasedWhenClosed         = NO;

    NSVisualEffectView* chrome = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    chrome.material            = NSVisualEffectMaterialHeaderView;
    chrome.blendingMode        = NSVisualEffectBlendingModeBehindWindow;
    chrome.state               = NSVisualEffectStateFollowsWindowActiveState;
    chrome.translatesAutoresizingMaskIntoConstraints = NO;
    _about.contentView                               = chrome;
    [chrome addSubview:row];
    [chrome addSubview:buttons];
    [NSLayoutConstraint activateConstraints:@[
      [row.topAnchor constraintEqualToAnchor:chrome.topAnchor constant:40],
      [row.leadingAnchor constraintEqualToAnchor:chrome.leadingAnchor constant:24],
      [row.trailingAnchor constraintEqualToAnchor:chrome.trailingAnchor constant:-32],
      [buttons.topAnchor constraintGreaterThanOrEqualToAnchor:row.bottomAnchor constant:16],
      [buttons.trailingAnchor constraintEqualToAnchor:chrome.trailingAnchor constant:-32],
      [buttons.bottomAnchor constraintEqualToAnchor:chrome.bottomAnchor constant:-20],
    ]];
    [_about setContentSize:aboutSize];
  }
  [_about center];
  [_about makeKeyAndOrderFront:sender];
}

- (void)openAboutLink:(NSButton*)sender
{
  NSString* s = sender.tag == 1 ? kDCAboutGitHubURL : kDCAboutDocsURL;
  NSURL* url  = [NSURL URLWithString:s];
  if (url)
  {
    [NSWorkspace.sharedWorkspace openURL:url];
  }
}

@end

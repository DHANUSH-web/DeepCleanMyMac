#import "ui/MainWindowController.h"
#import "ui/DashboardView.h"
#import "ui/DuplicatesView.h"
#import "ui/LargeFilesView.h"
#import "ui/MaintenanceView.h"
#import "ui/ResultsView.h"
#import "ui/SidebarView.h"
#import "ui/SettingsView.h"
#import "ui/SpaceLensView.h"
#import "ui/Theme.h"
#import "ui/UninstallerView.h"

#include "dcmm/dcmm.hpp"
#include "Modules.h"

@interface DCOpaquePane : NSView
@end
@implementation DCOpaquePane
- (BOOL)isOpaque {
  return YES;
}
- (BOOL)wantsUpdateLayer {
  return YES;
}
- (void)updateLayer {
  self.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
}
@end

namespace {
constexpr CGFloat kWindowWidth = 760;
constexpr CGFloat kWindowMinHeight = 520;
}  // namespace

@implementation DCMainWindowController {
  NSSplitView* _split;
  DCSidebarView* _sidebar;
  NSView* _content;
  NSMutableDictionary<NSNumber*, NSView*>* _pages;
}

- (instancetype)init {
  NSWindow* win = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, kWindowWidth, 700)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  // win.title = @"DeepCleanMyMac";
  win.minSize = NSMakeSize(kWindowWidth, kWindowMinHeight);
  win.maxSize = NSMakeSize(kWindowWidth, CGFLOAT_MAX);
  win.releasedWhenClosed = NO;
  win.titlebarAppearsTransparent = YES;
  win.titleVisibility = NSWindowTitleVisible;
  win.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
  win.opaque = YES;
  win.collectionBehavior = NSWindowCollectionBehaviorFullScreenNone;
  [win standardWindowButton:NSWindowZoomButton].enabled = NO;
  self = [super initWithWindow:win];
  if (self) {
    self.window.delegate = self;

    _sidebar = [[DCSidebarView alloc] initWithFrame:NSMakeRect(0, 0, 220, 700)];
    _content = [[DCOpaquePane alloc] initWithFrame:NSMakeRect(0, 0, 860, 700)];
    _content.wantsLayer = YES;

    _split = [[NSSplitView alloc] initWithFrame:NSZeroRect];
    _split.vertical = YES;
    _split.dividerStyle = NSSplitViewDividerStyleThin;
    _split.delegate = self;
    _split.autosaveName = @"DCMainSplit";
    [_split addSubview:_sidebar];
    [_split addSubview:_content];
    win.contentView = _split;
    [_split setPosition:220 ofDividerAtIndex:0];

    _pages = [NSMutableDictionary new];
    DCDashboardView* dash = [[DCDashboardView alloc] initWithFrame:NSZeroRect];
    _pages[@((int)ui::Module::Overview)] = dash;
    _pages[@((int)ui::Module::SmartScan)] = [[DCResultsView alloc]
        initWithMode:DCResultsModeSmart
               title:@"Smart Scan"
            subtitle:[NSString stringWithUTF8String:ui::subtitle(ui::Module::SmartScan)]];
    _pages[@((int)ui::Module::SystemJunk)] = [[DCResultsView alloc]
        initWithMode:DCResultsModeJunk
               title:@"System Wide Scan"
            subtitle:[NSString stringWithUTF8String:ui::subtitle(ui::Module::SystemJunk)]];
    _pages[@((int)ui::Module::LargeFiles)] = [[DCLargeFilesView alloc] initWithFrame:NSZeroRect];
    _pages[@((int)ui::Module::Duplicates)] = [[DCDuplicatesView alloc] initWithFrame:NSZeroRect];
    _pages[@((int)ui::Module::Uninstaller)] = [[DCUninstallerView alloc] initWithFrame:NSZeroRect];
    _pages[@((int)ui::Module::Privacy)] = [[DCResultsView alloc]
        initWithMode:DCResultsModePrivacy
               title:@"Privacy"
            subtitle:[NSString stringWithUTF8String:ui::subtitle(ui::Module::Privacy)]];
    _pages[@((int)ui::Module::SpaceLens)] = [[DCSpaceLensView alloc] initWithFrame:NSZeroRect];
    _pages[@((int)ui::Module::Maintenance)] = [[DCMaintenanceView alloc] initWithFrame:NSZeroRect];
    _pages[@((int)ui::Module::Settings)] = [[DCSettingsView alloc] initWithFrame:NSZeroRect];

    __weak DCMainWindowController* weakSelf = self;
    _sidebar.onSelect = ^(ui::Module m) {
      DCMainWindowController* s = weakSelf;
      if (s) [s showModule:m];
    };
    dash.onOpen = ^(ui::Module m) {
      DCMainWindowController* s = weakSelf;
      if (!s) return;
      s->_sidebar.selected = m;
      [s showModule:m];
    };

    [self showModule:ui::Module::Overview];
  }
  return self;
}

- (void)showModule:(ui::Module)m {
  for (NSView* v in _content.subviews) [v removeFromSuperview];
  NSView* page = _pages[@((int)m)];
  if (!page) return;
  [_content addSubview:page];
  DCPinEdges(page, _content);
}

- (void)showSettings {
  _sidebar.selected = ui::Module::Settings;
  [self showModule:ui::Module::Settings];
}

- (void)showWindowAndActivate {
  [self.window center];
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (NSSize)windowWillResize:(NSWindow*)sender toSize:(NSSize)frameSize {
  (void)sender;
  frameSize.width = kWindowWidth;
  if (frameSize.height < kWindowMinHeight) frameSize.height = kWindowMinHeight;
  return frameSize;
}

- (BOOL)windowShouldZoom:(NSWindow*)window toFrame:(NSRect)newFrame {
  (void)window;
  (void)newFrame;
  return NO;
}

- (CGFloat)splitView:(NSSplitView*)splitView constrainMinCoordinate:(CGFloat)proposed
         ofSubviewAt:(NSInteger)dividerIndex {
  (void)proposed;
  (void)dividerIndex;
  (void)splitView;
  return 180;
}

- (CGFloat)splitView:(NSSplitView*)splitView constrainMaxCoordinate:(CGFloat)proposed
         ofSubviewAt:(NSInteger)dividerIndex {
  (void)proposed;
  (void)dividerIndex;
  return MIN(260, NSWidth(splitView.bounds) - 480);
}

- (BOOL)splitView:(NSSplitView*)splitView shouldAdjustSizeOfSubview:(NSView*)view {
  (void)splitView;
  return view != _sidebar;
}

- (BOOL)splitView:(NSSplitView*)splitView canCollapseSubview:(NSView*)subview {
  (void)splitView;
  (void)subview;
  return NO;
}

@end

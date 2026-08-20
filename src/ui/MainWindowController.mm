#import "ui/MainWindowController.h"
#import "ui/DashboardView.h"
#import "ui/DuplicatesView.h"
#import "ui/LargeFilesView.h"
#import "ui/MaintenanceView.h"
#import "ui/ResultsView.h"
#import "ui/SidebarView.h"
#import "ui/SpaceLensView.h"
#import "ui/Theme.h"
#import "ui/UninstallerView.h"

#include "dcmm/dcmm.hpp"

@implementation DCMainWindowController {
  DCSidebarView* _sidebar;
  NSView* _content;
  NSMutableDictionary<NSNumber*, NSView*>* _pages;
}

- (instancetype)init {
  NSWindow* win = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 1240, 800)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  win.title = @"DeepCleanMyMac";
  win.titlebarAppearsTransparent = YES;
  win.backgroundColor = th::bg();
  win.minSize = NSMakeSize(1000, 680);
  win.releasedWhenClosed = NO;
  self = [super initWithWindow:win];
  if (self) {
    self.window.delegate = self;
    NSView* root = win.contentView;
    root.wantsLayer = YES;
    root.layer.backgroundColor = th::bg().CGColor;

    _sidebar = [[DCSidebarView alloc] initWithFrame:NSMakeRect(0, 0, 232, 800)];
    [root addSubview:_sidebar];

    _content = [[NSView alloc] initWithFrame:NSZeroRect];
    _content.wantsLayer = YES;
    [root addSubview:_content];

    _pages = [NSMutableDictionary new];
    DCDashboardView* dash = [[DCDashboardView alloc] initWithFrame:NSZeroRect];
    DCResultsView* scan = [[DCResultsView alloc] initWithMode:DCResultsModeJunk];
    DCResultsView* junk = [[DCResultsView alloc] initWithMode:DCResultsModeJunk];
    DCLargeFilesView* large = [[DCLargeFilesView alloc] initWithFrame:NSZeroRect];
    DCDuplicatesView* dup = [[DCDuplicatesView alloc] initWithFrame:NSZeroRect];
    DCUninstallerView* un = [[DCUninstallerView alloc] initWithFrame:NSZeroRect];
    DCResultsView* priv = [[DCResultsView alloc] initWithMode:DCResultsModePrivacy];
    DCSpaceLensView* lens = [[DCSpaceLensView alloc] initWithFrame:NSZeroRect];
    DCMaintenanceView* maint = [[DCMaintenanceView alloc] initWithFrame:NSZeroRect];

    _pages[@((int)ui::Module::Overview)] = dash;
    _pages[@((int)ui::Module::SmartScan)] = scan;
    _pages[@((int)ui::Module::SystemJunk)] = junk;
    _pages[@((int)ui::Module::LargeFiles)] = large;
    _pages[@((int)ui::Module::Duplicates)] = dup;
    _pages[@((int)ui::Module::Uninstaller)] = un;
    _pages[@((int)ui::Module::Privacy)] = priv;
    _pages[@((int)ui::Module::SpaceLens)] = lens;
    _pages[@((int)ui::Module::Maintenance)] = maint;

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

    dcmm::Engine e;
    auto d = e.disk("/");
    double used = d.totalBytes ? 1.0 - (double)d.availableBytes / (double)d.totalBytes : 0;
    _sidebar.diskUsedFraction = used;
    _sidebar.freeCaption = [NSString stringWithFormat:@"%@ free", DCNS(dcmm::formatBytes(d.availableBytes))];

    [self showModule:ui::Module::Overview];
  }
  return self;
}

- (void)showModule:(ui::Module)m {
  for (NSView* v in _content.subviews) [v removeFromSuperview];
  NSView* page = _pages[@((int)m)];
  if (!page) return;
  [_content addSubview:page];
  page.frame = _content.bounds;
  page.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
}

- (void)windowDidResize:(NSNotification*)notification {
  [self layout];
}

- (void)showWindowAndActivate {
  [self.window center];
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
  [self layout];
}

- (void)layout {
  NSView* root = self.window.contentView;
  NSRect b = root.bounds;
  const CGFloat side = 232;
  _sidebar.frame = NSMakeRect(0, 0, side, b.size.height);
  _content.frame = NSMakeRect(side + 16, 28, b.size.width - side - 32, b.size.height - 56);
  for (NSView* v in _content.subviews) v.frame = _content.bounds;
}

@end

@interface DCRootView : NSView
@property(nonatomic, weak) DCMainWindowController* controller;
@end
@implementation DCRootView
- (void)setFrameSize:(NSSize)newSize {
  [super setFrameSize:newSize];
  [self.controller layout];
}
@end

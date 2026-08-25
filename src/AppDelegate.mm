#import "AppDelegate.h"
#import "ui/MainWindowController.h"
#import "ui/Theme.h"

@implementation AppDelegate {
  DCMainWindowController* _main;
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  DCApplyStoredAppearance();
  [self buildMenu];
  _main = [[DCMainWindowController alloc] init];
  [_main showWindowAndActivate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
  return YES;
}

- (void)buildMenu {
  NSMenu* menubar = [[NSMenu alloc] init];
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
  winItem.submenu = win;
  NSApp.windowsMenu = win;
  NSApp.mainMenu = menubar;
}

- (void)showSettings:(id)sender {
  [_main showSettings];
}

- (void)showAbout:(id)sender {
  NSAlert* a = [[NSAlert alloc] init];
  a.messageText = @"DeepCleanMyMac";
  a.informativeText = @"Free macOS cleaner. Engine: dcmmlib 1.0.0\n"
                       @"Moves files to Trash after you review them. No telemetry.";
  [a addButtonWithTitle:@"OK"];
  DCPresentAlert(a);
}

@end

#pragma once

#import <Cocoa/Cocoa.h>

@interface DCMainWindowController : NSWindowController <NSWindowDelegate, NSSplitViewDelegate>
- (void)showWindowAndActivate;
- (void)showSettings;
@end

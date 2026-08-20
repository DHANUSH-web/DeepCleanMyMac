#pragma once

#import <Cocoa/Cocoa.h>

@interface DCMainWindowController : NSWindowController <NSWindowDelegate>
- (void)showWindowAndActivate;
- (void)layout;
@end

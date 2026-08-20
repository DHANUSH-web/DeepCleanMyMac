#pragma once

#import <Cocoa/Cocoa.h>
#include "Modules.h"

@interface DCDashboardView : NSView
@property(nonatomic, copy) void (^onOpen)(ui::Module);
- (void)refreshStats;
@end

#pragma once

#import <Cocoa/Cocoa.h>
#include "Modules.h"

@interface DCSidebarView : NSVisualEffectView
@property(nonatomic) ui::Module selected;
@property(nonatomic, copy) void (^onSelect)(ui::Module);
@end

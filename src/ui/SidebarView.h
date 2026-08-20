#pragma once

#import <Cocoa/Cocoa.h>
#include "Modules.h"

@interface DCSidebarView : NSView
@property(nonatomic) ui::Module selected;
@property(nonatomic, copy) void (^onSelect)(ui::Module);
@property(nonatomic, copy) NSString* freeCaption;
@property(nonatomic) double diskUsedFraction;
@end

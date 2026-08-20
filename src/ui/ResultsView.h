#pragma once

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, DCResultsMode) {
  DCResultsModeJunk = 0,
  DCResultsModePrivacy = 1,
};

@interface DCResultsView : NSView
- (instancetype)initWithMode:(DCResultsMode)mode;
- (void)startScan;
@end

#pragma once

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, DCResultsMode) {
  DCResultsModeJunk = 0,
  DCResultsModePrivacy = 1,
  DCResultsModeSmart = 2,
};

@interface DCResultsView : NSView
- (instancetype)initWithMode:(DCResultsMode)mode;
- (instancetype)initWithMode:(DCResultsMode)mode title:(NSString*)title subtitle:(NSString*)subtitle;
- (instancetype)initWithMode:(DCResultsMode)mode
                       title:(NSString*)title
                    subtitle:(NSString*)subtitle
                 emptySymbol:(NSString*)emptySymbol;
- (void)startScan;
@end

#pragma once

#import <Cocoa/Cocoa.h>

#include "AppSettings.hpp"

#include <atomic>
#include <cstdint>
#include <string>

NS_ASSUME_NONNULL_BEGIN

inline NSString* DCNS(const std::string& s) {
  if (s.empty()) return @"";
  return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding] ?: @"";
}

NSTextField* DCLabel(NSString* text);
NSTextField* DCSecondaryLabel(NSString* text);
NSTextField* DCCaptionLabel(NSString* text);
NSTextField* DCTitleLabel(NSString* text);

NSButton* DCPushButton(NSString* title, id target, SEL action);
NSButton* DCDefaultButton(NSString* title, id target, SEL action);
NSButton* DCDestructiveButton(NSString* title, id target, SEL action);

void DCStyleTable(NSTableView* table);
NSScrollView* DCWrapTable(NSTableView* table);
NSTableCellView* DCCenteredTextCell(NSTextField* field);
NSTableCellView* DCCenteredCheckCell(NSButton* checkbox);
NSTableCellView* DCCenteredFillCell(NSView* content);
NSTableCellView* DCCenteredIconTextCell(NSImageView* icon, NSTextField* field);
NSImageView* DCDangerIcon(CGFloat pointSize);
NSTableCellView* DCCenteredDangerTextCell(NSTextField* field);

/// Inline [icon | message] banner. `legendWithMessage:` is an info legend
/// (blue, info symbol). Override icon, tint, fill, border, radius as needed.
@interface DCLegendView : NSView
@property(nonatomic, copy) NSString* message;
@property(nonatomic, strong, nullable) NSImage* icon;
@property(nonatomic, copy, nullable) NSString* symbolName;
@property(nonatomic, strong) NSColor* tintColor;
@property(nonatomic, strong, nullable) NSColor* fillColor;
@property(nonatomic, strong, nullable) NSColor* borderColor;
@property(nonatomic, strong, nullable) NSColor* dividerColor;
@property(nonatomic, strong, nullable) NSColor* iconTintColor;
@property(nonatomic) CGFloat cornerRadius;
@property(nonatomic) CGFloat borderWidth;
@property(nonatomic) CGFloat iconPointSize;

- (instancetype)initWithMessage:(NSString*)message;
+ (instancetype)legendWithMessage:(NSString*)message;
+ (instancetype)dangerLegendWithMessage:(NSString*)message;
@end

/// Centered [icon + title + subtitle + button] start screen. Callers pass every visible value.
@interface DCStartScreen : NSView
@property(nonatomic, copy, nullable) NSString* title;
@property(nonatomic, strong, nullable) NSFont* titleFont;
@property(nonatomic, copy, nullable) NSString* subtitle;
@property(nonatomic, strong, nullable) NSFont* subtitleFont;
@property(nonatomic, strong, nullable) NSColor* subtitleColor;
@property(nonatomic) CGFloat subtitleMaxWidth;
@property(nonatomic, copy, nullable) NSString* symbolName;
@property(nonatomic, strong, nullable) NSImage* icon;
@property(nonatomic) CGFloat iconPointSize;
@property(nonatomic, strong, nullable) NSColor* iconTintColor;
@property(nonatomic) BOOL colored;
@property(nonatomic) CGFloat spacing;
@property(nonatomic, copy, nullable) NSString* buttonTitle;
@property(nonatomic) NSControlSize buttonControlSize;
@property(nonatomic) CGFloat buttonMinWidth;
@property(nonatomic, strong, nullable) NSFont* buttonFont;
@property(nonatomic) BOOL defaultButton;
@property(nonatomic, copy, nullable) void (^onAction)(void);
@property(nonatomic, readonly) NSButton* actionButton;

- (instancetype)initWithTitle:(nullable NSString*)title
                     subtitle:(nullable NSString*)subtitle
                       symbol:(nullable NSString*)symbolName
                iconPointSize:(CGFloat)iconPointSize
                      colored:(BOOL)colored
                  buttonTitle:(nullable NSString*)buttonTitle
                     onAction:(void (^_Nullable)(void))onAction;
@end

/// Settings-style hover popover: label on the left, value on the right.
/// Attach to any view; replaces a previous hover popover on that view.
/// Each row is `@[ label, value ]`. Pass an empty `rows` array to remove.
@interface DCHoverPopover : NSObject
@property(nonatomic, copy) NSArray<NSArray<NSString*>*>* rows;
/// Fixed popover width. `0` sizes to the row content.
@property(nonatomic) CGFloat width;
@property(nonatomic) CGFloat columnSpacing;
@property(nonatomic) CGFloat rowSpacing;
@property(nonatomic) NSEdgeInsets contentInsets;
@property(nonatomic, strong) NSFont* labelFont;
@property(nonatomic, strong) NSFont* valueFont;
@property(nonatomic, strong) NSColor* labelColor;
@property(nonatomic, strong) NSColor* valueColor;
@property(nonatomic) NSTextAlignment valueAlignment;
@property(nonatomic) NSRectEdge preferredEdge;
@property(nonatomic) BOOL animates;

- (instancetype)initWithRows:(NSArray<NSArray<NSString*>*>*)rows;
+ (instancetype)popoverWithRows:(NSArray<NSArray<NSString*>*>*)rows;
- (void)attachToView:(NSView*)view;
+ (void)attachToView:(NSView*)view rows:(NSArray<NSArray<NSString*>*>*)rows;
@end

void DCPinEdges(NSView* child, NSView* parent);
NSStackView* DCPageStack(NSView* host);
NSStackView* DCHeaderStack(NSString* title, NSString* subtitle);
NSStackView* DCTrailingButtons(NSArray<NSButton*>* buttons);
NSStackView* DCEqualButtonRow(NSArray<NSButton*>* buttons);
void DCStackFullWidth(NSStackView* stack, NSView* view);
/// Full-width slot that centers `view` at its intrinsic width. Returns the slot.
NSView* DCStackCentered(NSStackView* stack, NSView* view);
void DCStackExpand(NSStackView* stack, NSView* view);
NSView* DCFlexibleSpace(void);

/// Sheet on the main window when possible; otherwise a centered modal.
NSModalResponse DCPresentAlert(NSAlert* alert);

/// Increment `*jobSlot` and run `work` off the main thread. `done` runs on the
/// main queue only if this is still the latest job (stale completions are dropped).
void DCRunBackground(uint64_t* jobSlot, void (^work)(void), void (^_Nullable done)(void));
/// Coalesce UI progress from a worker: skip if the last update was less than `minMs` ms ago.
void DCDispatchMainThrottled(std::atomic<uint64_t>* lastMs, uint64_t minMs, void (^block)(void));

extern NSNotificationName const DCSettingsDidChangeNotification;

ui::AppearancePref DCAppearancePref(void);
void DCSetAppearancePref(ui::AppearancePref pref);
void DCApplyStoredAppearance(void);

ui::CleanPref DCCleanPref(void);
void DCSetCleanPref(ui::CleanPref pref);

/// Large Files minimum size, in mebibytes (1024-based MB). Default 50. Missing key → 50.
NSInteger DCLargeFileMinMB(void);
void DCSetLargeFileMinMB(NSInteger mb);
uint64_t DCLargeFileMinBytes(void);

/// Cancel is the default (Return). Copy follows the Cleaning setting.
BOOL DCConfirmClean(NSArray<NSString*>* paths, uint64_t bytes);
/// Space Lens: user-confirmed folders, including ones that are not on the safe list.
BOOL DCConfirmSpaceLensClean(NSArray<NSString*>* paths, uint64_t bytes);
BOOL DCConfirmMoveToTrash(NSArray<NSString*>* paths, uint64_t bytes);
BOOL DCConfirmDestructive(NSString* title, NSString* info, NSString* proceedTitle);
void DCRequestNotificationPermission(void);
void DCInformNothingToClean(NSString* detail);
void DCInformCleaned(NSString* title, NSString* detail);

void DCAttachTableMenu(NSTableView* table, id<NSMenuDelegate> delegate);
void DCAddPathMenuItems(NSMenu* menu, NSString* path);
void DCRevealInFinder(NSString* path);

NS_ASSUME_NONNULL_END

#pragma once

#import <Cocoa/Cocoa.h>

#include <string>

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

void DCPinEdges(NSView* child, NSView* parent);
NSStackView* DCPageStack(NSView* host);
NSStackView* DCHeaderStack(NSString* title, NSString* subtitle);
NSStackView* DCTrailingButtons(NSArray<NSButton*>* buttons);
NSStackView* DCEqualButtonRow(NSArray<NSButton*>* buttons);
void DCStackFullWidth(NSStackView* stack, NSView* view);
void DCStackExpand(NSStackView* stack, NSView* view);
NSView* DCFlexibleSpace(void);

/// Sheet on the main window when possible; otherwise a centered modal.
NSModalResponse DCPresentAlert(NSAlert* alert);

/// Cancel is the default (Return). Returns YES only if the user chose Move to Trash.
BOOL DCConfirmMoveToTrash(NSArray<NSString*>* paths, uint64_t bytes);
BOOL DCConfirmDestructive(NSString* title, NSString* info, NSString* proceedTitle);
void DCInformNothingToClean(NSString* detail);
void DCInformCleaned(NSString* title, NSString* detail);

#import "ui/SettingsView.h"
#import "ui/Theme.h"

#include "AppSettings.hpp"
#include "Modules.h"

#include <cctype>
#include <cstdlib>

@interface DCSettingsView () <NSTextFieldDelegate>
@end

@implementation DCSettingsView {
  NSPopUpButton* _appearance;
  NSPopUpButton* _cleaning;
  NSTextField* _largeFileMin;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Settings", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Settings)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);

    _appearance = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_appearance addItemsWithTitles:@[ @"System", @"Light", @"Dark" ]];
    _appearance.target = self;
    _appearance.action = @selector(appearanceChanged:);
    NSView* appearanceCard = [self cardTitle:@"Appearance"
                                      detail:@"Follow macOS, or lock the app to Light or Dark."
                                     control:_appearance];
    [page addArrangedSubview:appearanceCard];
    DCStackFullWidth(page, appearanceCard);

    _cleaning = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_cleaning addItemsWithTitles:@[ @"Move to Trash", @"Delete Permanently" ]];
    _cleaning.target = self;
    _cleaning.action = @selector(cleaningChanged:);
    NSView* cleaningCard = [self cardTitle:@"Cleaning"
                                    detail:@"Permanent delete cannot be undone"
                                   control:_cleaning];
    [page addArrangedSubview:cleaningCard];
    DCStackFullWidth(page, cleaningCard);

    _largeFileMin = [[NSTextField alloc] initWithFrame:NSZeroRect];
    _largeFileMin.translatesAutoresizingMaskIntoConstraints = NO;
    _largeFileMin.bezelStyle = NSTextFieldRoundedBezel;
    _largeFileMin.alignment = NSTextAlignmentRight;
    _largeFileMin.placeholderString = @"50";
    _largeFileMin.delegate = self;
    _largeFileMin.target = self;
    _largeFileMin.action = @selector(largeFileMinCommitted:);
    [_largeFileMin.widthAnchor constraintEqualToConstant:64].active = YES;
    NSTextField* mb = DCLabel(@"MB");
    mb.font = [NSFont systemFontOfSize:13];
    mb.textColor = [NSColor secondaryLabelColor];
    NSStackView* sizeRow = [NSStackView stackViewWithViews:@[ _largeFileMin, mb ]];
    sizeRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    sizeRow.alignment = NSLayoutAttributeCenterY;
    sizeRow.spacing = 6;
    [sizeRow setContentHuggingPriority:NSLayoutPriorityRequired
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
    [sizeRow setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSView* largeCard = [self cardTitle:@"Minimum Large Files threshold"
                                 detail:@"Minimum size to scan for large files"
                                control:sizeRow];
    [page addArrangedSubview:largeCard];
    DCStackFullWidth(page, largeCard);

    NSView* spacer = DCFlexibleSpace();
    [page addArrangedSubview:spacer];
    DCStackFullWidth(page, spacer);

    [self reloadFromDefaults];
  }
  return self;
}

- (NSView*)cardTitle:(NSString*)title detail:(NSString*)detail control:(NSView*)control {
  NSTextField* t = DCLabel(title);
  t.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  NSTextField* d = DCCaptionLabel(detail);
  d.maximumNumberOfLines = 4;
  d.lineBreakMode = NSLineBreakByWordWrapping;
  control.translatesAutoresizingMaskIntoConstraints = NO;
  NSStackView* text = [NSStackView stackViewWithViews:@[ t, d ]];
  text.orientation = NSUserInterfaceLayoutOrientationVertical;
  text.alignment = NSLayoutAttributeLeading;
  text.spacing = 2;
  NSView* gap = [[NSView alloc] initWithFrame:NSZeroRect];
  [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [gap setContentCompressionResistancePriority:1
                               forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView* body = [NSStackView stackViewWithViews:@[ text, gap, control ]];
  body.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  body.alignment = NSLayoutAttributeCenterY;
  body.distribution = NSStackViewDistributionFill;
  body.spacing = 16;
  [text setContentHuggingPriority:NSLayoutPriorityDefaultLow
                   forOrientation:NSLayoutConstraintOrientationHorizontal];
  [text setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [control setContentHuggingPriority:NSLayoutPriorityRequired
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
  [control setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
  body.edgeInsets = NSEdgeInsetsMake(14, 14, 14, 14);

  NSVisualEffectView* card = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
  card.material = NSVisualEffectMaterialContentBackground;
  card.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  card.state = NSVisualEffectStateFollowsWindowActiveState;
  card.wantsLayer = YES;
  card.layer.cornerRadius = 10;
  card.layer.masksToBounds = YES;
  [card addSubview:body];
  DCPinEdges(body, card);
  return card;
}

- (void)reloadFromDefaults {
  [_appearance selectItemAtIndex:static_cast<NSInteger>(DCAppearancePref())];
  [_cleaning selectItemAtIndex:static_cast<NSInteger>(DCCleanPref())];
  _largeFileMin.stringValue = [NSString stringWithFormat:@"%ld", (long)DCLargeFileMinMB()];
}

- (void)appearanceChanged:(NSPopUpButton*)sender {
  NSInteger i = sender.indexOfSelectedItem;
  if (i < 0 || i > 2) i = 0;
  DCSetAppearancePref(static_cast<ui::AppearancePref>(i));
}

- (void)cleaningChanged:(NSPopUpButton*)sender {
  auto p = sender.indexOfSelectedItem == 1 ? ui::CleanPref::DeletePermanently
                                           : ui::CleanPref::MoveToTrash;
  DCSetCleanPref(p);
}

- (void)commitLargeFileMin {
  NSInteger fallback = (NSInteger)(ui::kDefaultLargeFileMinBytes / ui::kMebibyte);
  NSString* raw = [_largeFileMin.stringValue stringByTrimmingCharactersInSet:
                                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (raw.length == 0) {
    DCSetLargeFileMinMB(fallback);
    [self reloadFromDefaults];
    return;
  }
  NSScanner* scan = [NSScanner scannerWithString:raw];
  NSInteger parsed = 0;
  if (![scan scanInteger:&parsed] || !scan.atEnd) {
    DCSetLargeFileMinMB(fallback);
    [self reloadFromDefaults];
    return;
  }
  DCSetLargeFileMinMB(std::abs(parsed));
  [self reloadFromDefaults];
}

- (void)largeFileMinCommitted:(id)sender {
  (void)sender;
  [self commitLargeFileMin];
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
  if (notification.object == _largeFileMin) [self commitLargeFileMin];
}

- (BOOL)control:(NSControl*)control
       textView:(NSTextView*)textView
shouldChangeTextInRange:(NSRange)range
replacementString:(NSString*)string {
  (void)textView;
  (void)range;
  if (control != _largeFileMin) return YES;
  for (NSUInteger i = 0; i < string.length; ++i) {
    if (!std::isdigit(static_cast<unsigned char>([string characterAtIndex:i]))) return NO;
  }
  return YES;
}

@end

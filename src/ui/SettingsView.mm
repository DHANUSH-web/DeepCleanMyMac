#import "ui/SettingsView.h"
#import "ui/Theme.h"

#include "AppSettings.hpp"
#include "Modules.h"

@implementation DCSettingsView {
  NSPopUpButton* _appearance;
  NSPopUpButton* _cleaning;
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
  control.translatesAutoresizingMaskIntoConstraints = NO;
  [control.widthAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
  NSStackView* text = [NSStackView stackViewWithViews:@[ t, d ]];
  text.orientation = NSUserInterfaceLayoutOrientationVertical;
  text.alignment = NSLayoutAttributeLeading;
  text.spacing = 2;
  NSStackView* body = [NSStackView stackViewWithViews:@[ text, control ]];
  body.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  body.alignment = NSLayoutAttributeCenterY;
  body.spacing = 16;
  [text setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
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

@end

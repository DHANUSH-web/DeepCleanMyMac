#import "ui/SettingsView.h"
#import "ui/Theme.h"

#include "AppSettings.hpp"
#include "Modules.h"

#include <cctype>
#include <cmath>
#include <cstdlib>

@interface DCSliderTickLabels : NSView
@property(nonatomic, weak) NSSlider* slider;
@property(nonatomic, copy) NSArray<NSTextField*>* labels;
@end

@implementation DCSliderTickLabels
- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setSlider:(NSSlider*)slider
{
  if (_slider == slider)
  {
    return;
  }
  if (_slider)
  {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewFrameDidChangeNotification
                                                  object:_slider];
  }
  _slider = slider;
  _slider.postsFrameChangedNotifications = YES;
  if (_slider)
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sliderFrameChanged:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:_slider];
  }
  [self setNeedsLayout:YES];
}

- (void)sliderFrameChanged:(NSNotification*)note
{
  (void)note;
  [self setNeedsLayout:YES];
}

- (void)layout
{
  [super layout];
  NSSlider* slider = self.slider;
  if (!slider || slider.numberOfTickMarks <= 0)
  {
    return;
  }
  const CGFloat hostW = NSWidth(self.bounds);
  const CGFloat hostH = NSHeight(self.bounds);
  const NSInteger n   = MIN((NSInteger)self.labels.count, slider.numberOfTickMarks);
  for (NSInteger i = 0; i < n; ++i)
  {
    NSTextField* lab = self.labels[(NSUInteger)i];
    [lab sizeToFit];
    NSRect tick  = [slider rectOfTickMarkAtIndex:i];
    NSPoint mid  = [slider convertPoint:NSMakePoint(NSMidX(tick), NSMidY(tick)) toView:self];
    NSRect frame = lab.frame;
    frame.origin.x = round(mid.x - NSWidth(frame) / 2.0);
    frame.origin.y = round((hostH - NSHeight(frame)) / 2.0);
    if (frame.origin.x < 0)
    {
      frame.origin.x = 0;
    }
    if (NSMaxX(frame) > hostW)
    {
      frame.origin.x = hostW - NSWidth(frame);
    }
    lab.frame = frame;
  }
}
@end

@interface DCSettingsView () <NSTextFieldDelegate>
@end

@implementation DCSettingsView
{
  NSPopUpButton* _appearance;
  NSPopUpButton* _cleaning;
  NSTextField* _largeFileMin;
  NSSwitch* _dupHome;
  NSSlider* _dupMin;
  DCSliderTickLabels* _dupMinTicks;
}

- (instancetype)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    NSStackView* page   = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Settings", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Settings)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);

    _appearance = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_appearance addItemsWithTitles:@[ @"System", @"Light", @"Dark" ]];
    _appearance.target     = self;
    _appearance.action     = @selector(appearanceChanged:);
    NSView* appearanceCard = [self cardTitle:@"Appearance"
                                      detail:@"Follow macOS, or lock the app to Light or Dark."
                                     control:_appearance];
    [page addArrangedSubview:appearanceCard];
    DCStackFullWidth(page, appearanceCard);

    _cleaning = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_cleaning addItemsWithTitles:@[ @"Move to Trash", @"Delete Permanently" ]];
    _cleaning.target     = self;
    _cleaning.action     = @selector(cleaningChanged:);
    NSView* cleaningCard = [self cardTitle:@"Cleaning"
                                    detail:@"Permanent delete cannot be undone"
                                   control:_cleaning];
    [page addArrangedSubview:cleaningCard];
    DCStackFullWidth(page, cleaningCard);

    _largeFileMin = [[NSTextField alloc] initWithFrame:NSZeroRect];
    _largeFileMin.translatesAutoresizingMaskIntoConstraints = NO;
    _largeFileMin.bezelStyle                                = NSTextFieldRoundedBezel;
    _largeFileMin.alignment                                 = NSTextAlignmentRight;
    _largeFileMin.placeholderString                         = @"50";
    _largeFileMin.delegate                                  = self;
    _largeFileMin.target                                    = self;
    _largeFileMin.action                                    = @selector(largeFileMinCommitted:);
    [_largeFileMin.widthAnchor constraintEqualToConstant:64].active = YES;
    NSTextField* mb                                                 = DCLabel(@"MB");
    mb.font                                                         = [NSFont systemFontOfSize:13];
    mb.textColor                                                    = [NSColor secondaryLabelColor];
    NSStackView* sizeRow = [NSStackView stackViewWithViews:@[ _largeFileMin, mb ]];
    sizeRow.orientation  = NSUserInterfaceLayoutOrientationHorizontal;
    sizeRow.alignment    = NSLayoutAttributeCenterY;
    sizeRow.spacing      = 6;
    [sizeRow setContentHuggingPriority:NSLayoutPriorityRequired
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
    [sizeRow setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSView* largeCard = [self cardTitle:@"Minimum Large Files threshold"
                                 detail:@"Minimum size to scan for large files"
                                control:sizeRow];
    [page addArrangedSubview:largeCard];
    DCStackFullWidth(page, largeCard);

    _dupHome        = [[NSSwitch alloc] initWithFrame:NSZeroRect];
    _dupHome.target = self;
    _dupHome.action = @selector(duplicatesHomeChanged:);
    [_dupHome setContentHuggingPriority:NSLayoutPriorityRequired
                         forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSView* dupCard =
        [self cardTitle:@"Look for duplicates at Home"
                 detail:@"Scan for entire home directory to find duplicate items beyond defaults."
                control:_dupHome];
    [page addArrangedSubview:dupCard];
    DCStackFullWidth(page, dupCard);

    _dupMin                            = [NSSlider sliderWithValue:5 minValue:0 maxValue:5
                                                            target:self
                                                            action:@selector(duplicatesMinChanged:)];
    _dupMin.numberOfTickMarks          = 6;
    _dupMin.allowsTickMarkValuesOnly   = YES;
    _dupMin.tickMarkPosition           = NSTickMarkPositionBelow;
    _dupMin.continuous                 = YES;
    _dupMin.translatesAutoresizingMaskIntoConstraints = NO;
    NSMutableArray<NSTextField*>* tickLabs = [NSMutableArray array];
    _dupMinTicks                           = [[DCSliderTickLabels alloc] initWithFrame:NSZeroRect];
    _dupMinTicks.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSString* title in @[ @"All", @"50KB", @"100KB", @"150KB", @"200KB", @"256KB" ])
    {
      NSTextField* lab         = DCCaptionLabel(title);
      lab.alignment            = NSTextAlignmentCenter;
      lab.maximumNumberOfLines = 1;
      lab.lineBreakMode        = NSLineBreakByClipping;
      [_dupMinTicks addSubview:lab];
      [tickLabs addObject:lab];
    }
    _dupMinTicks.slider = _dupMin;
    _dupMinTicks.labels = tickLabs;
    [_dupMinTicks.heightAnchor constraintEqualToConstant:16].active = YES;
    NSTextField* dupMinTitle = DCLabel(@"Minimum duplicate size");
    dupMinTitle.font         = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    NSTextField* dupMinDetail =
        DCCaptionLabel(@"Skip files smaller than this. All includes every size. Default 256KB.");
    dupMinDetail.maximumNumberOfLines = 4;
    dupMinDetail.lineBreakMode        = NSLineBreakByWordWrapping;
    NSStackView* dupMinBody =
        [NSStackView stackViewWithViews:@[ dupMinTitle, dupMinDetail, _dupMin, _dupMinTicks ]];
    dupMinBody.orientation = NSUserInterfaceLayoutOrientationVertical;
    dupMinBody.alignment   = NSLayoutAttributeLeading;
    dupMinBody.spacing     = 8;
    dupMinBody.edgeInsets  = NSEdgeInsetsMake(14, 14, 14, 14);
    DCStackFullWidth(dupMinBody, _dupMin);
    DCStackFullWidth(dupMinBody, _dupMinTicks);
    NSVisualEffectView* dupMinCard = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    dupMinCard.material            = NSVisualEffectMaterialContentBackground;
    dupMinCard.blendingMode        = NSVisualEffectBlendingModeWithinWindow;
    dupMinCard.state               = NSVisualEffectStateFollowsWindowActiveState;
    dupMinCard.wantsLayer          = YES;
    dupMinCard.layer.cornerRadius  = 10;
    dupMinCard.layer.masksToBounds = YES;
    [dupMinCard addSubview:dupMinBody];
    DCPinEdges(dupMinBody, dupMinCard);
    [page addArrangedSubview:dupMinCard];
    DCStackFullWidth(page, dupMinCard);

    NSView* spacer = DCFlexibleSpace();
    [page addArrangedSubview:spacer];
    DCStackFullWidth(page, spacer);

    [self reloadFromDefaults];
  }
  return self;
}

- (NSView*)cardTitle:(NSString*)title detail:(NSString*)detail control:(NSView*)control
{
  NSTextField* t         = DCLabel(title);
  t.font                 = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  NSTextField* d         = DCCaptionLabel(detail);
  d.maximumNumberOfLines = 4;
  d.lineBreakMode        = NSLineBreakByWordWrapping;
  control.translatesAutoresizingMaskIntoConstraints = NO;
  NSStackView* text                                 = [NSStackView stackViewWithViews:@[ t, d ]];
  text.orientation                                  = NSUserInterfaceLayoutOrientationVertical;
  text.alignment                                    = NSLayoutAttributeLeading;
  text.spacing                                      = 2;
  NSView* gap                                       = [[NSView alloc] initWithFrame:NSZeroRect];
  [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [gap setContentCompressionResistancePriority:1
                                forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView* body = [NSStackView stackViewWithViews:@[ text, gap, control ]];
  body.orientation  = NSUserInterfaceLayoutOrientationHorizontal;
  body.alignment    = NSLayoutAttributeCenterY;
  body.distribution = NSStackViewDistributionFill;
  body.spacing      = 16;
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
  card.material            = NSVisualEffectMaterialContentBackground;
  card.blendingMode        = NSVisualEffectBlendingModeWithinWindow;
  card.state               = NSVisualEffectStateFollowsWindowActiveState;
  card.wantsLayer          = YES;
  card.layer.cornerRadius  = 10;
  card.layer.masksToBounds = YES;
  [card addSubview:body];
  DCPinEdges(body, card);
  return card;
}

- (void)reloadFromDefaults
{
  [_appearance selectItemAtIndex:static_cast<NSInteger>(DCAppearancePref())];
  [_cleaning selectItemAtIndex:static_cast<NSInteger>(DCCleanPref())];
  _largeFileMin.stringValue = [NSString stringWithFormat:@"%ld", (long)DCLargeFileMinMB()];
  _dupHome.state     = DCDuplicatesScanHome() ? NSControlStateValueOn : NSControlStateValueOff;
  _dupMin.doubleValue = DCDuplicatesMinKBStopIndex();
}

- (void)appearanceChanged:(NSPopUpButton*)sender
{
  NSInteger i = sender.indexOfSelectedItem;
  if (i < 0 || i > 2)
  {
    i = 0;
  }
  DCSetAppearancePref(static_cast<ui::AppearancePref>(i));
}

- (void)duplicatesHomeChanged:(NSSwitch*)sender
{
  DCSetDuplicatesScanHome(sender.state == NSControlStateValueOn);
}

- (void)duplicatesMinChanged:(NSSlider*)sender
{
  DCSetDuplicatesMinKBStopIndex((NSInteger)llround(sender.doubleValue));
}

- (void)cleaningChanged:(NSPopUpButton*)sender
{
  auto p = sender.indexOfSelectedItem == 1 ? ui::CleanPref::DeletePermanently
                                           : ui::CleanPref::MoveToTrash;
  DCSetCleanPref(p);
}

- (void)commitLargeFileMin
{
  NSInteger fallback = (NSInteger)(ui::kDefaultLargeFileMinBytes / ui::kMebibyte);
  NSString* raw      = [_largeFileMin.stringValue
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (raw.length == 0)
  {
    DCSetLargeFileMinMB(fallback);
    [self reloadFromDefaults];
    return;
  }
  NSScanner* scan  = [NSScanner scannerWithString:raw];
  NSInteger parsed = 0;
  if (![scan scanInteger:&parsed] || !scan.atEnd)
  {
    DCSetLargeFileMinMB(fallback);
    [self reloadFromDefaults];
    return;
  }
  DCSetLargeFileMinMB(std::abs(parsed));
  [self reloadFromDefaults];
}

- (void)largeFileMinCommitted:(id)sender
{
  (void)sender;
  [self commitLargeFileMin];
}

- (void)controlTextDidEndEditing:(NSNotification*)notification
{
  if (notification.object == _largeFileMin)
  {
    [self commitLargeFileMin];
  }
}

- (BOOL)control:(NSControl*)control
                   textView:(NSTextView*)textView
    shouldChangeTextInRange:(NSRange)range
          replacementString:(NSString*)string
{
  (void)textView;
  (void)range;
  if (control != _largeFileMin)
  {
    return YES;
  }
  for (NSUInteger i = 0; i < string.length; ++i)
  {
    if (!std::isdigit(static_cast<unsigned char>([string characterAtIndex:i])))
    {
      return NO;
    }
  }
  return YES;
}

@end

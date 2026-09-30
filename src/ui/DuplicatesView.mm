#import "ui/DuplicatesView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCDupFlippedDoc : NSView
@end
@implementation DCDupFlippedDoc
- (BOOL)isFlipped
{
  return YES;
}
@end

@interface DCDuplicatesView ()
- (void)trashPaths:(std::vector<std::string>)paths bytes:(uint64_t)bytes;
@end

@implementation DCDuplicatesView
{
  dcmm::Engine _engine;
  std::vector<dcmm::DuplicateGroup> _groups;
  NSButton* _scan;
  NSButton* _clean;
  NSTextField* _status;
  NSStackView* _content;
  DCStartScreen* _startScreen;
  NSScrollView* _groupsScroll;
  DCDupFlippedDoc* _groupsDoc;
  NSStackView* _groupsList;
  uint64_t _job;
}

- (instancetype)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    NSStackView* page   = DCPageStack(self);
    _content            = page;
    NSStackView* header = DCHeaderStack(
        @"Duplicates", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Duplicates)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _scan         = [DCGlowButton defaultButtonWithTitle:@"Scan"
                                                  target:self
                                                  action:@selector(startScan)
                                               glowColor:NSColor.controlAccentColor
                                           glowLineWidth:2.5
                                               clockwise:YES];
    _clean        = DCDestructiveButton(@"Move Copies to Trash", self, @selector(cleanSelected));
    _clean.hidden = YES;
    NSStackView* actions = DCTrailingButtons(@[ _clean, _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status             = DCCaptionLabel(@"");
    _status.stringValue = [self idleStatus];
    [page addArrangedSubview:_status];

    _groupsScroll                       = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _groupsScroll.drawsBackground       = NO;
    _groupsScroll.hasVerticalScroller   = YES;
    _groupsScroll.hasHorizontalScroller = NO;
    _groupsScroll.autohidesScrollers    = YES;
    _groupsScroll.borderType            = NSNoBorder;
    _groupsScroll.automaticallyAdjustsContentInsets = NO;
    _groupsScroll.contentInsets                     = NSEdgeInsetsZero;
    _groupsScroll.usesPredominantAxisScrolling      = YES;
    _groupsScroll.horizontalScrollElasticity        = NSScrollElasticityNone;

    _groupsDoc               = [[DCDupFlippedDoc alloc] initWithFrame:NSZeroRect];
    _groupsList              = [NSStackView stackViewWithViews:@[]];
    _groupsList.orientation  = NSUserInterfaceLayoutOrientationVertical;
    _groupsList.alignment    = NSLayoutAttributeLeading;
    _groupsList.distribution = NSStackViewDistributionFill;
    _groupsList.spacing      = 12;
    _groupsList.translatesAutoresizingMaskIntoConstraints = NO;
    [_groupsDoc addSubview:_groupsList];
    [NSLayoutConstraint activateConstraints:@[
      [_groupsList.topAnchor constraintEqualToAnchor:_groupsDoc.topAnchor],
      [_groupsList.leadingAnchor constraintEqualToAnchor:_groupsDoc.leadingAnchor],
      [_groupsList.trailingAnchor constraintEqualToAnchor:_groupsDoc.trailingAnchor],
      [_groupsList.bottomAnchor constraintEqualToAnchor:_groupsDoc.bottomAnchor],
    ]];
    _groupsScroll.documentView = _groupsDoc;
    DCStackExpand(page, _groupsScroll);

    __weak DCDuplicatesView* weakSelf = self;
    _startScreen                      = [[DCStartScreen alloc]
        initWithTitle:@"Duplicates"
             subtitle:[NSString stringWithUTF8String:ui::subtitle(ui::Module::Duplicates)]
               symbol:[NSString stringWithUTF8String:ui::sidebarSymbol(ui::Module::Duplicates)]
        iconPointSize:250
              colored:NO
          buttonTitle:@"Scan"
             onAction:^{
               [weakSelf startScan];
             }];
    _startScreen.subtitleMaxWidth     = 360;
    _startScreen.buttonControlSize    = NSControlSizeLarge;
    _startScreen.buttonMinWidth       = 100;
    _startScreen.buttonFont           = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    _startScreen.defaultButton        = YES;
    [self addSubview:_startScreen];
    DCPinEdges(_startScreen, self);
    _content.hidden     = YES;
    _scan.keyEquivalent = @"";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged)
                                                 name:DCSettingsDidChangeNotification
                                               object:nil];
    [self refreshCleanTitle];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layout
{
  [super layout];
  CGFloat w = NSWidth(_groupsScroll.contentView.bounds);
  if (w < 1)
  {
    return;
  }
  CGFloat h  = MAX(_groupsList.fittingSize.height, 1);
  NSRect doc = NSMakeRect(0, 0, w, h);
  if (NSEqualRects(_groupsDoc.frame, doc))
  {
    return;
  }
  NSPoint saved    = _groupsScroll.contentView.bounds.origin;
  _groupsDoc.frame = doc;
  [_groupsScroll.contentView setBoundsOrigin:saved];
}

- (NSString*)idleStatus
{
  if (DCDuplicatesScanHome())
  {
    return @"Matches identical files in your home folder (256 KB or larger).";
  }
  return @"Matches identical files in Documents, Downloads, Desktop, Pictures, Movies, and Music "
         @"(256 KB or larger).";
}

- (void)settingsChanged
{
  [self refreshCleanTitle];
  if (_startScreen && !_startScreen.hidden)
  {
    _status.stringValue = [self idleStatus];
  }
}

- (void)refreshCleanTitle
{
  _clean.title  = DCCleanPref() == ui::CleanPref::DeletePermanently ? @"Delete Copies Permanently"
                                                                    : @"Move Copies to Trash";
  _clean.hidden = ui::duplicatePathsToTrash(_groups).empty();
}

- (void)clearGroups
{
  NSArray<NSView*>* old = [_groupsList.arrangedSubviews copy];
  for (NSView* v in old)
  {
    [_groupsList removeArrangedSubview:v];
    [v removeFromSuperview];
  }
}

- (void)rebuildGroups
{
  [self clearGroups];
  for (int g = 0; g < (int)_groups.size(); ++g)
  {
    auto& group = _groups[(size_t)g];
    if (group.files.empty())
    {
      continue;
    }
    NSString* title                             = DCNS(group.files[0].path).lastPathComponent;
    NSMutableArray<DCDuplicateItemCard*>* cards = [NSMutableArray array];
    for (int f = 0; f < (int)group.files.size(); ++f)
    {
      auto& file                        = group.files[(size_t)f];
      DCDuplicateItemCard* card         = [[DCDuplicateItemCard alloc] initWithPath:DCNS(file.path)
                                                                              bytes:file.bytes
                                                                           selected:!file.keep];
      __weak DCDuplicatesView* weakSelf = self;
      __weak DCDuplicateItemCard* weakCard = card;
      const int gi                         = g;
      const int fi                         = f;
      card.onToggle                        = ^(DCDuplicateItemCard*) {
        DCDuplicatesView* s    = weakSelf;
        DCDuplicateItemCard* c = weakCard;
        if (!s || !c)
        {
          return;
        }
        if (gi < 0 || gi >= (int)s->_groups.size())
        {
          return;
        }
        if (fi < 0 || fi >= (int)s->_groups[(size_t)gi].files.size())
        {
          return;
        }
        s->_groups[(size_t)gi].files[(size_t)fi].keep = !c.selected;
        [s refreshCleanTitle];
      };
      card.onTrash = ^(DCDuplicateItemCard* c) {
        DCDuplicatesView* s = weakSelf;
        if (!s || !c.path.length)
        {
          return;
        }
        [s trashPaths:std::vector<std::string>{c.path.UTF8String ?: ""} bytes:c.bytes];
      };
      [cards addObject:card];
    }
    DCDuplicateGroupView* row = [[DCDuplicateGroupView alloc] initWithTitle:title cards:cards];
    [_groupsList addArrangedSubview:row];
    DCStackFullWidth(_groupsList, row);
  }
  [self setNeedsLayout:YES];
}

- (void)showContent
{
  if (!_startScreen || _startScreen.hidden)
  {
    return;
  }
  _startScreen.hidden = YES;
  _content.hidden     = NO;
  _scan.keyEquivalent = @"\r";
}

- (void)showNothingFound
{
  _scan.keyEquivalent = @"";
  [_startScreen configureSymbol:@"checkmark.seal.fill"
                       subtitle:@"Everything is clean"
                    buttonTitle:@"Scan Again"
                      tintColor:NSColor.controlAccentColor
                  defaultButton:YES
                   appearBounce:YES];
  _startScreen.hidden = NO;
  _content.hidden     = YES;
}

- (void)setScanEnabled:(BOOL)on
{
  _scan.enabled                     = on;
  _startScreen.actionButton.enabled = on;
}

- (void)startScan
{
  if (!_scan.enabled)
  {
    return;
  }
  _status.stringValue = @"Hashing…";
  if (_startScreen && !_startScreen.hidden)
  {
    [_startScreen beginProgress];
  }
  DCGlowButtonSetActive(_scan, YES);
  DCGlowButtonSetActive(_startScreen.actionButton, YES);
  [self setScanEnabled:NO];
  _clean.hidden                     = YES;
  __weak DCDuplicatesView* weakSelf = self;
  __block std::vector<dcmm::DuplicateGroup> g;
  DCRunBackground(
      &_job,
      ^{
        DCDuplicatesView* strong = weakSelf;
        if (!strong)
        {
          return;
        }
        g = strong->_engine.findDuplicates(
            ui::duplicateOptions(dcmm::homeDirectory(), DCDuplicatesScanHome()));
      },
      ^{
        DCDuplicatesView* s = weakSelf;
        if (!s)
        {
          return;
        }
        s->_groups = std::move(g);
        [s setScanEnabled:YES];
        DCGlowButtonSetActive(s->_startScreen.actionButton, NO);
        [s->_startScreen endProgress];
        if (s->_groups.empty())
        {
          [s clearGroups];
          [s showNothingFound];
          return;
        }
        [s rebuildGroups];
        DCGlowButtonSetActive(s->_scan, NO);
        s->_status.stringValue =
            [NSString stringWithFormat:@"%lu duplicate groups", (unsigned long)s->_groups.size()];
        [s refreshCleanTitle];
        [s showContent];
      });
}

- (void)trashPaths:(std::vector<std::string>)paths bytes:(uint64_t)bytes
{
  if (paths.empty())
  {
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  for (const auto& p : paths)
  {
    [list addObject:DCNS(p)];
  }
  if (!DCConfirmClean(list, bytes))
  {
    return;
  }
  const auto mode = DCCleanPref();
  [self setScanEnabled:NO];
  _clean.hidden                     = YES;
  __weak DCDuplicatesView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(
      &_job,
      ^{
        DCDuplicatesView* strong = weakSelf;
        if (!strong)
        {
          return;
        }
        r = ui::applyClean(strong->_engine, paths, mode);
      },
      ^{
        DCDuplicatesView* s = weakSelf;
        if (!s)
        {
          return;
        }
        [s setScanEnabled:YES];
        if (r.trashedItems == 0)
        {
          DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
        }
        else
        {
          NSString* msg          = DCNS(ui::cleanFinishedDetail(mode, r));
          s->_status.stringValue = msg;
          DCInformCleaned(@"Clean finished", msg);
        }
        [s startScan];
      });
}

- (void)cleanSelected
{
  auto paths = ui::duplicatePathsToTrash(_groups);
  if (paths.empty())
  {
    DCInformNothingToClean(@"Every copy is marked Keep. Nothing was deleted.");
    return;
  }
  uint64_t bytes = 0;
  for (auto& group : _groups)
  {
    for (auto& f : group.files)
    {
      if (!f.keep)
      {
        bytes += f.bytes;
      }
    }
  }
  [self trashPaths:std::move(paths) bytes:bytes];
}

@end

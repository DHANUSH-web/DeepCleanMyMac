#import "ui/UninstallerView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/mac/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCUninstallAppCard : NSView <NSMenuDelegate>
@property(nonatomic) NSInteger index;
@property(nonatomic) BOOL selected;
@property(nonatomic, copy) void (^onToggle)(NSInteger index);
- (instancetype)initWithName:(NSString*)name
                        path:(NSString*)path
                       bytes:(uint64_t)bytes
                    selected:(BOOL)selected
                       index:(NSInteger)index;
@end

@interface DCUninstallerView ()
@end

@interface DCUninstallGridDoc : NSView
@end

@implementation DCUninstallGridDoc
- (BOOL)isFlipped
{
  return YES;
}
@end

@implementation DCUninstallAppCard
{
  NSString* _path;
  NSImageView* _icon;
}

- (instancetype)initWithName:(NSString*)name
                        path:(NSString*)path
                       bytes:(uint64_t)bytes
                    selected:(BOOL)selected
                       index:(NSInteger)index
{
  self = [super initWithFrame:NSZeroRect];
  if (self)
  {
    _path                                          = [path copy] ?: @"";
    _index                                         = index;
    _selected                                      = selected;
    self.wantsLayer                                = YES;
    self.layer.cornerRadius                        = 10;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _icon                              = [[NSImageView alloc] initWithFrame:NSZeroRect];
    NSImage* img                       = [[[NSWorkspace sharedWorkspace] iconForFile:_path] copy];
    img.size                           = NSMakeSize(56, 56);
    _icon.image                        = img;
    _icon.imageScaling                 = NSImageScaleProportionallyUpOrDown;
    _icon.translatesAutoresizingMaskIntoConstraints = NO;
    [_icon.widthAnchor constraintEqualToConstant:56].active  = YES;
    [_icon.heightAnchor constraintEqualToConstant:56].active = YES;

    NSTextField* title         = DCLabel(name.length ? name : _path.lastPathComponent);
    title.font                 = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    title.alignment            = NSTextAlignmentCenter;
    title.lineBreakMode        = NSLineBreakByTruncatingTail;
    title.usesSingleLineMode   = YES;
    title.maximumNumberOfLines = 1;
    [title setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];

    DCSizeBadge* badge = [[DCSizeBadge alloc] initWithBytes:bytes];

    NSStackView* col = [NSStackView stackViewWithViews:@[ _icon, title, badge ]];
    col.orientation  = NSUserInterfaceLayoutOrientationVertical;
    col.alignment    = NSLayoutAttributeCenterX;
    col.spacing      = 8;
    col.edgeInsets   = NSEdgeInsetsMake(12, 10, 12, 10);
    col.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:col];
    [NSLayoutConstraint activateConstraints:@[
      [col.topAnchor constraintEqualToAnchor:self.topAnchor],
      [col.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [col.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [col.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [self.heightAnchor constraintGreaterThanOrEqualToConstant:118],
    ]];
    [title.widthAnchor constraintEqualToAnchor:col.widthAnchor constant:-20].active = YES;

    NSMenu* menu          = [[NSMenu alloc] initWithTitle:@""];
    menu.delegate         = self;
    menu.autoenablesItems = YES;
    self.menu             = menu;
    [self applyChrome];
  }
  return self;
}

- (void)applyChrome
{
  NSColor* accent = NSColor.controlAccentColor;
  NSColor* fill   = _selected ? [accent colorWithAlphaComponent:0.22] : NSColor.controlBackgroundColor;
  NSColor* border = _selected ? accent : NSColor.separatorColor;
  __weak DCUninstallAppCard* weakSelf = self;
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    DCUninstallAppCard* s = weakSelf;
    if (!s)
    {
      return;
    }
    s.layer.backgroundColor = fill.CGColor;
    s.layer.borderColor     = border.CGColor;
  }];
  self.layer.borderWidth = _selected ? 2 : 1;
}

- (void)viewDidChangeEffectiveAppearance
{
  [super viewDidChangeEffectiveAppearance];
  [self applyChrome];
}

- (void)mouseUp:(NSEvent*)event
{
  (void)event;
  if (self.onToggle)
  {
    self.onToggle(self.index);
  }
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
  [menu removeAllItems];
  if (!_path.length)
  {
    return;
  }
  DCAddPathMenuItems(menu, _path);
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* sel = [[NSMenuItem alloc] initWithTitle:_selected ? @"Unselect" : @"Select"
                                               action:@selector(ctxToggle:)
                                        keyEquivalent:@""];
  sel.target = self;
  [menu addItem:sel];
}

- (void)ctxToggle:(id)sender
{
  (void)sender;
  if (self.onToggle)
  {
    self.onToggle(self.index);
  }
}

@end

@implementation DCUninstallerView
{
  dcmm::Engine _engine;
  struct AppRow
  {
    dcmm::InstalledApp app;
    bool selected = false;
  };
  std::vector<AppRow> _apps;
  DCGlowButton* _reload;
  NSButton* _selAll;
  NSButton* _remove;
  NSTextField* _status;
  NSScrollView* _scroll;
  DCUninstallGridDoc* _doc;
  NSStackView* _grid;
  NSStackView* _content;
  DCStartScreen* _startScreen;
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
        @"Uninstaller", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Uninstaller)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _reload              = [DCGlowButton defaultButtonWithTitle:@"Refresh"
                                                         target:self
                                                         action:@selector(reloadApps)
                                                      glowColor:NSColor.controlAccentColor
                                                  glowLineWidth:2.5
                                                      clockwise:YES];
    _selAll              = DCPushButton(@"Select All", self, @selector(toggleAll));
    _remove              = DCDestructiveButton(@"Uninstall", self, @selector(uninstall));
    _remove.hidden       = YES;
    NSStackView* actions = DCTrailingButtons(@[ _selAll, _reload, _remove ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(
        @"Check one or more apps to uninstall. Leftover files are removed with the app.");
    [page addArrangedSubview:_status];

    _scroll                    = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _scroll.drawsBackground    = NO;
    _scroll.hasVerticalScroller = YES;
    _scroll.borderType         = NSNoBorder;
    _doc                       = [[DCUninstallGridDoc alloc] initWithFrame:NSZeroRect];
    _grid                      = [NSStackView stackViewWithViews:@[]];
    _grid.orientation          = NSUserInterfaceLayoutOrientationVertical;
    _grid.alignment            = NSLayoutAttributeLeading;
    _grid.spacing              = 12;
    _grid.translatesAutoresizingMaskIntoConstraints = NO;
    [_doc addSubview:_grid];
    [NSLayoutConstraint activateConstraints:@[
      [_grid.topAnchor constraintEqualToAnchor:_doc.topAnchor],
      [_grid.leadingAnchor constraintEqualToAnchor:_doc.leadingAnchor],
      [_grid.trailingAnchor constraintEqualToAnchor:_doc.trailingAnchor],
      [_grid.bottomAnchor constraintEqualToAnchor:_doc.bottomAnchor],
    ]];
    _scroll.documentView = _doc;
    DCStackExpand(page, _scroll);
    __weak DCUninstallerView* weakSelf = self;
    _startScreen                       = [[DCStartScreen alloc]
        initWithTitle:@"Uninstaller"
             subtitle:[NSString stringWithUTF8String:ui::subtitle(ui::Module::Uninstaller)]
               symbol:[NSString stringWithUTF8String:ui::sidebarSymbol(ui::Module::Uninstaller)]
        iconPointSize:250
              colored:NO
          buttonTitle:@"Scan Apps"
             onAction:^{
               [weakSelf reloadApps];
             }];
    _startScreen.subtitleMaxWidth      = 360;
    _startScreen.buttonControlSize     = NSControlSizeLarge;
    _startScreen.buttonMinWidth        = 100;
    _startScreen.buttonFont            = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    _startScreen.defaultButton         = YES;
    [self addSubview:_startScreen];
    DCPinEdges(_startScreen, self);
    _content.hidden       = YES;
    _reload.keyEquivalent = @"";
    [self refreshUninstall];
  }
  return self;
}

- (void)showContent
{
  _startScreen.hidden   = YES;
  _content.hidden       = NO;
  _reload.keyEquivalent = @"\r";
}

- (void)showNothingFound
{
  _reload.keyEquivalent = @"";
  [_startScreen configureSymbol:@"checkmark.seal.fill"
                       subtitle:@"Everything is clean"
                    buttonTitle:@"Scan Again"
                      tintColor:NSColor.controlAccentColor
                  defaultButton:YES
                   appearBounce:YES];
  _startScreen.hidden = NO;
  _content.hidden     = YES;
}

- (void)reloadApps
{
  _status.stringValue               = @"Listing applications…";
  _reload.enabled                   = NO;
  _startScreen.actionButton.enabled = NO;
  if (_startScreen && !_startScreen.hidden)
  {
    [_startScreen beginProgress];
  }
  [_reload beginGlow];
  DCGlowButtonSetActive(_startScreen.actionButton, YES);
  _remove.hidden                     = YES;
  __weak DCUninstallerView* weakSelf = self;
  __block std::vector<dcmm::InstalledApp> apps;
  DCRunBackground(
      &_job,
      ^{
        DCUninstallerView* strong = weakSelf;
        if (!strong)
        {
          return;
        }
        apps = strong->_engine.list_apps();
      },
      ^{
        DCUninstallerView* s = weakSelf;
        if (!s)
        {
          return;
        }
        s->_apps.clear();
        s->_apps.reserve(apps.size());
        for (auto& a : apps)
        {
          s->_apps.push_back({std::move(a), false});
        }
        [s->_reload endGlow];
        DCGlowButtonSetActive(s->_startScreen.actionButton, NO);
        [s->_startScreen endProgress];
        s->_reload.enabled                   = YES;
        s->_startScreen.actionButton.enabled = YES;
        if (s->_apps.empty())
        {
          [s showNothingFound];
          return;
        }
        [s rebuildGrid];
        s->_status.stringValue =
            [NSString stringWithFormat:@"%lu apps", (unsigned long)s->_apps.size()];
        [s refreshUninstall];
        [s showContent];
      });
}

- (std::vector<dcmm::InstalledApp>)checkedApps
{
  std::vector<dcmm::InstalledApp> out;
  for (auto& row : _apps)
  {
    if (row.selected)
    {
      out.push_back(row.app);
    }
  }
  return out;
}

- (BOOL)allAppsSelected
{
  if (_apps.empty())
  {
    return NO;
  }
  for (const auto& row : _apps)
  {
    if (!row.selected)
    {
      return NO;
    }
  }
  return YES;
}

- (void)refreshUninstall
{
  std::size_t n = 0;
  for (const auto& row : _apps)
  {
    if (row.selected)
    {
      ++n;
    }
  }
  _remove.hidden = n == 0;
  if (n > 1)
  {
    _remove.title = [NSString stringWithFormat:@"Uninstall %lu Apps", (unsigned long)n];
  }
  else
  {
    _remove.title = @"Uninstall";
  }
  _selAll.title   = [self allAppsSelected] ? @"Unselect All" : @"Select All";
  _selAll.enabled = !_apps.empty();
}

- (void)toggleAll
{
  BOOL on = ![self allAppsSelected];
  for (auto& row : _apps)
  {
    row.selected = on;
  }
  [self rebuildGrid];
  [self refreshUninstall];
}

- (void)layout
{
  [super layout];
  CGFloat w = NSWidth(_scroll.contentView.bounds);
  if (w < 1)
  {
    return;
  }
  _doc.frame = NSMakeRect(0, 0, w, MAX(_grid.fittingSize.height, 1));
}

- (void)rebuildGrid
{
  NSArray<NSView*>* old = [_grid.arrangedSubviews copy];
  for (NSView* v in old)
  {
    [_grid removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  const NSInteger n                  = (NSInteger)_apps.size();
  const NSInteger cols               = 3;
  __weak DCUninstallerView* weakSelf = self;
  for (NSInteger i = 0; i < n; i += cols)
  {
    NSStackView* row = [NSStackView stackViewWithViews:@[]];
    row.orientation  = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment    = NSLayoutAttributeTop;
    row.distribution = NSStackViewDistributionFillEqually;
    row.spacing      = 12;
    for (NSInteger c = 0; c < cols; ++c)
    {
      NSInteger idx = i + c;
      if (idx >= n)
      {
        [row addArrangedSubview:[[NSView alloc] initWithFrame:NSZeroRect]];
        continue;
      }
      auto& a = _apps[(size_t)idx];
      DCUninstallAppCard* card =
          [[DCUninstallAppCard alloc] initWithName:DCNS(a.app.name)
                                              path:DCNS(a.app.appPath)
                                             bytes:a.app.appBytes
                                          selected:a.selected
                                             index:idx];
      card.onToggle = ^(NSInteger index) {
        DCUninstallerView* s = weakSelf;
        if (!s || index < 0 || index >= (NSInteger)s->_apps.size())
        {
          return;
        }
        s->_apps[(size_t)index].selected = !s->_apps[(size_t)index].selected;
        [s rebuildGrid];
        [s refreshUninstall];
      };
      [row addArrangedSubview:card];
    }
    [_grid addArrangedSubview:row];
    [row.widthAnchor constraintEqualToAnchor:_grid.widthAnchor].active = YES;
  }
  [self setNeedsLayout:YES];
}

- (void)uninstall
{
  auto apps = [self checkedApps];
  if (apps.empty())
  {
    DCInformNothingToClean(@"Check one or more applications in the list first.");
    return;
  }
  NSMutableArray<NSString*>* names = [NSMutableArray array];
  uint64_t bytes                   = ui::uninstallBytes(apps);
  for (const auto& a : apps)
  {
    [names addObject:DCNS(a.appPath)];
  }
  if (!DCConfirmClean(names, bytes))
  {
    return;
  }
  const auto mode                                  = DCCleanPref();
  _reload.enabled                                  = NO;
  _remove.hidden                                   = YES;
  __weak DCUninstallerView* weakSelf               = self;
  __block std::vector<dcmm::InstalledApp> workApps = std::move(apps);
  __block dcmm::CleanResult r;
  DCRunBackground(
      &_job,
      ^{
        DCUninstallerView* strong = weakSelf;
        if (!strong)
        {
          return;
        }
        for (auto& app : workApps)
        {
          strong->_engine.attach_left_overs(app);
        }
        auto paths = ui::uninstallPaths(workApps);
        r          = ui::applyClean(strong->_engine, paths, mode);
      },
      ^{
        DCUninstallerView* s = weakSelf;
        if (!s)
        {
          return;
        }
        s->_reload.enabled = YES;
        if (r.trashedItems == 0)
        {
          DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
        }
        else
        {
          NSString* msg          = DCNS(ui::cleanFinishedDetail(mode, r));
          s->_status.stringValue = msg;
          DCInformCleaned(@"Uninstall finished", msg);
        }
        [s reloadApps];
      });
}

@end

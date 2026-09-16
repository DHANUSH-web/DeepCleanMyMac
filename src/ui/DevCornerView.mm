#import "ui/DevCornerView.h"
#import "ui/Theme.h"

#import <objc/runtime.h>

#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"

#include <vector>

static char kDCDevUninstallRowKey;
static char kDCDevCheckRowKey;

typedef NS_ENUM(NSInteger, DCDevKind) { DCDevKindApp, DCDevKindFolder, DCDevKindExtension };

@interface DCDevRow : NSObject
@property(nonatomic) DCDevKind kind;
@property(nonatomic, copy) NSString* title;
@property(nonatomic, copy) NSString* path;
@property(nonatomic, copy) NSString* appPath;
@property(nonatomic, copy) NSString* iconPath;
@property(nonatomic) uint64_t bytes;
@property(nonatomic) dcmm::VsCodeEdition edition;
@property(nonatomic) BOOL selected;
@property(nonatomic) BOOL loaded;
@property(nonatomic) BOOL loading;
@property(nonatomic, strong) NSMutableArray<DCDevRow*>* children;
@property(nonatomic, weak) DCDevRow* parent;
@end

@implementation DCDevRow
- (instancetype)init {
  self = [super init];
  if (self) _children = [NSMutableArray array];
  return self;
}
@end

@interface DCDevCornerView () <NSOutlineViewDataSource, NSOutlineViewDelegate>
@end

@implementation DCDevCornerView {
  dcmm::Engine _engine;
  NSMutableArray<DCDevRow*>* _roots;
  NSOutlineView* _outline;
  DCGlowButton* _clean;
  DCGlowButton* _scanApps;
  BOOL _scanning;
  NSStackView* _actions;
  NSSegmentedControl* _tabs;
  NSView* _tableWrap;
  NSView* _placeholder;
  uint64_t _job;
  uint64_t _extJob;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _roots = [NSMutableArray array];
    NSStackView* page = DCPageStack(self);
    _scanApps = [DCGlowButton buttonWithTitle:@"Scan Applications"
                                       target:self
                                       action:@selector(reload)
                                    glowColor:NSColor.controlAccentColor
                                glowLineWidth:2.5
                                   clockwise:YES];
    _clean = [DCGlowButton buttonWithTitle:DCNS(ui::cleanButtonTitle(DCCleanPref()))
                                    target:self
                                    action:@selector(cleanSelected)
                                 glowColor:NSColor.systemRedColor
                             glowLineWidth:2.5
                                clockwise:YES];
    _clean.buttonColor = NSColor.systemRedColor;
    _clean.titleColor = NSColor.whiteColor;
    _clean.hasDestructiveAction = YES;
    _clean.hidden = YES;
    _actions = DCTrailingButtons(@[ _scanApps, _clean ]);

    _outline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_outline);
    _outline.dataSource = self;
    _outline.delegate = self;
    _outline.indentationPerLevel = 16;
    _outline.autoresizesOutlineColumn = NO;
    _outline.columnAutoresizingStyle = NSTableViewNoColumnAutoresizing;
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 24;
    c0.minWidth = 24;
    c0.maxWidth = 32;
    c0.title = @"";
    [_outline addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"Item";
    c1.width = 360;
    c1.minWidth = 220;
    [_outline addTableColumn:c1];
    _outline.outlineTableColumn = c1;
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 90;
    c2.minWidth = 80;
    c2.maxWidth = 110;
    [_outline addTableColumn:c2];
    NSTableColumn* c3 = [[NSTableColumn alloc] initWithIdentifier:@"action"];
    c3.title = @"";
    c3.width = 88;
    c3.minWidth = 88;
    c3.maxWidth = 96;
    [_outline addTableColumn:c3];
    _tableWrap = DCWrapTable(_outline);
    NSTextField* soon = DCSecondaryLabel(@"Under development");
    soon.alignment = NSTextAlignmentCenter;
    soon.translatesAutoresizingMaskIntoConstraints = NO;
    _placeholder = [[NSView alloc] initWithFrame:NSZeroRect];
    [_placeholder addSubview:soon];
    [NSLayoutConstraint activateConstraints:@[
      [soon.centerXAnchor constraintEqualToAnchor:_placeholder.centerXAnchor],
      [soon.centerYAnchor constraintEqualToAnchor:_placeholder.centerYAnchor],
    ]];
    _placeholder.hidden = YES;
    NSView* body = [[NSView alloc] initWithFrame:NSZeroRect];
    _tableWrap.translatesAutoresizingMaskIntoConstraints = NO;
    _placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [body addSubview:_tableWrap];
    [body addSubview:_placeholder];
    DCPinEdges(_tableWrap, body);
    DCPinEdges(_placeholder, body);

    _tabs = [NSSegmentedControl segmentedControlWithLabels:@[ @"Applications", @"Toolchains", @"Others" ]
                                              trackingMode:NSSegmentSwitchTrackingSelectOne
                                                    target:self
                                                    action:@selector(tabChanged:)];
    _tabs.segmentStyle = NSSegmentStyleRounded;
    _tabs.selectedSegment = 0;
    DCStackCentered(page, _tabs);
    DCStackExpand(page, body);
    [page addArrangedSubview:_actions];
    DCStackFullWidth(page, _actions);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshClean)
                                                 name:DCSettingsDidChangeNotification
                                               object:nil];
    [self reload];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)applicationTabSelected {
  return _tabs.selectedSegment == 0;
}

- (void)tabChanged:(NSSegmentedControl*)sender {
  const BOOL apps = sender.selectedSegment == 0;
  _tableWrap.hidden = !apps;
  _placeholder.hidden = apps;
  [self refreshClean];
}

- (void)reload {
  if (_scanning) return;
  _scanning = YES;
  [_scanApps beginGlow];
  __weak DCDevCornerView* weakSelf = self;
  __block std::vector<dcmm::VsCodeInstall> installs;
  DCRunBackground(&_job, ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    installs = strong->_engine.listVsCode();
  }, ^{
    DCDevCornerView* s = weakSelf;
    if (!s) return;
    [s->_roots removeAllObjects];
    for (auto& inst : installs) {
      DCDevRow* app = [[DCDevRow alloc] init];
      app.kind = DCDevKindApp;
      app.title = DCNS(inst.displayName);
      app.appPath = DCNS(inst.appPath);
      app.bytes = inst.bytes;
      app.edition = inst.edition;
      for (auto& it : inst.items) {
        DCDevRow* child = [[DCDevRow alloc] init];
        child.kind = DCDevKindFolder;
        child.title = DCNS(it.label);
        child.path = DCNS(it.path);
        child.bytes = it.bytes;
        child.edition = inst.edition;
        child.loaded = !it.extensions;
        child.parent = app;
        [app.children addObject:child];
      }
      [s->_roots addObject:app];
    }
    [s->_outline reloadData];
    for (DCDevRow* app in s->_roots) [s->_outline expandItem:app];
    [s->_scanApps endGlow];
    s->_scanApps.enabled = YES;
    s->_scanning = NO;
    [s refreshClean];
  });
}

- (void)loadExtensions:(DCDevRow*)row {
  if (row.kind != DCDevKindFolder || row.loaded || row.loading) return;
  if (![row.title isEqualToString:@"Extensions"]) return;
  row.loading = YES;
  dcmm::VsCodeEdition edition = row.edition;
  __weak DCDevCornerView* weakSelf = self;
  __weak DCDevRow* weakRow = row;
  __block std::vector<dcmm::VsCodeExtension> exts;
  DCRunBackground(&_extJob, ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    exts = strong->_engine.listVsCodeExtensions(edition);
  }, ^{
    DCDevCornerView* s = weakSelf;
    DCDevRow* parent = weakRow;
    if (!s || !parent) return;
    [parent.children removeAllObjects];
    for (auto& e : exts) {
      DCDevRow* child = [[DCDevRow alloc] init];
      child.kind = DCDevKindExtension;
      child.title = DCNS(e.name);
      child.path = DCNS(e.path);
      child.iconPath = DCNS(e.iconPath);
      child.bytes = e.bytes;
      child.parent = parent;
      [parent.children addObject:child];
    }
    parent.loaded = YES;
    parent.loading = NO;
    [s->_outline reloadItem:parent reloadChildren:YES];
    [s refreshClean];
  });
}

- (void)refreshClean {
  std::vector<std::string> paths;
  [self collectSelected:_roots into:paths];
  uint64_t bytes = 0;
  [self sumSelected:_roots bytes:&bytes];
  _clean.title = DCNS(ui::cleanButtonTitleWithBytes(DCCleanPref(), bytes));
  _clean.hidden = paths.empty();
  _actions.hidden = ![self applicationTabSelected];
}

- (void)collectSelected:(NSArray<DCDevRow*>*)rows into:(std::vector<std::string>&)out {
  for (DCDevRow* r in rows) {
    if (r.kind != DCDevKindApp && r.selected && r.path.length)
      out.push_back(r.path.UTF8String);
    [self collectSelected:r.children into:out];
  }
}

- (void)cleanSelected {
  std::vector<std::string> paths;
  [self collectSelected:_roots into:paths];
  if (paths.empty()) {
    DCInformNothingToClean(@"Check the items you want to remove.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  uint64_t bytes = 0;
  for (const auto& p : paths) [list addObject:DCNS(p)];
  [self sumSelected:_roots bytes:&bytes];
  if (!DCConfirmSpaceLensClean(list, bytes)) return;
  const auto mode = DCCleanPref();
  [_clean beginGlow];
  __weak DCDevCornerView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    r = ui::applySpaceLensClean(strong->_engine, paths, mode);
  }, ^{
    DCDevCornerView* s = weakSelf;
    if (!s) return;
    [s->_clean endGlow];
    if (r.trashedItems == 0)
      DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    else
      DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
    [s reload];
  });
}

- (void)sumSelected:(NSArray<DCDevRow*>*)rows bytes:(uint64_t*)n {
  for (DCDevRow* r in rows) {
    if (r.selected && r.kind != DCDevKindApp) *n += r.bytes;
    [self sumSelected:r.children bytes:n];
  }
}

- (void)uninstall:(NSButton*)sender {
  DCDevRow* row = objc_getAssociatedObject(sender, &kDCDevUninstallRowKey);
  if (!row || row.kind != DCDevKindApp) return;
  std::vector<std::string> paths = dcmm::vsCodeNukePaths(row.edition);
  if (paths.empty()) {
    DCInformNothingToClean(@"Nothing to remove.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray array];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  if (!DCConfirmSpaceLensClean(list, row.bytes)) return;
  const auto mode = DCCleanPref();
  __weak DCDevCornerView* weakSelf = self;
  __block dcmm::CleanResult r;
  DCRunBackground(&_job, ^{
    DCDevCornerView* strong = weakSelf;
    if (!strong) return;
    r = ui::applySpaceLensClean(strong->_engine, paths, mode);
  }, ^{
    DCDevCornerView* s = weakSelf;
    if (!s) return;
    if (r.trashedItems == 0)
      DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    else
      DCInformCleaned(@"Uninstalled", DCNS(ui::cleanFinishedDetail(mode, r)));
    [s reload];
  });
}

- (void)outlineViewItemWillExpand:(NSNotification*)notification {
  DCDevRow* row = notification.userInfo[@"NSObject"];
  if ([row isKindOfClass:[DCDevRow class]]) [self loadExtensions:row];
}

- (NSInteger)outlineView:(NSOutlineView*)ov numberOfChildrenOfItem:(id)item {
  if (!item) return (NSInteger)_roots.count;
  return (NSInteger)((DCDevRow*)item).children.count;
}

- (id)outlineView:(NSOutlineView*)ov child:(NSInteger)idx ofItem:(id)item {
  NSArray<DCDevRow*>* list = item ? ((DCDevRow*)item).children : _roots;
  if (idx < 0 || idx >= (NSInteger)list.count) return nil;
  return list[(NSUInteger)idx];
}

- (BOOL)outlineView:(NSOutlineView*)ov isItemExpandable:(id)item {
  DCDevRow* row = item;
  if (row.kind == DCDevKindExtension) return NO;
  if ([row.title isEqualToString:@"Extensions"]) return YES;
  return row.children.count > 0;
}

- (NSView*)outlineView:(NSOutlineView*)ov viewForTableColumn:(NSTableColumn*)col item:(id)item {
  DCDevRow* row = item;
  if ([col.identifier isEqualToString:@"check"]) {
    if (row.kind == DCDevKindApp) return DCCenteredTextCell(DCLabel(@""));
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.state = row.selected ? NSControlStateValueOn : NSControlStateValueOff;
    objc_setAssociatedObject(b, &kDCDevCheckRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return DCCenteredCheckCell(b);
  }
  if ([col.identifier isEqualToString:@"action"]) {
    if (row.kind != DCDevKindApp) return DCCenteredTextCell(DCLabel(@""));
    NSButton* u = DCDestructiveButton(@"Uninstall", self, @selector(uninstall:));
    objc_setAssociatedObject(u, &kDCDevUninstallRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return DCCenteredFillCell(u);
  }
  if ([col.identifier isEqualToString:@"size"]) {
    NSTextField* t = DCLabel(DCNS(dcmm::formatBytes(row.bytes)));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
    return DCCenteredTextCell(t);
  }
  NSTextField* t = DCLabel(row.title);
  t.lineBreakMode = NSLineBreakByTruncatingTail;
  t.usesSingleLineMode = YES;
  if (row.kind == DCDevKindApp && row.appPath.length) {
    NSImageView* icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    NSImage* img = [[[NSWorkspace sharedWorkspace] iconForFile:row.appPath] copy];
    img.size = NSMakeSize(28, 28);
    icon.image = img;
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    [icon.widthAnchor constraintEqualToConstant:28].active = YES;
    [icon.heightAnchor constraintEqualToConstant:28].active = YES;
    return DCCenteredIconTextCell(icon, t);
  }
  if (row.kind == DCDevKindExtension) {
    NSImageView* icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    NSImage* img = nil;
    if (row.iconPath.length) img = [[NSImage alloc] initWithContentsOfFile:row.iconPath];
    if (!img) {
      img = [[NSImage alloc] initWithSize:NSMakeSize(16, 16)];
      [img lockFocus];
      [@"📦" drawInRect:NSMakeRect(0, 0, 16, 16)
          withAttributes:@{NSFontAttributeName : [NSFont systemFontOfSize:13]}];
      [img unlockFocus];
    }
    img.size = NSMakeSize(16, 16);
    icon.image = img;
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    [icon.widthAnchor constraintEqualToConstant:16].active = YES;
    [icon.heightAnchor constraintEqualToConstant:16].active = YES;
    return DCCenteredIconTextCell(icon, t);
  }
  return DCCenteredTextCell(t);
}

- (void)layout {
  [super layout];
  NSTableColumn* name = [_outline tableColumnWithIdentifier:@"name"];
  NSTableColumn* size = [_outline tableColumnWithIdentifier:@"size"];
  NSTableColumn* action = [_outline tableColumnWithIdentifier:@"action"];
  NSTableColumn* check = [_outline tableColumnWithIdentifier:@"check"];
  if (!name || !size || !action || !check) return;
  const CGFloat used = check.width + size.width + action.width + 24;
  const CGFloat w = NSWidth(_outline.bounds) - used;
  if (w > name.minWidth) name.width = w;
}

- (CGFloat)outlineView:(NSOutlineView*)ov heightOfRowByItem:(id)item {
  DCDevRow* row = item;
  return row.kind == DCDevKindApp ? 36 : 28;
}

- (void)tog:(NSButton*)s {
  DCDevRow* item = objc_getAssociatedObject(s, &kDCDevCheckRowKey);
  if (!item) return;
  item.selected = s.state == NSControlStateValueOn;
  [self refreshClean];
}

@end

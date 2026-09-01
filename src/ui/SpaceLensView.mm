#import "ui/SpaceLensView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "SystemInfo.hpp"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCLensRow : NSObject
@property(nonatomic) dcmm::SpaceNode node;
@property(nonatomic) BOOL selected;
@property(nonatomic) BOOL loaded;
@property(nonatomic) BOOL loading;
@property(nonatomic, strong) NSMutableArray<DCLensRow*>* children;
@property(nonatomic, weak) DCLensRow* parent;
- (ui::GroupCheck)checkState;
- (void)setSelectedDeep:(BOOL)on;
- (void)collectSelected:(std::vector<std::pair<std::string, uint64_t>>&)out;
@end

@implementation DCLensRow
- (instancetype)initWithNode:(dcmm::SpaceNode)node {
  self = [super init];
  if (self) {
    _node = std::move(node);
    _children = [NSMutableArray array];
  }
  return self;
}

- (ui::GroupCheck)checkState {
  if (_selected) return ui::GroupCheck::On;
  BOOL any = NO;
  for (DCLensRow* c in _children) {
    auto st = [c checkState];
    if (st == ui::GroupCheck::On || st == ui::GroupCheck::Mixed) any = YES;
  }
  return any ? ui::GroupCheck::Mixed : ui::GroupCheck::Off;
}

- (void)setSelectedDeep:(BOOL)on {
  _selected = on;
  for (DCLensRow* c in _children) [c setSelectedDeep:on];
}

- (void)collectSelected:(std::vector<std::pair<std::string, uint64_t>>&)out {
  if (_selected) {
    if (!_node.path.empty()) out.push_back({_node.path, _node.bytes});
    return;
  }
  for (DCLensRow* c in _children) [c collectSelected:out];
}
@end

@interface DCSpaceLensView () <NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate>
@end

@implementation DCSpaceLensView {
  dcmm::Engine _engine;
  NSMutableArray<DCLensRow*>* _roots;
  uint64_t _volumeBytes;
  NSButton* _scan;
  NSButton* _selAll;
  NSButton* _clean;
  NSTextField* _status;
  NSOutlineView* _outline;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _volumeBytes = 0;
    _roots = [NSMutableArray array];
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Space Lens", [NSString stringWithUTF8String:ui::subtitle(ui::Module::SpaceLens)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _scan = DCDefaultButton(@"Analyze", self, @selector(startScan));
    _selAll = DCPushButton(@"Select All", self, @selector(toggleAll));
    _selAll.enabled = NO;
    _clean = DCDestructiveButton(@"Move to Trash", self, @selector(cleanSelected));
    _clean.hidden = YES;
    NSStackView* actions = DCTrailingButtons(@[ _selAll, _clean, _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    NSView* legend = [DCLegendView dangerLegendWithMessage:
                          @"Warning icon shows the folder might not be safe to delete. Please clean at your own risk"];
    [page addArrangedSubview:legend];
    DCStackFullWidth(page, legend);
    [page setCustomSpacing:20 afterView:actions];
    [page setCustomSpacing:20 afterView:legend];
    _status = DCCaptionLabel(@"Measures folders in your home directory.");
    [page addArrangedSubview:_status];

    _outline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_outline);
    _outline.dataSource = self;
    _outline.delegate = self;
    _outline.indentationPerLevel = 16;
    _outline.autoresizesOutlineColumn = YES;
    DCAttachTableMenu(_outline, self);
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 24;
    c0.minWidth = 24;
    c0.maxWidth = 32;
    c0.title = @"";
    [_outline addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"Folder";
    c1.width = 280;
    c1.minWidth = 160;
    [_outline addTableColumn:c1];
    _outline.outlineTableColumn = c1;
    _outline.autoresizesOutlineColumn = NO;
    _outline.columnAutoresizingStyle = NSTableViewNoColumnAutoresizing;
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 100;
    c2.minWidth = 80;
    [_outline addTableColumn:c2];
    NSTableColumn* c3 = [[NSTableColumn alloc] initWithIdentifier:@"share"];
    c3.title = @"Share";
    c3.width = 72;
    c3.minWidth = 56;
    [_outline addTableColumn:c3];
    NSScrollView* scroll = DCWrapTable(_outline);
    scroll.hasHorizontalScroller = YES;
    DCStackExpand(page, scroll);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshClean)
                                                 name:DCSettingsDidChangeNotification
                                               object:nil];
    [self refreshClean];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startScan {
  _status.stringValue = @"Measuring…";
  _scan.enabled = NO;
  __weak DCSpaceLensView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCSpaceLensView* strong = weakSelf;
    if (!strong) return;
    auto n = strong->_engine.spaceLens();
    uint64_t volume = ui::volumeInfo("/").totalBytes;
    if (volume == 0) volume = strong->_engine.disk("/").totalBytes;
    dispatch_async(dispatch_get_main_queue(), ^{
      DCSpaceLensView* s = weakSelf;
      if (!s) return;
      [s->_roots removeAllObjects];
      for (auto& node : n) {
        DCLensRow* row = [[DCLensRow alloc] initWithNode:std::move(node)];
        [s->_roots addObject:row];
      }
      s->_volumeBytes = volume;
      [s->_outline reloadData];
      [s fitOutlineColumns];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu folders", (unsigned long)s->_roots.count];
      [s refreshClean];
    });
  });
}

- (BOOL)allSelected {
  if (_roots.count == 0) return NO;
  for (DCLensRow* r in _roots)
    if ([r checkState] != ui::GroupCheck::On) return NO;
  return YES;
}

- (void)refreshClean {
  std::vector<std::pair<std::string, uint64_t>> picked;
  for (DCLensRow* r in _roots) [r collectSelected:picked];
  uint64_t b = 0;
  for (const auto& p : picked) b += p.second;
  _clean.hidden = picked.empty();
  _clean.title = DCNS(ui::cleanButtonTitleWithBytes(DCCleanPref(), picked.empty() ? 0 : b));
  _selAll.enabled = _roots.count > 0;
  _selAll.title = [self allSelected] ? @"Unselect All" : @"Select All";
}

- (void)toggleAll {
  BOOL on = ![self allSelected];
  for (DCLensRow* r in _roots) [r setSelectedDeep:on];
  [_outline reloadData];
  [self refreshClean];
}

- (std::vector<std::string>)selectedPaths {
  std::vector<std::pair<std::string, uint64_t>> picked;
  for (DCLensRow* r in _roots) [r collectSelected:picked];
  std::vector<std::string> paths;
  paths.reserve(picked.size());
  for (const auto& p : picked) paths.push_back(p.first);
  ui::pruneNestedSpaceLensPaths(paths);
  return paths;
}

- (uint64_t)selectedBytes {
  std::vector<std::pair<std::string, uint64_t>> picked;
  for (DCLensRow* r in _roots) [r collectSelected:picked];
  auto paths = [self selectedPaths];
  uint64_t b = 0;
  for (const auto& want : paths)
    for (const auto& p : picked)
      if (p.first == want) {
        b += p.second;
        break;
      }
  return b;
}

- (void)cleanSelected {
  auto paths = [self selectedPaths];
  if (paths.empty()) {
    DCInformNothingToClean(@"Check the folders you want to remove. Please clean at your own risk.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray arrayWithCapacity:paths.size()];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  uint64_t bytes = [self selectedBytes];
  if (!DCConfirmSpaceLensClean(list, bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applySpaceLensClean(_engine, paths, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
  } else {
    NSString* msg = DCNS(ui::cleanFinishedDetail(mode, r));
    _status.stringValue = msg;
    DCInformCleaned(@"Clean finished", msg);
  }
  [self startScan];
}

static NSColor* DCSpaceSizeBandFill(ui::SpaceSizeBand band) {
  if (band == ui::SpaceSizeBand::Normal) return NSColor.clearColor;
  NSColor* base =
      band == ui::SpaceSizeBand::TooBig ? NSColor.systemRedColor : NSColor.systemOrangeColor;
  return [NSColor colorWithName:nil
               dynamicProvider:^NSColor*(NSAppearance* appearance) {
                 NSAppearanceName match =
                     [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameDarkAqua ]];
                 const CGFloat alpha =
                     [match isEqualToString:NSAppearanceNameDarkAqua] ? 0.18 : 0.10;
                 return [base colorWithAlphaComponent:alpha];
               }];
}

- (void)fitOutlineColumns {
  NSInteger maxLevel = 0;
  const NSInteger rows = _outline.numberOfRows;
  for (NSInteger i = 0; i < rows; ++i) {
    const NSInteger level = [_outline levelForRow:i];
    if (level > maxLevel) maxLevel = level;
  }
  NSTableColumn* name = [_outline tableColumnWithIdentifier:@"name"];
  const CGFloat need = 160 + (maxLevel + 1) * _outline.indentationPerLevel + 96;
  if (name && need > name.width) name.width = need;
}

- (void)outlineViewItemDidExpand:(NSNotification*)notification {
  [self fitOutlineColumns];
}

- (void)outlineViewItemDidCollapse:(NSNotification*)notification {
  [self fitOutlineColumns];
}

- (void)loadChildren:(DCLensRow*)row {
  if (!row.node.isDir || row.loaded || row.loading) return;
  row.loading = YES;
  std::string path = row.node.path;
  __weak DCSpaceLensView* weakSelf = self;
  __weak DCLensRow* weakRow = row;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCSpaceLensView* strong = weakSelf;
    if (!strong) return;
    auto kids = strong->_engine.spaceLensChildren(path);
    dispatch_async(dispatch_get_main_queue(), ^{
      DCSpaceLensView* s = weakSelf;
      DCLensRow* parent = weakRow;
      if (!s || !parent) return;
      [parent.children removeAllObjects];
      for (auto& n : kids) {
        DCLensRow* child = [[DCLensRow alloc] initWithNode:std::move(n)];
        child.parent = parent;
        if (parent.selected) child.selected = YES;
        [parent.children addObject:child];
      }
      parent.loaded = YES;
      parent.loading = NO;
      [s->_outline reloadItem:parent reloadChildren:YES];
      [s fitOutlineColumns];
      [s refreshClean];
    });
  });
}

- (NSInteger)outlineView:(NSOutlineView*)ov numberOfChildrenOfItem:(id)item {
  if (!item) return (NSInteger)_roots.count;
  DCLensRow* row = item;
  if (row.node.isDir && !row.loaded) [self loadChildren:row];
  return (NSInteger)row.children.count;
}

- (id)outlineView:(NSOutlineView*)ov child:(NSInteger)idx ofItem:(id)item {
  NSArray<DCLensRow*>* list = item ? ((DCLensRow*)item).children : _roots;
  if (idx < 0 || idx >= (NSInteger)list.count) return nil;
  return list[(NSUInteger)idx];
}

- (BOOL)outlineView:(NSOutlineView*)ov isItemExpandable:(id)item {
  DCLensRow* row = item;
  return row.node.isDir;
}

- (void)outlineView:(NSOutlineView*)ov didAddRowView:(NSTableRowView*)rowView forRow:(NSInteger)row {
  DCLensRow* item = [ov itemAtRow:row];
  ui::SpaceSizeBand band = item ? ui::spaceSizeBand(item.node.bytes) : ui::SpaceSizeBand::Normal;
  rowView.backgroundColor = DCSpaceSizeBandFill(band);
}

- (NSView*)outlineView:(NSOutlineView*)ov viewForTableColumn:(NSTableColumn*)col item:(id)item {
  DCLensRow* row = item;
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.allowsMixedState = YES;
    switch ([row checkState]) {
      case ui::GroupCheck::On:
        b.state = NSControlStateValueOn;
        break;
      case ui::GroupCheck::Mixed:
        b.state = NSControlStateValueMixed;
        break;
      case ui::GroupCheck::Off:
        b.state = NSControlStateValueOff;
        break;
    }
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) {
    t.stringValue = DCNS(row.node.name);
    t.toolTip = DCNS(row.node.path);
    if (ui::spaceLensDanger(row.node.path)) return DCCenteredDangerTextCell(t);
  } else if ([col.identifier isEqualToString:@"share"]) {
    t.stringValue = DCNS(ui::spaceSharePercent(row.node.bytes, _volumeBytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
    t.textColor = [NSColor secondaryLabelColor];
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(row.node.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

- (void)tog:(NSButton*)s {
  NSInteger row = [_outline rowForView:s];
  if (row < 0) return;
  DCLensRow* item = [_outline itemAtRow:row];
  if (!item) return;
  BOOL on = [item checkState] != ui::GroupCheck::On;
  [item setSelectedDeep:on];
  if (!on) {
    DCLensRow* p = item.parent;
    while (p) {
      p.selected = NO;
      p = p.parent;
    }
  } else if (item.parent) {
    BOOL all = YES;
    for (DCLensRow* c in item.parent.children)
      if ([c checkState] != ui::GroupCheck::On) all = NO;
    if (all) item.parent.selected = YES;
  }
  [_outline reloadData];
  [self refreshClean];
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSInteger row = _outline.clickedRow;
  if (row < 0) return;
  DCLensRow* item = [_outline itemAtRow:row];
  if (!item) return;
  DCAddPathMenuItems(menu, DCNS(item.node.path));
  [menu addItem:[NSMenuItem separatorItem]];
  const bool on = [item checkState] == ui::GroupCheck::On;
  NSMenuItem* sel = [[NSMenuItem alloc] initWithTitle:on ? @"Unselect" : @"Select"
                                               action:@selector(ctxToggleSelect:)
                                        keyEquivalent:@""];
  sel.target = self;
  sel.tag = row;
  [menu addItem:sel];
  NSMenuItem* trash = [[NSMenuItem alloc] initWithTitle:DCNS(ui::cleanMenuTitle(DCCleanPref()))
                                                 action:@selector(ctxTrashRow:)
                                          keyEquivalent:@""];
  trash.target = self;
  trash.tag = row;
  [menu addItem:trash];
}

- (void)ctxToggleSelect:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0) return;
  DCLensRow* item = [_outline itemAtRow:row];
  if (!item) return;
  NSButton* fake = [NSButton checkboxWithTitle:@"" target:nil action:nil];
  fake.tag = row;
  [self tog:fake];
}

- (void)ctxTrashRow:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0) return;
  DCLensRow* item = [_outline itemAtRow:row];
  if (!item) return;
  if (!DCConfirmSpaceLensClean(@[ DCNS(item.node.path) ], item.node.bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applySpaceLensClean(_engine, {item.node.path}, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    return;
  }
  DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
  [self startScan];
}

@end

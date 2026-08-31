#import "ui/SpaceLensView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCSpaceLensView () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

@implementation DCSpaceLensView {
  dcmm::Engine _engine;
  std::vector<dcmm::SpaceNode> _nodes;
  std::vector<char> _selected;
  uint64_t _total;
  NSButton* _scan;
  NSButton* _selAll;
  NSButton* _clean;
  NSTextField* _status;
  NSTableView* _table;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _total = 0;
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Space Lens", [NSString stringWithUTF8String:ui::subtitle(ui::Module::SpaceLens)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    NSImageView* legendIcon = DCDangerIcon(12);
    [legendIcon setContentHuggingPriority:NSLayoutPriorityRequired
                           forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSTextField* legendText = DCCaptionLabel(
        @"Warning icon shows the folder might not be safe to delete. Please clean at your own risk");
    [legendText setContentHuggingPriority:NSLayoutPriorityDefaultLow
                           forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* legend = [NSStackView stackViewWithViews:@[ legendIcon, legendText ]];
    legend.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    legend.alignment = NSLayoutAttributeCenterY;
    legend.spacing = 6;
    [legend setContentHuggingPriority:NSLayoutPriorityRequired
                       forOrientation:NSLayoutConstraintOrientationVertical];
    [page addArrangedSubview:legend];
    DCStackFullWidth(page, legend);
    _scan = DCDefaultButton(@"Analyze", self, @selector(startScan));
    _selAll = DCPushButton(@"Select All", self, @selector(toggleAll));
    _selAll.enabled = NO;
    _clean = DCDestructiveButton(@"Move to Trash", self, @selector(cleanSelected));
    _clean.enabled = NO;
    NSStackView* actions = DCTrailingButtons(@[ _selAll, _clean, _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(@"Measures folders in your home directory.");
    [page addArrangedSubview:_status];

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_table);
    _table.dataSource = self;
    _table.delegate = self;
    DCAttachTableMenu(_table, self);
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 24;
    c0.minWidth = 24;
    c0.maxWidth = 32;
    c0.title = @"";
    [_table addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"Folder";
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 100;
    [_table addTableColumn:c2];
    NSTableColumn* c3 = [[NSTableColumn alloc] initWithIdentifier:@"share"];
    c3.title = @"Share";
    c3.width = 72;
    [_table addTableColumn:c3];
    DCStackExpand(page, DCWrapTable(_table));
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
    dispatch_async(dispatch_get_main_queue(), ^{
      DCSpaceLensView* s = weakSelf;
      if (!s) return;
      s->_nodes = std::move(n);
      s->_selected.assign(s->_nodes.size(), 0);
      s->_total = 0;
      for (const auto& x : s->_nodes) s->_total += x.bytes;
      [s->_table reloadData];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu folders", (unsigned long)s->_nodes.size()];
      [s refreshClean];
    });
  });
}

- (BOOL)allSelected {
  if (_nodes.empty()) return NO;
  for (std::size_t i = 0; i < _nodes.size(); ++i) {
    if (i >= _selected.size() || !_selected[i]) return NO;
  }
  return YES;
}

- (void)refreshClean {
  auto paths = ui::selectedSpaceLensPaths(_nodes, _selected);
  uint64_t b = ui::selectedSpaceLensBytes(_nodes, _selected);
  _clean.enabled = !paths.empty();
  _clean.title = DCNS(ui::cleanButtonTitleWithBytes(DCCleanPref(), paths.empty() ? 0 : b));
  _selAll.enabled = !_nodes.empty();
  _selAll.title = [self allSelected] ? @"Unselect All" : @"Select All";
}

- (void)toggleAll {
  BOOL on = ![self allSelected];
  if (_selected.size() != _nodes.size()) _selected.assign(_nodes.size(), 0);
  for (std::size_t i = 0; i < _nodes.size(); ++i) _selected[i] = on ? 1 : 0;
  [_table reloadData];
  [self refreshClean];
}

- (void)cleanSelected {
  auto paths = ui::selectedSpaceLensPaths(_nodes, _selected);
  if (paths.empty()) {
    DCInformNothingToClean(@"Check the folders you want to remove. Please clean at your own risk.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray arrayWithCapacity:paths.size()];
  for (const auto& p : paths) [list addObject:DCNS(p)];
  uint64_t bytes = ui::selectedSpaceLensBytes(_nodes, _selected);
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

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_nodes.size();
}

- (void)tableView:(NSTableView*)tv didAddRowView:(NSTableRowView*)rowView forRow:(NSInteger)row {
  ui::SpaceSizeBand band = ui::SpaceSizeBand::Normal;
  if (row >= 0 && row < (NSInteger)_nodes.size())
    band = ui::spaceSizeBand(_nodes[(size_t)row].bytes);
  rowView.backgroundColor = DCSpaceSizeBandFill(band);
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto& n = _nodes[(size_t)row];
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.enabled = YES;
    b.state = (row < (NSInteger)_selected.size() && _selected[(size_t)row])
                  ? NSControlStateValueOn
                  : NSControlStateValueOff;
    b.tag = row;
    return DCCenteredCheckCell(b);
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) {
    t.stringValue = DCNS(n.name);
    t.toolTip = DCNS(n.path);
    if (ui::spaceLensDanger(n.path)) return DCCenteredDangerTextCell(t);
  } else if ([col.identifier isEqualToString:@"share"]) {
    t.stringValue = DCNS(ui::spaceSharePercent(n.bytes, _total));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
    t.textColor = [NSColor secondaryLabelColor];
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(n.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return DCCenteredTextCell(t);
}

- (void)tog:(NSButton*)s {
  if (s.tag < 0 || s.tag >= (NSInteger)_nodes.size()) return;
  if (_selected.size() != _nodes.size()) _selected.assign(_nodes.size(), 0);
  _selected[(size_t)s.tag] = s.state == NSControlStateValueOn ? 1 : 0;
  [self refreshClean];
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSInteger row = _table.clickedRow;
  if (row < 0 || row >= (NSInteger)_nodes.size()) return;
  const auto& n = _nodes[(size_t)row];
  DCAddPathMenuItems(menu, DCNS(n.path));
  [menu addItem:[NSMenuItem separatorItem]];
  const bool on = row < (NSInteger)_selected.size() && _selected[(size_t)row];
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
  if (row < 0 || row >= (NSInteger)_nodes.size()) return;
  if (_selected.size() != _nodes.size()) _selected.assign(_nodes.size(), 0);
  _selected[(size_t)row] = _selected[(size_t)row] ? 0 : 1;
  [_table reloadData];
  [self refreshClean];
}

- (void)ctxTrashRow:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_nodes.size()) return;
  const auto& n = _nodes[(size_t)row];
  if (!DCConfirmSpaceLensClean(@[ DCNS(n.path) ], n.bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applySpaceLensClean(_engine, {n.path}, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    return;
  }
  DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
  [self startScan];
}

@end

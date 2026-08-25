#import "ui/SpaceLensView.h"
#import "ui/Theme.h"
#include "AppFeatures.hpp"
#include "AppSettings.hpp"
#include "dcmm/dcmm.hpp"
#include "dcmm/safety.hpp"
#include "Modules.h"
#include <vector>

@interface DCSpaceLensView () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

@implementation DCSpaceLensView {
  dcmm::Engine _engine;
  std::vector<dcmm::SpaceNode> _nodes;
  uint64_t _total;
  NSButton* _scan;
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
    _scan = DCDefaultButton(@"Analyze", self, @selector(startScan));
    NSStackView* actions = DCTrailingButtons(@[ _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(@"Measures folders in your home directory.");
    [page addArrangedSubview:_status];

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_table);
    _table.dataSource = self;
    _table.delegate = self;
    DCAttachTableMenu(_table, self);
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
  }
  return self;
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
      s->_total = 0;
      for (const auto& x : s->_nodes) s->_total += x.bytes;
      [s->_table reloadData];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu folders", (unsigned long)s->_nodes.size()];
    });
  });
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
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) {
    t.stringValue = DCNS(n.name);
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

- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSInteger row = _table.clickedRow;
  if (row < 0 || row >= (NSInteger)_nodes.size()) return;
  const auto& n = _nodes[(size_t)row];
  DCAddPathMenuItems(menu, DCNS(n.path));
  if (dcmm::isSafeToTrash(n.path)) {
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem* trash = [[NSMenuItem alloc] initWithTitle:DCNS(ui::cleanMenuTitle(DCCleanPref()))
                                                   action:@selector(ctxTrashRow:)
                                            keyEquivalent:@""];
    trash.target = self;
    trash.tag = row;
    [menu addItem:trash];
  }
}

- (void)ctxTrashRow:(NSMenuItem*)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)_nodes.size()) return;
  const auto& n = _nodes[(size_t)row];
  if (!DCConfirmClean(@[ DCNS(n.path) ], n.bytes)) return;
  const auto mode = DCCleanPref();
  auto r = ui::applyClean(_engine, {n.path}, mode);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(DCNS(ui::cleanNothingDetail(mode)));
    return;
  }
  DCInformCleaned(@"Clean finished", DCNS(ui::cleanFinishedDetail(mode, r)));
  [self startScan];
}

@end

#import "ui/UninstallerView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"
#include <vector>

@interface DCUninstallerView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation DCUninstallerView {
  dcmm::Engine _engine;
  std::vector<dcmm::InstalledApp> _apps;
  NSInteger _sel;
  NSTextField* _title;
  NSTextField* _status;
  DCButton* _reload;
  DCButton* _remove;
  NSTableView* _appsTable;
  NSTableView* _leftTable;
  NSScrollView* _appsScroll;
  NSScrollView* _leftScroll;
}
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _sel = -1;
    _title = DCLabel(@"Uninstaller", th::title(), th::text());
    [self addSubview:_title];
    _status = DCLabel(@"Third-party apps. Related files are listed when you select one.", th::body(),
                      th::muted());
    [self addSubview:_status];
    _reload = [[DCButton alloc] initWithFrame:NSZeroRect];
    _reload.title = @"Refresh";
    _reload.primary = NO;
    _reload.target = self;
    _reload.action = @selector(reloadApps);
    [self addSubview:_reload];
    _remove = [[DCButton alloc] initWithFrame:NSZeroRect];
    _remove.title = @"Uninstall selected";
    _remove.destructive = YES;
    _remove.target = self;
    _remove.action = @selector(uninstall);
    _remove.enabled = NO;
    [self addSubview:_remove];

    _appsTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _appsTable.backgroundColor = th::card();
    _appsTable.dataSource = self;
    _appsTable.delegate = self;
    NSTableColumn* n = [[NSTableColumn alloc] initWithIdentifier:@"app"];
    n.title = @"Application";
    n.width = 280;
    [_appsTable addTableColumn:n];
    NSTableColumn* s = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    s.title = @"Size";
    s.width = 80;
    [_appsTable addTableColumn:s];
    _appsScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _appsScroll.documentView = _appsTable;
    _appsScroll.hasVerticalScroller = YES;
    _appsScroll.backgroundColor = th::card();
    _appsScroll.wantsLayer = YES;
    _appsScroll.layer.cornerRadius = 12;
    [self addSubview:_appsScroll];

    _leftTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _leftTable.backgroundColor = th::card();
    _leftTable.dataSource = self;
    _leftTable.delegate = self;
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 36;
    c0.title = @"";
    [_leftTable addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"leftover"];
    c1.title = @"Related files";
    c1.width = 360;
    [_leftTable addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"lsize"];
    c2.title = @"Size";
    c2.width = 80;
    [_leftTable addTableColumn:c2];
    _leftScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _leftScroll.documentView = _leftTable;
    _leftScroll.hasVerticalScroller = YES;
    _leftScroll.backgroundColor = th::card();
    _leftScroll.wantsLayer = YES;
    _leftScroll.layer.cornerRadius = 12;
    [self addSubview:_leftScroll];
  }
  return self;
}
- (BOOL)isFlipped { return YES; }
- (void)reloadApps {
  _status.stringValue = @"Listing applications…";
  __weak DCUninstallerView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCUninstallerView* strong = weakSelf;
    if (!strong) return;
    auto apps = strong->_engine.listApps();
    dispatch_async(dispatch_get_main_queue(), ^{
      DCUninstallerView* s = weakSelf;
      if (!s) return;
      s->_apps = std::move(apps);
      s->_sel = -1;
      [s->_appsTable reloadData];
      [s->_leftTable reloadData];
      s->_status.stringValue = [NSString stringWithFormat:@"%lu apps", (unsigned long)s->_apps.size()];
    });
  });
}
- (void)tableViewSelectionDidChange:(NSNotification*)n {
  if (n.object != _appsTable) return;
  _sel = _appsTable.selectedRow;
  if (_sel >= 0 && _sel < (NSInteger)_apps.size()) {
    _engine.attachLeftovers(_apps[(size_t)_sel]);
    _remove.enabled = YES;
  } else {
    _remove.enabled = NO;
  }
  [_leftTable reloadData];
}
- (void)uninstall {
  if (_sel < 0 || _sel >= (NSInteger)_apps.size()) return;
  auto& app = _apps[(size_t)_sel];
  std::vector<std::string> paths;
  for (auto& it : app.leftovers)
    if (it.selected) paths.push_back(it.path);
  NSAlert* a = [[NSAlert alloc] init];
  a.messageText = [NSString stringWithFormat:@"Uninstall %@?", DCNS(app.name)];
  a.informativeText = @"Selected related files will be moved to Trash.";
  [a addButtonWithTitle:@"Move to Trash"];
  [a addButtonWithTitle:@"Cancel"];
  if ([a runModal] != NSAlertFirstButtonReturn) return;
  auto r = _engine.trashPaths(paths);
  _status.stringValue = [NSString stringWithFormat:@"Moved %llu items.", (unsigned long long)r.trashedItems];
  [self reloadApps];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  if (tv == _appsTable) return (NSInteger)_apps.size();
  if (_sel < 0 || _sel >= (NSInteger)_apps.size()) return 0;
  return (NSInteger)_apps[(size_t)_sel].leftovers.size();
}
- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  if (tv == _appsTable) {
    auto& a = _apps[(size_t)row];
    NSTextField* t = DCLabel(@"", th::body(), th::text());
    if ([col.identifier isEqualToString:@"app"]) t.stringValue = DCNS(a.name);
    else {
      t.stringValue = DCNS(dcmm::formatBytes(a.appBytes));
      t.font = th::mono();
    }
    return t;
  }
  auto& it = _apps[(size_t)_sel].leftovers[(size_t)row];
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.state = it.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return b;
  }
  NSTextField* t = DCLabel(@"", th::body(), th::text());
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"leftover"]) {
    t.stringValue = DCNS(it.path);
    t.toolTip = t.stringValue;
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(it.bytes));
    t.font = th::mono();
  }
  return t;
}
- (void)tog:(NSButton*)s {
  if (_sel < 0) return;
  auto& it = _apps[(size_t)_sel].leftovers[(size_t)s.tag];
  it.selected = s.state == NSControlStateValueOn;
}
- (void)layout {
  [super layout];
  NSRect b = self.bounds;
  _title.frame = NSMakeRect(8, 8, 400, 34);
  _status.frame = NSMakeRect(8, 44, b.size.width - 360, 20);
  _reload.frame = NSMakeRect(b.size.width - 280, 10, 110, 36);
  _remove.frame = NSMakeRect(b.size.width - 160, 10, 148, 36);
  CGFloat y = 76, h = b.size.height - 84, leftW = b.size.width * 0.42;
  _appsScroll.frame = NSMakeRect(8, y, leftW, h);
  _leftScroll.frame = NSMakeRect(leftW + 20, y, b.size.width - leftW - 28, h);
}
@end

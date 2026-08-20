#import "ui/LargeFilesView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"
#include "Modules.h"
#include <vector>

@interface DCLargeFilesView () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation DCLargeFilesView {
  dcmm::Engine _engine;
  std::vector<dcmm::LargeFile> _files;
  NSButton* _scan;
  NSButton* _clean;
  NSTextField* _status;
  NSTableView* _table;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Large Files", [NSString stringWithUTF8String:ui::subtitle(ui::Module::LargeFiles)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);
    _scan = DCDefaultButton(@"Scan", self, @selector(startScan));
    _clean = DCDestructiveButton(@"Move to Trash", self, @selector(cleanSelected));
    _clean.enabled = NO;
    NSStackView* actions = DCTrailingButtons(@[ _clean, _scan ]);
    [page addArrangedSubview:actions];
    DCStackFullWidth(page, actions);
    _status = DCCaptionLabel(@"Looks in Desktop, Documents, Downloads, and Movies for files of 50 MB or more.");
    [page addArrangedSubview:_status];

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    DCStyleTable(_table);
    _table.dataSource = self;
    _table.delegate = self;
    NSTableColumn* c0 = [[NSTableColumn alloc] initWithIdentifier:@"check"];
    c0.width = 24;
    c0.minWidth = 24;
    c0.maxWidth = 32;
    c0.title = @"";
    [_table addTableColumn:c0];
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    c1.title = @"File";
    [_table addTableColumn:c1];
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    c2.title = @"Size";
    c2.width = 100;
    [_table addTableColumn:c2];
    DCStackExpand(page, DCWrapTable(_table));
  }
  return self;
}

- (void)startScan {
  _status.stringValue = @"Scanning…";
  _scan.enabled = NO;
  __weak DCLargeFilesView* weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DCLargeFilesView* strong = weakSelf;
    if (!strong) return;
    dcmm::LargeFileOptions opt;
    auto home = dcmm::homeDirectory();
    opt.roots = {dcmm::joinPath(home, "Desktop"), dcmm::joinPath(home, "Documents"),
                 dcmm::joinPath(home, "Downloads"), dcmm::joinPath(home, "Movies")};
    auto files = strong->_engine.findLargeFiles(opt);
    dispatch_async(dispatch_get_main_queue(), ^{
      DCLargeFilesView* s = weakSelf;
      if (!s) return;
      s->_files = std::move(files);
      [s->_table reloadData];
      s->_scan.enabled = YES;
      s->_status.stringValue =
          [NSString stringWithFormat:@"%lu files of 50 MB or more", (unsigned long)s->_files.size()];
      [s refreshClean];
    });
  });
}

- (void)refreshClean {
  uint64_t n = 0, b = 0;
  for (auto& f : _files)
    if (f.selected) {
      n++;
      b += f.bytes;
    }
  _clean.enabled = n > 0;
  _clean.title = n ? [NSString stringWithFormat:@"Move %@ to Trash", DCNS(dcmm::formatBytes(b))]
                   : @"Move to Trash";
}

- (void)cleanSelected {
  std::vector<std::string> paths;
  for (auto& f : _files)
    if (f.selected) paths.push_back(f.path);
  if (paths.empty()) {
    DCInformNothingToClean(@"Select files in the list first. Nothing was deleted.");
    return;
  }
  NSMutableArray<NSString*>* list = [NSMutableArray arrayWithCapacity:paths.size()];
  uint64_t bytes = 0;
  for (auto& f : _files)
    if (f.selected) {
      [list addObject:DCNS(f.path)];
      bytes += f.bytes;
    }
  if (!DCConfirmMoveToTrash(list, bytes)) return;
  auto r = _engine.trashPaths(paths);
  if (r.trashedItems == 0) {
    DCInformNothingToClean(@"No items were moved. Protected paths are skipped.");
  } else {
    NSString* msg = [NSString stringWithFormat:@"Freed %@ by moving %llu item%s to Trash.",
                                               DCNS(dcmm::formatBytes(r.trashedBytes)),
                                               (unsigned long long)r.trashedItems,
                                               r.trashedItems == 1 ? "" : "s"];
    _status.stringValue = msg;
    DCInformCleaned(@"Clean finished", msg);
  }
  [self startScan];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  return (NSInteger)_files.size();
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row {
  auto& f = _files[(size_t)row];
  if ([col.identifier isEqualToString:@"check"]) {
    NSButton* b = [NSButton checkboxWithTitle:@"" target:self action:@selector(tog:)];
    b.state = f.selected ? NSControlStateValueOn : NSControlStateValueOff;
    b.tag = row;
    return b;
  }
  NSTextField* t = DCLabel(@"");
  t.lineBreakMode = NSLineBreakByTruncatingMiddle;
  if ([col.identifier isEqualToString:@"name"]) {
    t.stringValue = DCNS(f.path);
    t.toolTip = t.stringValue;
  } else {
    t.stringValue = DCNS(dcmm::formatBytes(f.bytes));
    t.alignment = NSTextAlignmentRight;
    t.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
  }
  return t;
}

- (void)tog:(NSButton*)s {
  if (s.tag >= 0 && s.tag < (NSInteger)_files.size()) {
    _files[(size_t)s.tag].selected = s.state == NSControlStateValueOn;
    [self refreshClean];
  }
}

@end

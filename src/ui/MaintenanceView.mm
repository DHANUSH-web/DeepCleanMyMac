#import "ui/MaintenanceView.h"
#import "ui/Theme.h"
#include "dcmm/dcmm.hpp"
#include "Modules.h"

namespace {

struct ConfirmCopy {
  NSString* title;
  NSString* body;
  NSString* proceed;
};

ConfirmCopy ConfirmForTask(const std::string& id, const dcmm::MaintenanceTask& task) {
  if (id == "empty_trash") {
    return {@"Empty Trash permanently?",
            @"This permanently deletes every item currently in your user Trash.\n\n"
             @"• Cannot be undone from this app\n"
             @"• Only items already in Trash are removed\n"
             @"• Documents, apps, and system files outside Trash are not touched\n"
             @"• Symlinks that point outside Trash are skipped",
            @"Empty Trash"};
  }
  if (id == "flush_dns") {
    return {@"Flush the DNS cache?",
            @"This only clears locally cached DNS lookups (dscacheutil).\n\n"
             @"• Does not delete files, apps, or browsing history\n"
             @"• Some sites may need a moment to resolve again\n"
             @"• No documents or settings are changed",
            @"Flush DNS Cache"};
  }
  if (id == "launch_services") {
    return {@"Rebuild Launch Services?",
            @"This refreshes the user-domain database that maps file types to apps "
             @"(the Open With menu).\n\n"
             @"• Does not delete documents or applications\n"
             @"• Only the current user domain is rebuilt\n"
             @"• The Open With list may take a moment to repopulate",
            @"Rebuild"};
  }
  if (id == "quicklook") {
    return {@"Clear Quick Look caches?",
            @"Thumbnail and preview caches in your user Library/Caches will be moved to Trash "
             @"(not erased in place).\n\n"
             @"• Original documents are not deleted\n"
             @"• Caches rebuild as you preview files in Finder\n"
             @"• You can restore the cache folders from Trash until it is emptied",
            @"Move Caches to Trash"};
  }
  return {DCNS(task.title),
          [NSString stringWithFormat:@"%@\n\n%@", DCNS(task.detail),
                                     task.note.empty() ? @"This action cannot be undone from this screen."
                                                       : DCNS(task.note)],
          @"Run"};
}

}  // namespace

@implementation DCMaintenanceView {
  dcmm::Engine _engine;
}

- (NSView*)cardForTask:(const dcmm::MaintenanceTask&)task index:(NSInteger)index {
  NSTextField* title = DCLabel(DCNS(task.title));
  title.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
  title.maximumNumberOfLines = 1;
  [title setContentHuggingPriority:NSLayoutPriorityDefaultLow
                    forOrientation:NSLayoutConstraintOrientationHorizontal];
  [title setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];

  NSTextField* subtitle = DCSecondaryLabel(DCNS(task.detail));
  subtitle.font = [NSFont preferredFontForTextStyle:NSFontTextStyleSubheadline options:@{}];
  subtitle.maximumNumberOfLines = 0;
  [subtitle setContentHuggingPriority:NSLayoutPriorityDefaultLow
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
  [subtitle setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                     forOrientation:NSLayoutConstraintOrientationHorizontal];

  NSStackView* text = [NSStackView stackViewWithViews:@[ title, subtitle ]];
  text.orientation = NSUserInterfaceLayoutOrientationVertical;
  text.alignment = NSLayoutAttributeLeading;
  text.spacing = 4;
  [text setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [text setContentCompressionResistancePriority:1
                                 forOrientation:NSLayoutConstraintOrientationHorizontal];

  NSButton* run = (task.id == "empty_trash") ? DCDestructiveButton(@"Run", self, @selector(runTask:))
                                             : DCPushButton(@"Run", self, @selector(runTask:));
  run.tag = index;
  [run setContentHuggingPriority:NSLayoutPriorityRequired
                  forOrientation:NSLayoutConstraintOrientationHorizontal];
  [run setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                forOrientation:NSLayoutConstraintOrientationHorizontal];

  NSView* spacer = [[NSView alloc] initWithFrame:NSZeroRect];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [spacer setContentCompressionResistancePriority:1
                                   forOrientation:NSLayoutConstraintOrientationHorizontal];

  NSStackView* body = [NSStackView stackViewWithViews:@[ text, spacer, run ]];
  body.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  body.alignment = NSLayoutAttributeCenterY;
  body.spacing = 16;
  body.edgeInsets = NSEdgeInsetsMake(16, 16, 16, 16);

  NSVisualEffectView* card = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
  card.material = NSVisualEffectMaterialContentBackground;
  card.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  card.state = NSVisualEffectStateFollowsWindowActiveState;
  card.wantsLayer = YES;
  card.layer.cornerRadius = 10;
  card.layer.masksToBounds = YES;
  [card addSubview:body];
  DCPinEdges(body, card);
  [card setContentHuggingPriority:NSLayoutPriorityRequired
                   forOrientation:NSLayoutConstraintOrientationVertical];
  return card;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSStackView* page = DCPageStack(self);
    NSStackView* header = DCHeaderStack(
        @"Maintenance", [NSString stringWithUTF8String:ui::subtitle(ui::Module::Maintenance)]);
    [page addArrangedSubview:header];
    DCStackFullWidth(page, header);

    auto tasks = _engine.maintenanceTasks();
    NSMutableArray<NSView*>* cards = [NSMutableArray array];
    for (size_t i = 0; i < tasks.size(); ++i) {
      [cards addObject:[self cardForTask:tasks[i] index:(NSInteger)i]];
    }

    NSStackView* list = [NSStackView stackViewWithViews:cards];
    list.orientation = NSUserInterfaceLayoutOrientationVertical;
    list.alignment = NSLayoutAttributeLeading;
    list.spacing = 12;
    [list setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationVertical];
    [page addArrangedSubview:list];
    DCStackFullWidth(page, list);
    for (NSView* card in cards) {
      [card.widthAnchor constraintEqualToAnchor:list.widthAnchor].active = YES;
    }

    NSView* spacer = DCFlexibleSpace();
    [page addArrangedSubview:spacer];
    DCStackFullWidth(page, spacer);
  }
  return self;
}

- (void)runTask:(NSButton*)sender {
  auto tasks = _engine.maintenanceTasks();
  if (sender.tag < 0 || sender.tag >= (NSInteger)tasks.size()) return;
  const auto& task = tasks[(size_t)sender.tag];
  auto preview = _engine.previewMaintenance(task.id);
  if (preview.nothingToDo) {
    DCInformNothingToClean(DCNS(preview.message));
    return;
  }
  ConfirmCopy c = ConfirmForTask(task.id, task);
  if (preview.bytesFreed > 0) {
    c.body = [NSString stringWithFormat:@"%@\n\nCurrently using %@.", c.body,
                                        DCNS(dcmm::formatBytes(preview.bytesFreed))];
  }
  if (!DCConfirmDestructive(c.title, c.body, c.proceed)) return;
  auto result = _engine.runMaintenance(task.id);
  if (result.nothingToDo) {
    DCInformNothingToClean(DCNS(result.message));
    return;
  }
  NSString* doneTitle = result.bytesFreed > 0
                            ? [NSString stringWithFormat:@"Freed %@", DCNS(dcmm::formatBytes(result.bytesFreed))]
                            : @"Finished";
  DCInformCleaned(doneTitle, DCNS(result.message));
}

@end

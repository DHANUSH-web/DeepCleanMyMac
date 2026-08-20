#import "AppDelegate.h"

int main(int argc, const char* argv[]) {
  (void)argc;
  (void)argv;
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    AppDelegate* delegate = [AppDelegate new];
    NSApp.delegate = delegate;
    [NSApp run];
  }
  return 0;
}

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "NeoSystemNotifications.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--system-notifications") == 0) {
            const char *cmd = (argc > 2) ? argv[2] : "on";
            return NeoSystemNotificationsRun(cmd);
        }
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

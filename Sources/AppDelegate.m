#import "AppDelegate.h"
#import "LoginViewController.h"
#import "TabBarController.h"
#import "MatrixAPIClient.h"
#import "MatrixSyncManager.h"
#import "RoomListViewController.h"
#import "ThemeManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    [ThemeManager sharedManager]; // carga theme guardado

    MatrixAPIClient *client = [MatrixAPIClient sharedClient];

    if (client.accessToken) {
        self.tabBarController = [[TabBarController alloc] init];
        self.window.rootViewController = self.tabBarController;
    } else {
        self.loginViewController = [[LoginViewController alloc] init];
        self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.loginViewController];
        self.window.rootViewController = self.navigationController;
    }

    [self.window makeKeyAndVisible];

    if (launchOptions[UIApplicationLaunchOptionsLocalNotificationKey]) {
        NSDictionary *userInfo = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
        [self handleNotificationUserInfo:userInfo];
    }

    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[MatrixSyncManager sharedManager] startSync];

    self.backgroundTaskId = [application beginBackgroundTaskWithExpirationHandler:^{
        [[MatrixSyncManager sharedManager] stopSync];
        [application endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[MatrixSyncManager sharedManager] stopSync];

    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        [application endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if (application.applicationState == UIApplicationStateInactive) {
        NSDictionary *userInfo = notification.userInfo;
        [self handleNotificationUserInfo:userInfo];
    }
}

- (void)handleNotificationUserInfo:(NSDictionary *)userInfo {
    NSString *roomId = userInfo[@"room_id"];
    if ([roomId length] == 0) return;

    if (self.tabBarController) {
        self.tabBarController.selectedIndex = 0;
        UINavigationController *nav = (UINavigationController *)self.tabBarController.selectedViewController;
        if ([nav.topViewController isKindOfClass:[RoomListViewController class]]) {
            RoomListViewController *list = (RoomListViewController *)nav.topViewController;
            [list navigateToRoom:roomId];
        }
    }
}

@end

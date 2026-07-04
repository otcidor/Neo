#import <UIKit/UIKit.h>

@class LoginViewController;
@class TabBarController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) TabBarController *tabBarController;
@property (strong, nonatomic) UINavigationController *navigationController;
@property (strong, nonatomic) LoginViewController *loginViewController;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@end

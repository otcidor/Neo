#import "TabBarController.h"
#import "RoomListViewController.h"
#import "SettingsViewController.h"
#import "NetworksViewController.h"
#import "LoginViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"

@implementation TabBarController {
    UINavigationController *_chatsNav;
    UINavigationController *_networksNav;
    UINavigationController *_settingsNav;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;

    RoomListViewController *allVC = [[RoomListViewController alloc] init];
    allVC.title = NSLocalizedString(@"Chats", nil);
    allVC.theme = SpaceThemeDefault;
    allVC.spaceFilter = nil;
    _chatsNav = [[UINavigationController alloc]
        initWithRootViewController:allVC];
    UIImage *chatsIcon = [UIImage imageNamed:@"TabIconMessages_Gray"];
    if (!chatsIcon) chatsIcon = [UIImage imageNamed:@"Balloon_WhiteSolid"];
    _chatsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Chats", nil)
                                                         image:chatsIcon
                                                           tag:0];
    if (IS_IOS7_OR_LATER) {
        _chatsNav.tabBarItem.image = [chatsIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        [_chatsNav.tabBarItem setFinishedSelectedImage:chatsIcon
                          withFinishedUnselectedImage:chatsIcon];
    }

    NetworksViewController *networksVC = [[NetworksViewController alloc] init];
    _networksNav = [[UINavigationController alloc]
        initWithRootViewController:networksVC];
    UIImage *redesIcon = [UIImage imageNamed:@"TabIconContacts_Gray"];
    if (!redesIcon) redesIcon = [UIImage imageNamed:@"Balloon_GreenSolid"];
    _networksNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Networks", nil)
                                                                  image:redesIcon
                                                                    tag:1];
    if (IS_IOS7_OR_LATER) {
        _networksNav.tabBarItem.image = [redesIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        [_networksNav.tabBarItem setFinishedSelectedImage:redesIcon
                                     withFinishedUnselectedImage:redesIcon];
    }

    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    _settingsNav = [[UINavigationController alloc]
        initWithRootViewController:settingsVC];
    UIImage *settingsIcon = [UIImage imageNamed:@"TabIconSettings_Gray"];
    if (!settingsIcon) settingsIcon = [UIImage imageNamed:@"Settings"];
    _settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil)
                                                            image:settingsIcon
                                                              tag:2];
    if (IS_IOS7_OR_LATER) {
        _settingsNav.tabBarItem.image = [settingsIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        [_settingsNav.tabBarItem setFinishedSelectedImage:settingsIcon
                               withFinishedUnselectedImage:settingsIcon];
    }

    [self updateTabVisibility];

    [self applyTabBarTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTabBarTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTabVisibility)
                                                 name:@"NeoNetworksVisibilityChanged"
                                               object:nil];
}

- (void)updateTabVisibility {
    BOOL hide = [[NSUserDefaults standardUserDefaults] boolForKey:@"neo_hide_networks_tab"];
    if (hide) {
        self.viewControllers = @[_chatsNav, _settingsNav];
    } else {
        self.viewControllers = @[_chatsNav, _networksNav, _settingsNav];
    }
}

- (void)applyTabBarTheme {
    ThemeManager *tm = [ThemeManager sharedManager];
    [tm applyThemeToTabBar:self.tabBar];
    for (UIViewController *vc in self.viewControllers) {
        if ([vc isKindOfClass:[UINavigationController class]]) {
            [tm applyThemeToNavigationBar:[(UINavigationController *)vc navigationBar]];
        }
    }
}

- (void)showLogin {
    LoginViewController *login = [[LoginViewController alloc] init];
    UINavigationController *loginNav = [[UINavigationController alloc]
        initWithRootViewController:login];
    [self presentViewController:loginNav animated:YES completion:nil];
}

@end

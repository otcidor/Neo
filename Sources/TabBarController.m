#import "TabBarController.h"
#import "RoomListViewController.h"
#import "SettingsViewController.h"
#import "LoginViewController.h"
#import "ThemeManager.h"
#import "NeoAlert.h"
#import "NeoCompatibility.h"

@implementation TabBarController {
    UIViewController *_redesPlaceholder;
    NSInteger _lastSelectedIndex;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    _lastSelectedIndex = 0;

    RoomListViewController *allVC = [[RoomListViewController alloc] init];
    allVC.title = NSLocalizedString(@"Chats", nil);
    allVC.theme = SpaceThemeDefault;
    allVC.spaceFilter = nil;
    UINavigationController *chatsNav = [[UINavigationController alloc]
        initWithRootViewController:allVC];
    UIImage *chatsIcon = [UIImage imageNamed:@"TabIconMessages_Gray"];
    if (!chatsIcon) chatsIcon = [UIImage imageNamed:@"Balloon_WhiteSolid"];
    chatsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Chats", nil)
                                                        image:chatsIcon
                                                          tag:0];
    if (IS_IOS7_OR_LATER) {
        chatsNav.tabBarItem.image = [chatsIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        [chatsNav.tabBarItem setFinishedSelectedImage:chatsIcon
                          withFinishedUnselectedImage:chatsIcon];
    }

    _redesPlaceholder = [[UIViewController alloc] init];
    _redesPlaceholder.view.backgroundColor = [UIColor colorWithWhite:0.93
                                                               alpha:1.0];
    UIImage *redesIcon = [UIImage imageNamed:@"TabIconContacts_Gray"];
    if (!redesIcon) redesIcon = [UIImage imageNamed:@"Balloon_GreenSolid"];
    _redesPlaceholder.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Networks", nil)
                                                                 image:redesIcon
                                                                   tag:1];
    if (IS_IOS7_OR_LATER) {
        _redesPlaceholder.tabBarItem.image = [redesIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        [_redesPlaceholder.tabBarItem setFinishedSelectedImage:redesIcon
                                     withFinishedUnselectedImage:redesIcon];
    }

    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc]
        initWithRootViewController:settingsVC];
    UIImage *settingsIcon = [UIImage imageNamed:@"TabIconSettings_Gray"];
    if (!settingsIcon) settingsIcon = [UIImage imageNamed:@"Settings"];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil)
                                                           image:settingsIcon
                                                             tag:2];
    if (IS_IOS7_OR_LATER) {
        settingsNav.tabBarItem.image = [settingsIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        [settingsNav.tabBarItem setFinishedSelectedImage:settingsIcon
                               withFinishedUnselectedImage:settingsIcon];
    }

    self.viewControllers = @[chatsNav, _redesPlaceholder, settingsNav];

    [self applyTabBarTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTabBarTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
}

#pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tbc
    shouldSelectViewController:(UIViewController *)vc {
    if (vc == _redesPlaceholder) {
        [self showRedesActionSheet];
        return NO;
    }
    _lastSelectedIndex = [self.viewControllers indexOfObject:vc];
    return YES;
}

- (void)showRedesActionSheet {
    NSArray *nets = @[@"WhatsApp", @"Telegram", @"Discord", @"Instagram"];
    [NeoAlert showActionSheetWithTitle:NSLocalizedString(@"Select network", nil)
                           cancelTitle:NSLocalizedString(@"Cancel", nil)
                      destructiveTitle:nil
                           otherTitles:nets
                            controller:self
                           sourceRect:CGRectZero
                           sourceView:self.view
                               handler:^(NSInteger index) {
        if (index == 0) return;
        NSDictionary *map = @{
            @1: @{@"filter": @"whatsapp", @"title": @"WhatsApp",
                  @"theme": @(SpaceThemeWhatsApp),
                  @"r": @0.145, @"g": @0.827, @"b": @0.400},
            @2: @{@"filter": @"telegram", @"title": @"Telegram",
                  @"theme": @(SpaceThemeTelegram),
                  @"r": @0.0, @"g": @0.533, @"b": @0.800},
            @3: @{@"filter": @"discord", @"title": @"Discord",
                  @"theme": @(SpaceThemeDiscord),
                  @"r": @0.345, @"g": @0.396, @"b": @0.949},
            @4: @{@"filter": @"instagram", @"title": @"Instagram",
                  @"theme": @(SpaceThemeInstagram),
                  @"r": @0.882, @"g": @0.188, @"b": @0.424},
        };
        NSDictionary *info = map[@(index)];
        if (!info) return;

        RoomListViewController *vc = [[RoomListViewController alloc] init];
        vc.title = info[@"title"];
        vc.theme = [info[@"theme"] intValue];
        vc.spaceFilter = info[@"filter"];

        UIColor *tint = [UIColor colorWithRed:[info[@"r"] floatValue]
                                        green:[info[@"g"] floatValue]
                                         blue:[info[@"b"] floatValue]
                                        alpha:1.0];
        UINavigationController *nav = [[UINavigationController alloc]
            initWithRootViewController:vc];
        if (IS_IOS7_OR_LATER) {
            nav.navigationBar.barTintColor = tint;
            nav.navigationBar.tintColor = [UIColor whiteColor];
            nav.navigationBar.titleTextAttributes = @{UITextAttributeTextColor: [UIColor whiteColor]};
        } else {
            nav.navigationBar.tintColor = tint;
        }

        vc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithTitle:NSLocalizedString(@"Close", nil)
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(dismissRedModal)];
        [self presentViewController:nav animated:YES completion:nil];
    }];
}

- (void)dismissRedModal {
    [self dismissViewControllerAnimated:YES completion:nil];
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

#import "SettingsViewController.h"
#import "MatrixAPIClient.h"
#import "LoginViewController.h"
#import "ArchiveManager.h"
#import "ArchivedChatsViewController.h"
#import "WallpaperGalleryViewController.h"
#import "ThemeManager.h"
#import "ThemeSelectionViewController.h"
#import "BubbleStylePickerController.h"
#import "NeoAlert.h"
#import "NeoCompatibility.h"
#import "DemoModeManager.h"

static NSString *const kBubbleStyleKey = @"neo_bubble_style";
static NSString *const kWallpaperKey = @"neo_wallpaper";

static NSString *const kMessageLimitKey = @"neo_message_limit";

@interface SettingsViewController () <UIAlertViewDelegate, UIActionSheetDelegate>
@end

static NSString *kWpNames[] = {
    @"Default",
    @"Abstract",
    @"Particles",
    @"Flowers",
    @"Leaves",
    @"Landscape",
    @"Sunset",
    @"Texture",
    @"Bubbles",
    @"Circles",
    @"Stripes",
    @"Hexagons",
    @"Triangles",
    @"Fabric",
};

static NSString *kWpImages[] = {
    @"wallpaper_61",
    @"wallpaper_01",
    @"wallpaper_03",
    @"wallpaper_04.jpg",
    @"wallpaper_05.jpg",
    @"wallpaper_07.jpg",
    @"wallpaper_08.jpg",
    @"wallpaper_12.jpg",
    @"wallpaper_14.jpg",
    @"wallpaper_55",
    @"wallpaper_56",
    @"wallpaper_57",
    @"wallpaper_59",
    @"wallpaper_60.jpg",
};

@implementation SettingsViewController {
    UITableView *_tableView;
    NSInteger _serverTapCount;
    NSTimer *_tapResetTimer;
}

- (void)loadView {
    [super loadView];
    self.title = NSLocalizedString(@"Settings", nil);

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h)
                                              style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundView = nil;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeChanged)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self applyThemeToUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyThemeToUI];
    [_tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return NSLocalizedString(@"Account", nil);
    if (section == 1) return NSLocalizedString(@"Chats", nil);
    if (section == 2) return NSLocalizedString(@"Session", nil);
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    CGFloat w = tableView.bounds.size.width;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 32.0f)];
    v.backgroundColor = [tm backgroundColor];

    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    if ([title length] > 0) {
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 32, 16)];
        lbl.font = [UIFont boldSystemFontOfSize:12];
        lbl.textColor = [tm secondaryTextColor];
        lbl.backgroundColor = [UIColor clearColor];
        lbl.text = [title uppercaseString];
        [v addSubview:lbl];
    }
    return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return (section == 2) ? 24.0f : 12.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    CGFloat h = [self tableView:tableView heightForFooterInSection:section];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, h)];
    v.backgroundColor = [tm backgroundColor];
    return v;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) {
        NSInteger base = 6;
        return [DemoModeManager sharedManager].demoModeUnlocked ? base + 1 : base;
    }
    if (section == 2) return 2;
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ThemeManager *tm_cell = [ThemeManager sharedManager];
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    CGFloat cellW = tableView.bounds.size.width;

    if (indexPath.section == 0) {
        static NSString *valueCellId = @"SettingsValueCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:valueCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                          reuseIdentifier:valueCellId];
        }
        cell.backgroundColor = [tm_cell cellBackgroundColor];
        cell.textLabel.textColor = [tm_cell primaryTextColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.detailTextLabel.textColor = [tm_cell secondaryTextColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        if (indexPath.row == 0) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"user"];
            cell.textLabel.text = NSLocalizedString(@"Username", nil);
            BOOL demo = [DemoModeManager sharedManager].demoModeEnabled;
            cell.detailTextLabel.text = demo ? @"@user:matrix.org" : (client.userId ?: @"—");
        } else {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"server"];
            cell.textLabel.text = NSLocalizedString(@"Server", nil);
            BOOL demo = [DemoModeManager sharedManager].demoModeEnabled;
            cell.detailTextLabel.text = demo ? @"https://matrix.org" : (client.homeserver ?: @"—");
        }

        UIView *sep = [cell.contentView viewWithTag:98];
        if (!sep) {
            sep = [[UIView alloc] initWithFrame:CGRectZero];
            sep.tag = 98;
            [cell.contentView addSubview:sep];
        }
        sep.frame = (indexPath.row == 1) ? CGRectMake(0, 43.5f, cellW, 0.5f) : CGRectMake(58.0f, 43.5f, cellW - 58.0f, 0.5f);
        sep.backgroundColor = [tm_cell separatorColor];

        return cell;

    } else if (indexPath.section == 1) {
        if (indexPath.row == 4 || (indexPath.row == 6 && [DemoModeManager sharedManager].demoModeUnlocked)) {
            static NSString *switchCellId = @"SettingsSwitchCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:switchCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:switchCellId];
            }
            cell.backgroundColor = [tm_cell cellBackgroundColor];
            cell.textLabel.textColor = [tm_cell primaryTextColor];
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.detailTextLabel.text = nil;
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UISwitch *toggle = [cell.accessoryView isKindOfClass:[UISwitch class]] ? (UISwitch *)cell.accessoryView : nil;
            if (!toggle) {
                toggle = [[UISwitch alloc] init];
                cell.accessoryView = toggle;
            }
            if ([toggle respondsToSelector:@selector(setOnTintColor:)]) {
                toggle.onTintColor = [UIColor colorWithRed:0.20 green:0.52 blue:0.98 alpha:1.0];
            }

            if (indexPath.row == 4) {
                cell.imageView.image = [ThemeManager settingsIconNamed:@"networks"];
                cell.textLabel.text = NSLocalizedString(@"Hide Networks", nil);
                [toggle removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [toggle addTarget:self action:@selector(hideNetworksToggled:)
                 forControlEvents:UIControlEventValueChanged];
                toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"neo_hide_networks_tab"];
            } else {
                cell.imageView.image = [ThemeManager settingsIconNamed:@"demo"];
                cell.textLabel.text = @"Demo Mode";
                [toggle removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [toggle addTarget:self action:@selector(demoModeToggled:)
                 forControlEvents:UIControlEventValueChanged];
                toggle.on = [DemoModeManager sharedManager].demoModeEnabled;
            }

            NSInteger totalRows = [self tableView:tableView numberOfRowsInSection:1];
            BOOL isLast = (indexPath.row == totalRows - 1);
            UIView *sep = [cell.contentView viewWithTag:98];
            if (!sep) {
                sep = [[UIView alloc] initWithFrame:CGRectZero];
                sep.tag = 98;
                [cell.contentView addSubview:sep];
            }
            sep.frame = isLast ? CGRectMake(0, 43.5f, cellW, 0.5f) : CGRectMake(58.0f, 43.5f, cellW - 58.0f, 0.5f);
            sep.backgroundColor = [tm_cell separatorColor];

            return cell;
        }

        static NSString *valueCellId = @"SettingsValueCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:valueCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                          reuseIdentifier:valueCellId];
        }
        cell.backgroundColor = [tm_cell cellBackgroundColor];
        cell.textLabel.textColor = [tm_cell primaryTextColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.detailTextLabel.textColor = [tm_cell secondaryTextColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;

        if (tm_cell.isDarkGlass) {
            cell.accessoryView = [ThemeManager modernDisclosureIndicator];
            UIView *selBg = [[UIView alloc] init];
            selBg.backgroundColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.28 alpha:1.0];
            cell.selectedBackgroundView = selBg;
        } else {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectedBackgroundView = nil;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }

        if (indexPath.row == 0) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"archive"];
            cell.textLabel.text = NSLocalizedString(@"Archived", nil);
            NSInteger count = [[[ArchiveManager sharedManager] archivedRoomIds] count];
            cell.detailTextLabel.text = (count > 0) ? [NSString stringWithFormat:@"%d", (int)count] : @"";
        } else if (indexPath.row == 1) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"wallpaper"];
            cell.textLabel.text = NSLocalizedString(@"Chat Wallpaper", nil);
            NSString *wp = [[NSUserDefaults standardUserDefaults] stringForKey:kWallpaperKey] ?: kWpImages[0];
            cell.detailTextLabel.text = NSLocalizedString(kWpNames[0], nil);
            for (int i = 0; i < 14; i++) {
                if ([wp isEqualToString:kWpImages[i]]) {
                    cell.detailTextLabel.text = NSLocalizedString(kWpNames[i], nil);
                    break;
                }
            }
        } else if (indexPath.row == 2) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"bubble"];
            cell.textLabel.text = NSLocalizedString(@"Bubble Style", nil);
            NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:kBubbleStyleKey];
            NSDictionary *names = @{
                @"neo": @"Neo", @"neo-cyan": @"Cyan",
                @"neo-purple": @"Purple", @"neo-pink": @"Pink",
                @"neo-orange": @"Orange", @"neo-red": @"Red",
                @"neo-teal": @"Teal", @"neo-indigo": @"Indigo",
                @"whatsapp": @"WhatsApp",
                @"neo-telegram": @"Telegram",
                @"neo-telegram-classic": @"Telegram Classic",
            };
            cell.detailTextLabel.text = names[style] ?: (style == nil ? @"Neo" : style);
        } else if (indexPath.row == 3) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"theme"];
            cell.textLabel.text = @"Theme";
            cell.detailTextLabel.text = [ThemeManager nameForThemeId:[ThemeManager sharedManager].currentThemeId];
        } else if (indexPath.row == 5) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"limit"];
            cell.textLabel.text = NSLocalizedString(@"Message Limit", nil);
            NSInteger limit = [[NSUserDefaults standardUserDefaults] integerForKey:kMessageLimitKey];
            cell.detailTextLabel.text = (limit <= 0) ? NSLocalizedString(@"No limit", nil) : [NSString stringWithFormat:@"%ld", (long)limit];
        }

        NSInteger totalRows = [self tableView:tableView numberOfRowsInSection:1];
        BOOL isLast = (indexPath.row == totalRows - 1);
        UIView *sep = [cell.contentView viewWithTag:98];
        if (!sep) {
            sep = [[UIView alloc] initWithFrame:CGRectZero];
            sep.tag = 98;
            [cell.contentView addSubview:sep];
        }
        sep.frame = isLast ? CGRectMake(0, 43.5f, cellW, 0.5f) : CGRectMake(58.0f, 43.5f, cellW - 58.0f, 0.5f);
        sep.backgroundColor = [tm_cell separatorColor];

        return cell;

    } else {
        static NSString *actionCellId = @"SettingsActionCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:actionCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:actionCellId];
        }
        cell.backgroundColor = [tm_cell cellBackgroundColor];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        cell.detailTextLabel.text = nil;

        if (tm_cell.isDarkGlass) {
            UIView *selBg = [[UIView alloc] init];
            selBg.backgroundColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.28 alpha:1.0];
            cell.selectedBackgroundView = selBg;
        } else {
            cell.selectedBackgroundView = nil;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }

        if (indexPath.row == 0) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"logout"];
            cell.textLabel.text = NSLocalizedString(@"Logout", nil);
            cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
        } else {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"clearcache"];
            cell.textLabel.text = NSLocalizedString(@"Clear Cache", nil);
            cell.textLabel.textColor = [tm_cell primaryTextColor];
        }

        UIView *sep = [cell.contentView viewWithTag:98];
        if (!sep) {
            sep = [[UIView alloc] initWithFrame:CGRectZero];
            sep.tag = 98;
            [cell.contentView addSubview:sep];
        }
        sep.frame = (indexPath.row == 1) ? CGRectMake(0, 43.5f, cellW, 0.5f) : CGRectMake(58.0f, 43.5f, cellW - 58.0f, 0.5f);
        sep.backgroundColor = [tm_cell separatorColor];

        return cell;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *hv = (UITableViewHeaderFooterView *)view;
        hv.textLabel.textColor = [tm secondaryTextColor];
        hv.contentView.backgroundColor = [tm backgroundColor];
    }
}

- (void)resetTapCount {
    _serverTapCount = 0;
}

- (void)demoModeToggled:(UISwitch *)toggle {
    [DemoModeManager sharedManager].demoModeEnabled = toggle.on;
    if (!toggle.on) {
        [DemoModeManager sharedManager].demoModeUnlocked = NO;
        _serverTapCount = 0;
    }
    [_tableView reloadData];
}

- (void)hideNetworksToggled:(UISwitch *)toggle {
    [[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:@"neo_hide_networks_tab"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeoNetworksVisibilityChanged"
                                                        object:nil];
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 1) {
        _serverTapCount++;
        [_tapResetTimer invalidate];
        _tapResetTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                           target:self
                                                         selector:@selector(resetTapCount)
                                                         userInfo:nil
                                                          repeats:NO];
        if (_serverTapCount >= 5) {
            _serverTapCount = 0;
            [_tapResetTimer invalidate];
            BOOL wasUnlocked = [DemoModeManager sharedManager].demoModeUnlocked;
            [DemoModeManager sharedManager].demoModeUnlocked = !wasUnlocked;
            NSString *title = wasUnlocked ? @"🔒 Demo Mode" : @"🔓 Demo Mode";
            NSString *msg = wasUnlocked ? @"Demo mode hidden. Tap 5 times again to show." : @"Demo mode unlocked. A new option appeared below.";
            [NeoAlert showAlertWithTitle:title
                                 message:msg
                             cancelTitle:@"OK"
                              controller:self];
            [_tableView reloadData];
        }
        return;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            ArchivedChatsViewController *vc = [[ArchivedChatsViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 1) {
            WallpaperGalleryViewController *vc = [[WallpaperGalleryViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 2) {
            BubbleStylePickerController *vc = [[BubbleStylePickerController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 3) {
            ThemeSelectionViewController *vc = [[ThemeSelectionViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 5) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Message Limit", nil)
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:@"20", @"50", NSLocalizedString(@"No limit", nil), nil];
            sheet.tag = 555;
            [sheet showInView:self.view];
        }
        return;
    }
    if (indexPath.section == 2 && indexPath.row == 0) {
        UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"Logout", nil)
                  message:NSLocalizedString(@"Are you sure you want to logout?", nil)
                 delegate:self
        cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
        otherButtonTitles:NSLocalizedString(@"Logout", nil), nil];
        alert.tag = 1001;
        [alert show];
    }
    if (indexPath.section == 2 && indexPath.row == 1) {
        UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"Clear Cache", nil)
                  message:NSLocalizedString(@"Are you sure?", nil)
                 delegate:self
        cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
        otherButtonTitles:NSLocalizedString(@"Clear", nil), nil];
        alert.tag = 1002;
        [alert show];
    }
}

- (void)themeChanged {
    [self applyThemeToUI];
    [_tableView reloadData];
}

- (void)applyThemeToUI {
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];
    _tableView.backgroundColor = [tm backgroundColor];
    if ([_tableView respondsToSelector:@selector(setSeparatorColor:)]) {
        _tableView.separatorColor = [tm separatorColor];
    }
    [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    if (!IS_IOS7_OR_LATER) self.navigationController.navigationBar.barStyle = [tm barStyle];
}

- (void)actionSheet:(UIActionSheet *)actionSheet
    clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag != 555) return;
    if (buttonIndex == 3 || buttonIndex < 0) return;
    NSInteger limits[] = {20, 50, 0};
    if (buttonIndex < 3) {
        [[NSUserDefaults standardUserDefaults] setInteger:limits[buttonIndex] forKey:kMessageLimitKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [_tableView reloadData];
}

- (void)alertView:(UIAlertView *)alertView
    clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        if (alertView.tag == 1001) {
            [[MatrixAPIClient sharedClient] clearAllCaches];
            [[MatrixAPIClient sharedClient] clearCredentials];
            LoginViewController *login = [[LoginViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc]
                initWithRootViewController:login];
            UIWindow *window = self.view.window ?: [[UIApplication sharedApplication] keyWindow];
            window.rootViewController = nav;
            [window makeKeyAndVisible];
        } else if (alertView.tag == 1002) {
            [[MatrixAPIClient sharedClient] clearAllCaches];
            UIAlertView *doneAlert = [[UIAlertView alloc]
                initWithTitle:NSLocalizedString(@"Cache Cleared", nil)
                      message:NSLocalizedString(@"Local cache has been cleared.", nil)
                     delegate:nil
            cancelButtonTitle:NSLocalizedString(@"OK", nil)
            otherButtonTitles:nil];
            [doneAlert show];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

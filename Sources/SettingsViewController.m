#import "SettingsViewController.h"
#import "MatrixAPIClient.h"
#import "LoginViewController.h"
#import "ArchiveManager.h"
#import "ArchivedChatsViewController.h"
#import "WallpaperGalleryViewController.h"
#import "ThemeManager.h"
#import "ThemeSelectionViewController.h"
#import "NeoAlert.h"
#import "NeoCompatibility.h"

static NSString *const kBubbleStyleKey = @"neo_bubble_style";
static NSString *const kWallpaperKey = @"neo_wallpaper";

@interface SettingsViewController () <UIAlertViewDelegate>
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
    @"TG Classic",
    @"TG Blue",
    @"TG Purple",
    @"TG Dark",
    @"TG Green",
    @"TG Pink",
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
    @"wallpaper_tg.jpg",
    @"wallpaper_tg_0.jpg",
    @"wallpaper_tg_1.jpg",
    @"wallpaper_tg_2.jpg",
    @"wallpaper_tg_3.jpg",
    @"wallpaper_tg_4.jpg",
};

@implementation SettingsViewController {
    UITableView *_tableView;
}

- (void)loadView {
    [super loadView];
    self.title = NSLocalizedString(@"Settings", nil);

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h)
                                              style:UITableViewStyleGrouped];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundView = nil;
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
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return 4;
    if (section == 2) return 1;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:cellId];
    }
    ThemeManager *tm_cell = [ThemeManager sharedManager];
    cell.backgroundColor = [tm_cell cellBackgroundColor];
    cell.textLabel.textColor = [tm_cell primaryTextColor];
    cell.detailTextLabel.textColor = [tm_cell secondaryTextColor];

    MatrixAPIClient *client = [MatrixAPIClient sharedClient];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Username", nil);
            cell.detailTextLabel.text = client.userId ?: @"—";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = NSLocalizedString(@"Server", nil);
            cell.detailTextLabel.text = client.homeserver ?: @"—";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Archived", nil);
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            NSInteger count = [[[ArchiveManager sharedManager] archivedRoomIds] count];
            if (count > 0) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)count];
            } else {
                cell.detailTextLabel.text = @"";
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Chat Wallpaper", nil);
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            NSString *wp = [[NSUserDefaults standardUserDefaults] stringForKey:kWallpaperKey] ?: kWpImages[0];
            cell.detailTextLabel.text = NSLocalizedString(kWpNames[0], nil);
            for (int i = 0; i < 20; i++) {
                if ([wp isEqualToString:kWpImages[i]]) {
                    cell.detailTextLabel.text = NSLocalizedString(kWpNames[i], nil);
                    break;
                }
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = NSLocalizedString(@"Bubble Style", nil);
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:kBubbleStyleKey];
            if ([style isEqualToString:@"telegram"]) {
                cell.detailTextLabel.text = @"Telegram";
            } else {
                cell.detailTextLabel.text = @"Predeterminado";
            }
        } else {
            cell.textLabel.text = @"Theme";
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.detailTextLabel.text = [ThemeManager nameForThemeId:[ThemeManager sharedManager].currentThemeId];
        }
    } else {
        cell.textLabel.text = NSLocalizedString(@"Logout", nil);
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *hv = (UITableViewHeaderFooterView *)view;
        hv.textLabel.textColor = [tm secondaryTextColor];
        hv.contentView.backgroundColor = [tm backgroundColor];
    }
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            ArchivedChatsViewController *vc = [[ArchivedChatsViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 1) {
            WallpaperGalleryViewController *vc = [[WallpaperGalleryViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 2) {
            [self showBubbleStylePicker];
        } else if (indexPath.row == 3) {
            ThemeSelectionViewController *vc = [[ThemeSelectionViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
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
    [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    if (!IS_IOS7_OR_LATER) self.navigationController.navigationBar.barStyle = [tm barStyle];
}

- (void)showBubbleStylePicker {
    [NeoAlert showActionSheetWithTitle:NSLocalizedString(@"Bubble Style", nil)
                           cancelTitle:NSLocalizedString(@"Cancel", nil)
                      destructiveTitle:nil
                           otherTitles:@[NSLocalizedString(@"Default", nil), @"Telegram"]
                            controller:self
                           sourceRect:CGRectZero
                           sourceView:self.view
                               handler:^(NSInteger index) {
        if (index == 0) return;
        NSString *style = (index == 2) ? @"telegram" : @"default";
        [[NSUserDefaults standardUserDefaults] setObject:style forKey:kBubbleStyleKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [_tableView reloadData];
    }];
}

- (void)alertView:(UIAlertView *)alertView
    clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [[MatrixAPIClient sharedClient] clearCredentials];
        LoginViewController *login = [[LoginViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc]
            initWithRootViewController:login];
        UIWindow *window = self.view.window ?: [[UIApplication sharedApplication] keyWindow];
        window.rootViewController = nav;
        [window makeKeyAndVisible];
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

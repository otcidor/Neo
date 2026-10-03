#import "NetworksViewController.h"
#import "RoomListViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"
#import "NeoSkeuoRenderer.h"

@interface NetworksViewController ()
@property (nonatomic, strong) NSArray *networks;
@end

@implementation NetworksViewController

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    view.backgroundColor = [UIColor whiteColor];
    self.view = view;

    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h)
                                                  style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = 70.0f;
    self.tableView.tableFooterView = [[UIView alloc] init];
    if (IS_IOS7_OR_LATER) {
        self.tableView.separatorInset = UIEdgeInsetsMake(0, 74, 0, 0);
    }
    [view addSubview:self.tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Networks", nil);

    self.networks = @[
        @{
            @"name": @"WhatsApp",
            @"subtitle": NSLocalizedString(@"WhatsApp bridge rooms & chats", nil),
            @"filter": @"whatsapp",
            @"icon": @"network_whatsapp",
            @"theme": @(SpaceThemeWhatsApp),
            @"color": [UIColor colorWithRed:0.145 green:0.827 blue:0.400 alpha:1.0]
        },
        @{
            @"name": @"Telegram",
            @"subtitle": NSLocalizedString(@"Telegram groups & channels", nil),
            @"filter": @"telegram",
            @"icon": @"network_telegram",
            @"theme": @(SpaceThemeTelegram),
            @"color": [UIColor colorWithRed:0.0 green:0.533 blue:0.800 alpha:1.0]
        },
        @{
            @"name": @"Discord",
            @"subtitle": NSLocalizedString(@"Discord guilds & direct messages", nil),
            @"filter": @"discord",
            @"icon": @"network_discord",
            @"theme": @(SpaceThemeDiscord),
            @"color": [UIColor colorWithRed:0.345 green:0.396 blue:0.949 alpha:1.0]
        },
        @{
            @"name": @"Instagram",
            @"subtitle": NSLocalizedString(@"Instagram direct messages", nil),
            @"filter": @"instagram",
            @"icon": @"network_instagram",
            @"theme": @(SpaceThemeInstagram),
            @"color": [UIColor colorWithRed:0.882 green:0.188 blue:0.424 alpha:1.0]
        },
    ];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
    [self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
    [self.tableView reloadData];
}

- (void)applyTheme {
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];
    self.tableView.backgroundColor = [tm backgroundColor];
    if (self.navigationController) {
        [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
        if (!IS_IOS7_OR_LATER) self.navigationController.navigationBar.barStyle = [tm barStyle];
    }
    if ([self.tableView respondsToSelector:@selector(setSeparatorColor:)]) {
        self.tableView.separatorColor = [tm separatorColor];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 34.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    CGFloat w = tableView.bounds.size.width;
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 34.0f)];
    h.backgroundColor = [tm backgroundColor];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 32, 16)];
    lbl.font = [UIFont boldSystemFontOfSize:12.0f];
    lbl.textColor = [tm secondaryTextColor];
    lbl.backgroundColor = [UIColor clearColor];
    lbl.text = [NSLocalizedString(@"Bridged Networks", nil) uppercaseString];
    if (tm.isSkeuomorphicMode) {
        lbl.shadowColor = tm.isDarkMode ? [UIColor colorWithWhite:0.0f alpha:0.6f] : [UIColor whiteColor];
        lbl.shadowOffset = tm.isDarkMode ? CGSizeMake(0, -1.0f) : CGSizeMake(0, 1.0f);
    }
    [h addSubview:lbl];
    return h;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 44.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    CGFloat w = tableView.bounds.size.width;
    UIView *f = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44.0f)];
    f.backgroundColor = [tm backgroundColor];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, w - 32, 28)];
    lbl.font = [UIFont systemFontOfSize:12.0f];
    lbl.textColor = [tm secondaryTextColor];
    lbl.numberOfLines = 2;
    lbl.backgroundColor = [UIColor clearColor];
    lbl.text = NSLocalizedString(@"Conversations from external networks bridged to your Matrix account.", nil);
    if (tm.isSkeuomorphicMode) {
        lbl.shadowColor = tm.isDarkMode ? [UIColor colorWithWhite:0.0f alpha:0.6f] : [UIColor whiteColor];
        lbl.shadowOffset = tm.isDarkMode ? CGSizeMake(0, -1.0f) : CGSizeMake(0, 1.0f);
    }
    [f addSubview:lbl];
    return f;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return [self.networks count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cellId = @"NetworkCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellId];

        // 1. Icon Container with elevation shadow
        UIView *shadowBox = [[UIView alloc] initWithFrame:CGRectMake(14, 11, 48, 48)];
        shadowBox.tag = 101;
        shadowBox.backgroundColor = [UIColor clearColor];
        shadowBox.layer.shadowColor = [UIColor blackColor].CGColor;
        shadowBox.layer.shadowOpacity = 0.28f;
        shadowBox.layer.shadowOffset = CGSizeMake(0, 1.5f);
        shadowBox.layer.shadowRadius = 2.0f;
        shadowBox.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 48, 48) cornerRadius:10.0f].CGPath;

        // 2. Icon ImageView inside shadowBox
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
        iconView.tag = 102;
        iconView.layer.cornerRadius = 10.0f;
        iconView.layer.masksToBounds = YES;
        iconView.layer.borderWidth = 0.5f;
        iconView.layer.borderColor = [UIColor colorWithWhite:0.0f alpha:0.25f].CGColor;
        iconView.contentMode = UIViewContentModeScaleAspectFill;
        [shadowBox addSubview:iconView];
        [cell.contentView addSubview:shadowBox];

        // 3. Title Label
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(74, 15, cell.contentView.bounds.size.width - 110, 22)];
        titleLabel.tag = 103;
        titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:titleLabel];

        // 4. Subtitle Label
        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(74, 38, cell.contentView.bounds.size.width - 110, 18)];
        subLabel.tag = 104;
        subLabel.font = [UIFont systemFontOfSize:13.0f];
        subLabel.backgroundColor = [UIColor clearColor];
        subLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:subLabel];
    }

    NSDictionary *net = self.networks[ip.row];
    ThemeManager *tm = [ThemeManager sharedManager];

    cell.backgroundColor = [tm cellBackgroundColor];

    // Configure Icon
    UIView *shadowBox = [cell.contentView viewWithTag:101];
    UIImageView *iconView = (UIImageView *)[shadowBox viewWithTag:102];
    NSString *iconName = net[@"icon"];
    UIImage *iconImg = [UIImage imageNamed:iconName];
    iconView.image = iconImg;

    // Configure Title
    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:103];
    titleLabel.text = net[@"name"];
    titleLabel.textColor = [tm primaryTextColor];

    // Configure Subtitle
    UILabel *subLabel = (UILabel *)[cell.contentView viewWithTag:104];
    subLabel.text = net[@"subtitle"];
    subLabel.textColor = [tm secondaryTextColor];

    // Text shadows for skeuomorphic depth
    if (tm.isSkeuomorphicMode) {
        if (tm.isDarkMode) {
            titleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.8f];
            titleLabel.shadowOffset = CGSizeMake(0, -1.0f);
            subLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
            subLabel.shadowOffset = CGSizeMake(0, -1.0f);
        } else {
            titleLabel.shadowColor = [UIColor whiteColor];
            titleLabel.shadowOffset = CGSizeMake(0, 1.0f);
            subLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.8f];
            subLabel.shadowOffset = CGSizeMake(0, 1.0f);
        }
    } else {
        titleLabel.shadowColor = nil;
        titleLabel.shadowOffset = CGSizeZero;
        subLabel.shadowColor = nil;
        subLabel.shadowOffset = CGSizeZero;
    }

    // Accessory and Selection Style
    if (tm.isDarkGlass) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = [ThemeManager modernDisclosureIndicator];
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0];
        cell.selectedBackgroundView = selBg;
    } else if (tm.isSkeuomorphicMode) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = [NeoSkeuoRenderer classicDisclosureIndicator];
        UIView *selBg = [[UIView alloc] init];
        if (tm.isDarkMode) {
            selBg.backgroundColor = [UIColor colorWithRed:0.18 green:0.20 blue:0.26 alpha:1.0];
        } else {
            selBg.backgroundColor = [UIColor colorWithRed:0.88 green:0.91 blue:0.96 alpha:1.0];
        }
        cell.selectedBackgroundView = selBg;
    } else {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectedBackgroundView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }

    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *net = self.networks[ip.row];

    RoomListViewController *vc = [[RoomListViewController alloc] init];
    vc.title = net[@"name"];
    vc.theme = [net[@"theme"] intValue];
    vc.spaceFilter = net[@"filter"];

    ThemeManager *tm = [ThemeManager sharedManager];
    UINavigationController *nav = self.navigationController;
    if (tm.isDarkGlass) {
        [tm applyThemeToNavigationBar:nav.navigationBar];
    } else if (tm.isSkeuomorphicMode) {
        UIColor *tint = net[@"color"];
        UIImage *barImg = [NeoSkeuoRenderer navBarImageWithColor:tint height:44.0f];
        [nav.navigationBar setBackgroundImage:barImg forBarMetrics:UIBarMetricsDefault];
        if (IS_IOS7_OR_LATER) {
            UIImage *barImg64 = [NeoSkeuoRenderer navBarImageWithColor:tint height:64.0f];
            if ([nav.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarPosition:barMetrics:)]) {
                [(id)nav.navigationBar setBackgroundImage:barImg64 forBarPosition:UIBarPositionTopAttached barMetrics:UIBarMetricsDefault];
            }
            nav.navigationBar.barTintColor = [NeoSkeuoRenderer darkTabTintColorForThemeColor:tint];
            nav.navigationBar.tintColor = [UIColor whiteColor];
        } else {
            nav.navigationBar.tintColor = tint;
        }
        nav.navigationBar.translucent = NO;
        if ([nav.navigationBar respondsToSelector:@selector(setShadowImage:)]) {
            nav.navigationBar.shadowImage = [NeoSkeuoRenderer clearPixelImage];
        }
        nav.navigationBar.titleTextAttributes = @{
            UITextAttributeTextColor: [UIColor whiteColor],
            UITextAttributeTextShadowColor: [UIColor colorWithWhite:0.0f alpha:0.6f],
            UITextAttributeTextShadowOffset: [NSValue valueWithCGSize:CGSizeMake(0, -1.0f)],
            UITextAttributeFont: [UIFont boldSystemFontOfSize:18.0f]
        };
    } else {
        UIColor *tint = net[@"color"];
        if (IS_IOS7_OR_LATER) {
            nav.navigationBar.barTintColor = tint;
            nav.navigationBar.tintColor = [UIColor whiteColor];
            nav.navigationBar.titleTextAttributes = @{UITextAttributeTextColor: [UIColor whiteColor]};
        } else {
            nav.navigationBar.tintColor = tint;
        }
    }

    [nav pushViewController:vc animated:YES];
}

@end

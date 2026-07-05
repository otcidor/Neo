#import "NetworksViewController.h"
#import "RoomListViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"

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
    self.tableView.rowHeight = 60;
    self.tableView.tableFooterView = [[UIView alloc] init];
    if (IS_IOS7_OR_LATER) self.tableView.separatorInset = UIEdgeInsetsMake(0, 15, 0, 0);
    [view addSubview:self.tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Networks", nil);

    self.networks = @[
        @{@"name": @"WhatsApp",  @"filter": @"whatsapp",  @"theme": @(SpaceThemeWhatsApp),
          @"color": [UIColor colorWithRed:0.145 green:0.827 blue:0.400 alpha:1.0]},
        @{@"name": @"Telegram",  @"filter": @"telegram",  @"theme": @(SpaceThemeTelegram),
          @"color": [UIColor colorWithRed:0.0 green:0.533 blue:0.800 alpha:1.0]},
        @{@"name": @"Discord",   @"filter": @"discord",   @"theme": @(SpaceThemeDiscord),
          @"color": [UIColor colorWithRed:0.345 green:0.396 blue:0.949 alpha:1.0]},
        @{@"name": @"Instagram", @"filter": @"instagram", @"theme": @(SpaceThemeInstagram),
          @"color": [UIColor colorWithRed:0.882 green:0.188 blue:0.424 alpha:1.0]},
    ];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
    [self applyTheme];
}

- (void)applyTheme {
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];
    self.tableView.backgroundColor = [tm backgroundColor];
    if (self.navigationController) {
        [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return [self.networks count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }

    NSDictionary *net = self.networks[ip.row];
    cell.textLabel.text = net[@"name"];
    cell.textLabel.textColor = net[@"color"];
    cell.imageView.image = nil;

    ThemeManager *tm = [ThemeManager sharedManager];
    cell.backgroundColor = [tm cellBackgroundColor];
    cell.textLabel.backgroundColor = [UIColor clearColor];

    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *net = self.networks[ip.row];

    RoomListViewController *vc = [[RoomListViewController alloc] init];
    vc.title = net[@"name"];
    vc.theme = [net[@"theme"] intValue];
    vc.spaceFilter = net[@"filter"];

    UIColor *tint = net[@"color"];
    UINavigationController *nav = self.navigationController;
    if (IS_IOS7_OR_LATER) {
        nav.navigationBar.barTintColor = tint;
        nav.navigationBar.tintColor = [UIColor whiteColor];
        nav.navigationBar.titleTextAttributes = @{UITextAttributeTextColor: [UIColor whiteColor]};
    } else {
        nav.navigationBar.tintColor = tint;
    }

    [nav pushViewController:vc animated:YES];
}

@end

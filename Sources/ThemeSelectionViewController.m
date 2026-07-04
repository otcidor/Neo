#import "ThemeSelectionViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"
#import <QuartzCore/QuartzCore.h>

@implementation ThemeSelectionViewController {
    UITableView *_tableView;
    NSArray *_lightThemes;
    NSArray *_darkThemes;
}

- (void)loadView {
    [super loadView];
    self.title = @"Theme";

    _lightThemes = @[@(NeoThemeLightDefault), @(NeoThemeLightGreen),
                      @(NeoThemeLightCyan), @(NeoThemeLightPurple), @(NeoThemeLightPink)];
    _darkThemes = @[@(NeoThemeDarkGray), @(NeoThemeDarkGreen),
                     @(NeoThemeDarkBlue), @(NeoThemeDarkPurple), @(NeoThemeDarkRed)];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h)
                                              style:UITableViewStyleGrouped];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundView = nil;
    [self.view addSubview:_tableView];

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

- (void)applyThemeToUI {
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];
    _tableView.backgroundColor = [tm backgroundColor];
    [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    if (!IS_IOS7_OR_LATER) self.navigationController.navigationBar.barStyle = [tm barStyle];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Light" : @"Dark mode";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? [_lightThemes count] : [_darkThemes count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ThemeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellId];
    }

    NeoThemeId themeId = (NeoThemeId)[(indexPath.section == 0 ? _lightThemes : _darkThemes)[indexPath.row] integerValue];
    ThemeManager *tm = [ThemeManager sharedManager];

    cell.backgroundColor = [tm cellBackgroundColor];
    cell.textLabel.textColor = [tm primaryTextColor];
    cell.textLabel.text = [ThemeManager nameForThemeId:themeId];
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;

    cell.indentationLevel = 3;
    cell.indentationWidth = 18;

    UIView *swatch = [cell.contentView viewWithTag:77];
    if (!swatch) {
        swatch = [[UIView alloc] initWithFrame:CGRectMake(12, 8, 28, 28)];
        swatch.tag = 77;
        swatch.layer.cornerRadius = 6;
        [cell.contentView addSubview:swatch];
    }
    swatch.backgroundColor = [ThemeManager swatchColorForThemeId:themeId];

    cell.accessoryType = (themeId == tm.currentThemeId)
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;

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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NeoThemeId themeId = (NeoThemeId)[(indexPath.section == 0 ? _lightThemes : _darkThemes)[indexPath.row] integerValue];
    [[ThemeManager sharedManager] setThemeId:themeId];
    [self applyThemeToUI];
    [tableView reloadData];
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

@end

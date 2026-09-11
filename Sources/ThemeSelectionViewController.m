#import "ThemeSelectionViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"
#import <QuartzCore/QuartzCore.h>

@implementation ThemeSelectionViewController {
    UITableView *_tableView;
    NSArray *_lightThemes;
    NSArray *_darkThemes;
    NSArray *_darkGlassThemes;
}

- (void)loadView {
    [super loadView];
    self.title = NSLocalizedString(@"Theme", nil);

    _lightThemes = @[@(NeoThemeLightDefault), @(NeoThemeLightGreen),
                      @(NeoThemeLightCyan), @(NeoThemeLightPurple), @(NeoThemeLightPink)];
    _darkThemes = @[@(NeoThemeDarkGray), @(NeoThemeDarkGreen),
                     @(NeoThemeDarkBlue), @(NeoThemeDarkPurple), @(NeoThemeDarkRed)];
    _darkGlassThemes = @[@(NeoThemeDarkGlass)];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h)
                                              style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundView = nil;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleThemeChanged)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
    [self applyThemeToUI];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyThemeToUI];
    [_tableView reloadData];
}

- (void)handleThemeChanged {
    [self applyThemeToUI];
    [_tableView reloadData];
}

- (void)applyThemeToUI {
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];
    _tableView.backgroundColor = [tm backgroundColor];
    [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    if (!IS_IOS7_OR_LATER && !tm.isDarkGlass) {
        self.navigationController.navigationBar.barStyle = [tm barStyle];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return NSLocalizedString(@"Light", nil);
    if (section == 1) return NSLocalizedString(@"Dark", nil);
    return NSLocalizedString(@"Others", nil);
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return [_lightThemes count];
    if (section == 1) return [_darkThemes count];
    return [_darkGlassThemes count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ThemeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellId];
    }

    NSArray *themes = (indexPath.section == 0) ? _lightThemes : ((indexPath.section == 1) ? _darkThemes : _darkGlassThemes);
    NeoThemeId themeId = (NeoThemeId)[themes[indexPath.row] integerValue];
    ThemeManager *tm = [ThemeManager sharedManager];

    cell.backgroundColor = [tm cellBackgroundColor];
    cell.textLabel.text = [ThemeManager nameForThemeId:themeId];
    cell.textLabel.textColor = [tm primaryTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.textLabel.backgroundColor = [UIColor clearColor];

    cell.indentationLevel = 1;
    cell.indentationWidth = 56;

    if (tm.isDarkGlass) {
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.13 green:0.16 blue:0.20 alpha:1.0];
        cell.selectedBackgroundView = selBg;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }

    UIView *swatch = [cell.contentView viewWithTag:77];
    if (!swatch) {
        swatch = [[UIView alloc] initWithFrame:CGRectMake(16, 8, 28, 28)];
        swatch.tag = 77;
        swatch.layer.cornerRadius = 6;
        swatch.layer.masksToBounds = YES;
        [cell.contentView addSubview:swatch];
    }
    swatch.backgroundColor = [ThemeManager swatchColorForThemeId:themeId];
    if (tm.isDarkGlass) {
        swatch.layer.borderWidth = 0.5f;
        swatch.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    } else {
        swatch.layer.borderWidth = 0.0f;
    }

    if (themeId == tm.currentThemeId) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    CGFloat cellW = tableView.bounds.size.width;
    BOOL isLastRow = (indexPath.row == [themes count] - 1);
    UIView *sep = [cell.contentView viewWithTag:98];
    if (!sep) {
        sep = [[UIView alloc] initWithFrame:CGRectZero];
        sep.tag = 98;
        sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:sep];
    }
    sep.frame = isLastRow ? CGRectMake(0, 43.5f, cellW, 0.5f) : CGRectMake(56.0f, 43.5f, cellW - 56.0f, 0.5f);
    sep.backgroundColor = [tm separatorColor];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *themes = (indexPath.section == 0) ? _lightThemes : ((indexPath.section == 1) ? _darkThemes : _darkGlassThemes);
    NeoThemeId themeId = (NeoThemeId)[themes[indexPath.row] integerValue];
    [[ThemeManager sharedManager] setThemeId:themeId];
    [self applyThemeToUI];
    [tableView reloadData];
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

@end

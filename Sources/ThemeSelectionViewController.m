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
    self.navigationItem.leftBarButtonItem = [ThemeManager backBarButtonItemWithTarget:self action:@selector(neoBackAction)];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleThemeChanged)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
    [self applyThemeToUI];
}

- (void)neoBackAction {
    [self.navigationController popViewControllerAnimated:YES];
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
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return NSLocalizedString(@"Interface Style", nil);
    if (section == 1) return NSLocalizedString(@"Light", nil);
    if (section == 2) return NSLocalizedString(@"Dark", nil);
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
    return (section == 3) ? 24.0f : 12.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    CGFloat h = [self tableView:tableView heightForFooterInSection:section];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, h)];
    v.backgroundColor = [tm backgroundColor];
    return v;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return [_lightThemes count];
    if (section == 2) return [_darkThemes count];
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

    ThemeManager *tm = [ThemeManager sharedManager];
    cell.backgroundColor = [tm cellBackgroundColor];
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

    CGFloat cellW = tableView.bounds.size.width;

    if (indexPath.section == 0) {
        // Interface Style section: Skeuomorphic vs Flat
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"iOS 6 Skeuomorphic", nil);
            swatch.backgroundColor = [UIColor colorWithRed:0.20f green:0.52f blue:0.88f alpha:1.0f];
            cell.accessoryType = tm.isSkeuomorphicMode ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        } else {
            cell.textLabel.text = NSLocalizedString(@"Modern Flat", nil);
            swatch.backgroundColor = [UIColor colorWithWhite:0.45f alpha:1.0f];
            cell.accessoryType = !tm.isSkeuomorphicMode ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
        swatch.layer.borderWidth = 0.5f;
        swatch.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.2f].CGColor;

        UIView *sep = [cell.contentView viewWithTag:98];
        if (!sep) {
            sep = [[UIView alloc] initWithFrame:CGRectZero];
            sep.tag = 98;
            sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:sep];
        }
        sep.frame = (indexPath.row == 1) ? CGRectMake(0, 43.5f, cellW, 0.5f) : CGRectMake(56.0f, 43.5f, cellW - 56.0f, 0.5f);
        sep.backgroundColor = [tm separatorColor];
        return cell;
    }

    // Color themes sections:
    NSArray *themes = (indexPath.section == 1) ? _lightThemes : ((indexPath.section == 2) ? _darkThemes : _darkGlassThemes);
    NeoThemeId themeId = (NeoThemeId)[themes[indexPath.row] integerValue];

    cell.textLabel.text = [ThemeManager nameForThemeId:themeId];
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
    ThemeManager *tm = [ThemeManager sharedManager];

    if (indexPath.section == 0) {
        BOOL skeuo = (indexPath.row == 0);
        [tm setSkeuomorphicMode:skeuo];
        [self applyThemeToUI];
        [tableView reloadData];
        return;
    }

    NSArray *themes = (indexPath.section == 1) ? _lightThemes : ((indexPath.section == 2) ? _darkThemes : _darkGlassThemes);
    NeoThemeId themeId = (NeoThemeId)[themes[indexPath.row] integerValue];
    [tm setThemeId:themeId];
    [self applyThemeToUI];
    [tableView reloadData];
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

@end

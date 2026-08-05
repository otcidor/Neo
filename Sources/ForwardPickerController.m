#import "ForwardPickerController.h"
#import "MatrixModels.h"
#import "MatrixAPIClient.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"

@implementation ForwardPickerController {
    UITableView *_tableView;
    NSArray *_rooms;
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    view.backgroundColor = [UIColor whiteColor];
    self.view = view;

    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;

    CGFloat barH = 44;
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, barH)];
    topBar.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [view addSubview:topBar];

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.frame = CGRectMake(8, 0, 70, barH);
    [cancelBtn setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [cancelBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:cancelBtn];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 0, w - 172, barH)];
    titleLabel.text = NSLocalizedString(@"Forward to…", nil);
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:titleLabel];

    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, barH - 0.5, w, 0.5)];
    separator.backgroundColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:separator];

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, barH, w, h - barH)
                                               style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 60;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.tableFooterView = [[UIView alloc] init];
    [view addSubview:_tableView];

    ThemeManager *tm = [ThemeManager sharedManager];
    if (tm.isDarkMode) {
        view.backgroundColor = [tm backgroundColor];
        _tableView.backgroundColor = [tm backgroundColor];
        topBar.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        titleLabel.textColor = [UIColor whiteColor];
        separator.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    }

    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
                           stringByAppendingPathComponent:@"com.neo.roomCache.plist"];
    NSMutableArray *rooms = [[NSArray arrayWithContentsOfFile:cachePath] mutableCopy];
    if (![rooms isKindOfClass:[NSArray class]]) rooms = [NSMutableArray array];

    // Sort by name
    [rooms sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] compare:b[@"name"] options:NSCaseInsensitiveSearch];
    }];

    _rooms = rooms;
    [_tableView reloadData];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return [_rooms count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"FwdCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    }

    NSDictionary *r = _rooms[ip.row];
    cell.textLabel.text = r[@"name"] ?: r[@"roomId"] ?: @"";
    cell.textLabel.textColor = [UIColor blackColor];

    ThemeManager *tm = [ThemeManager sharedManager];
    if (tm.isDarkMode) {
        cell.backgroundColor = [tm cellBackgroundColor];
        cell.textLabel.textColor = [tm primaryTextColor];
    }

    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *r = _rooms[ip.row];
    NSString *roomId = r[@"roomId"];
    if (!roomId || !self.message) return;

    if ([self.message.msgType isEqualToString:@"m.text"] || [self.message.body length] > 0) {
        [[MatrixAPIClient sharedClient] sendMessage:self.message.body
                                             roomId:roomId
                                         completion:nil];
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

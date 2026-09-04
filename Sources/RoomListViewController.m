#import "RoomListViewController.h"
#import "MatrixAPIClient.h"
#import "MatrixModels.h"
#import "SpaceManager.h"
#import "ChatViewController.h"
#import "LoginViewController.h"
#import "ArchiveManager.h"
#import "MatrixSyncManager.h"
#import <QuartzCore/QuartzCore.h>
#import "ThemeManager.h"
#import "NeoCompatibility.h"
#import "DemoModeManager.h"
#import "UIImage+NeoBlur.h"
#import "TGTableDeltaUpdater.h"

static UIColor *colorForTheme(SpaceTheme theme) {
    switch (theme) {
        case SpaceThemeWhatsApp:  return [UIColor colorWithRed:0.145 green:0.827 blue:0.400 alpha:1.0];
        case SpaceThemeTelegram:  return [UIColor colorWithRed:0.0 green:0.533 blue:0.800 alpha:1.0];
        case SpaceThemeDiscord:   return [UIColor colorWithRed:0.345 green:0.396 blue:0.949 alpha:1.0];
        case SpaceThemeInstagram: return [UIColor colorWithRed:0.882 green:0.188 blue:0.424 alpha:1.0];
        default:                  return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    }
}

@implementation RoomListViewController {
    NSMutableDictionary *_roomAvatars;
    NSTimer *_saveCacheTimer;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h)
                                                  style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];

    self.rooms = [NSMutableArray array];
    _roomAvatars = [NSMutableDictionary dictionary];
    [self loadRoomsFromCache];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUnreadUpdate:)
                                                 name:MatrixSyncUnreadUpdateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRoomBatch:)
                                                 name:MatrixRoomBatchNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSessionExpired)
                                                 name:MatrixSessionExpiredNotification
                                               object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    ThemeManager *tm = [ThemeManager sharedManager];
    UIColor *tint = colorForTheme(self.theme);
    if (self.spaceFilter != nil && tm.isDarkMode) {
        CGFloat r, g, b, a;
        [tint getRed:&r green:&g blue:&b alpha:&a];
        tint = [UIColor colorWithRed:r*0.3 green:g*0.3 blue:b*0.3 alpha:1.0];
    }

    if (self.spaceFilter == nil) {
        [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    } else {
        if (IS_IOS7_OR_LATER) {
            self.navigationController.navigationBar.barTintColor = tint;
            self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
            self.navigationController.navigationBar.titleTextAttributes = @{UITextAttributeTextColor: [UIColor whiteColor]};
        } else {
            self.navigationController.navigationBar.tintColor = tint;
        }
    }

    if (tm.isDarkMode) {
        if (!IS_IOS7_OR_LATER) self.navigationController.navigationBar.barStyle = [tm barStyle];
        self.tableView.backgroundColor = [tm backgroundColor];
        self.view.backgroundColor = [tm backgroundColor];
    } else if (self.spaceFilter == nil) {
        self.tableView.backgroundColor = [UIColor whiteColor];
        self.view.backgroundColor = [UIColor whiteColor];
    }

    if (self.spaceFilter == nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleThemeChanged)
                                                     name:NeoThemeDidChangeNotification
                                                   object:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDemoModeChanged)
                                                 name:NeoDemoModeDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCacheDidClear)
                                                 name:NeoCacheDidClearNotification
                                               object:nil];

    [self updateTitleView];

    if (!self.filteredRooms) self.filteredRooms = [NSMutableArray array];
    CGFloat w = self.view.bounds.size.width;

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    headerView.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    self.searchBar.placeholder = NSLocalizedString(@"Search", nil);
    self.searchBar.delegate = self;
    self.searchBar.backgroundImage = [[UIImage alloc] init];
    self.searchBar.showsCancelButton = YES;
    [headerView addSubview:self.searchBar];

    ThemeManager *tm_sb = [ThemeManager sharedManager];
    if (tm_sb.isDarkMode) {
        self.searchBar.barStyle = [tm_sb barStyle];
        headerView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    } else if (self.spaceFilter == nil) {
        self.searchBar.barStyle = [tm_sb barStyle];
    }

    self.tableView.tableHeaderView = headerView;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)dismissKeyboard {
    [self.searchBar resignFirstResponder];
}

- (void)updateTitleView {
    NSString *titleStr = self.title;
    if ([titleStr length] == 0) titleStr = @" ";
    int cnt = (int)[self.filteredRooms count];
    NSString *subStr = (cnt == 1) ? NSLocalizedString(@"1 chat", nil) : [NSString stringWithFormat:NSLocalizedString(@"%d chats", nil), cnt];
    NSString *combined = [NSString stringWithFormat:@"%@\n%@", titleStr, subStr];

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:combined];
    [attr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:16] range:NSMakeRange(0, [titleStr length])];
    [attr addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, [titleStr length])];
    [attr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:11] range:NSMakeRange([titleStr length] + 1, [subStr length])];
    [attr addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:0.85 alpha:1.0] range:NSMakeRange([titleStr length] + 1, [subStr length])];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.attributedText = attr;
    [titleLabel sizeToFit];

    self.navigationItem.titleView = titleLabel;
}

- (void)updateSubtitle {
    [self updateTitleView];
}

- (NSString *)relativeDate:(NSDate *)date {
    if (!date) return @"";
    NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:date];
    if (diff < 60) return NSLocalizedString(@"now", nil);
    if (diff < 3600) return [NSString stringWithFormat:NSLocalizedString(@"%dm", nil), (int)(diff/60)];

    time_t now = time(NULL);
    time_t t = [date timeIntervalSince1970];
    struct tm nowTm, dateTm;
    localtime_r(&now, &nowTm);
    localtime_r(&t, &dateTm);

    if (nowTm.tm_year == dateTm.tm_year && nowTm.tm_yday == dateTm.tm_yday) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = NSLocalizedString(@"HH:mm", nil);
        return [fmt stringFromDate:date];
    }
    if (nowTm.tm_year == dateTm.tm_year && nowTm.tm_yday - dateTm.tm_yday == 1) {
        return NSLocalizedString(@"yesterday", nil);
    }
    if (nowTm.tm_year == dateTm.tm_year) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"EEE dd/MM";
        return [fmt stringFromDate:date];
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = NSLocalizedString(@"dd/MM/yy", nil);
    return [fmt stringFromDate:date];
}

- (void)applyFilters {
    NSString *query = [[self.searchBar.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
        lowercaseString];

    NSArray *oldFiltered = [self.filteredRooms copy];

    NSMutableArray *base = [NSMutableArray array];
    for (MatrixRoom *r in self.rooms) {
        if ([[ArchiveManager sharedManager] isArchivedRoomId:r.roomId]) continue;
        if (self.spaceFilter != nil && [self.spaceFilter length] > 0) {
            NSString *bridge = [[SpaceManager sharedManager] bridgeTypeForRoomId:r.roomId];
            if (!bridge ||
                [bridge rangeOfString:self.spaceFilter options:NSCaseInsensitiveSearch].location == NSNotFound) {
                continue;
            }
        }
        [base addObject:r];
    }

    if ([query length] > 0) {
        NSMutableArray *tmp = [NSMutableArray array];
        for (MatrixRoom *r in base) {
            BOOL nameMatch = [[r.name lowercaseString]
                rangeOfString:query].location != NSNotFound;
            BOOL msgMatch = [[r.lastMessage lowercaseString]
                rangeOfString:query].location != NSNotFound;
            if (nameMatch || msgMatch) [tmp addObject:r];
        }
        self.filteredRooms = tmp;
    } else {
        self.filteredRooms = base;
    }

    if ([query length] > 0 || !oldFiltered) {
        [self.tableView reloadData];
    } else {
        [TGTableDeltaUpdater replaceItemsInTable:oldFiltered
                                    withNewItems:self.filteredRooms
                            singleUpdateBlock:^(NSArray<TGTableAlignment *> *deletes,
                                                NSArray<TGTableAlignment *> *inserts) {
            [self.tableView beginUpdates];
            for (TGTableAlignment *al in deletes) {
                NSMutableArray *idxs = [NSMutableArray array];
                for (NSInteger i = al.pos; i < al.pos + al.len; i++) {
                    [idxs addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
                if ([idxs count]) {
                    [self.tableView deleteRowsAtIndexPaths:idxs withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            for (TGTableAlignment *al in inserts) {
                NSMutableArray *idxs = [NSMutableArray array];
                for (NSInteger i = al.pos; i < al.pos + al.len; i++) {
                    [idxs addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
                if ([idxs count]) {
                    [self.tableView insertRowsAtIndexPaths:idxs withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            [self.tableView endUpdates];
        }];
    }
    [self updateSubtitle];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
    [self applyFilters];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [self applyFilters];
}

- (void)composeTapped {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"New Chat", nil)
                                                    message:NSLocalizedString(@"Enter user ID to start a chat", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"Start", nil), nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 100;
    [alert show];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Data is always current: the model is fed by MatrixRoomBatchNotification
    // (persistent observer since loadView). Just re-render the current filters.
    [self applyFilters];
}

- (void)handleSessionExpired {
    if (self.spaceFilter != nil) return; // only the main list acts
    [[MatrixAPIClient sharedClient] clearCredentials];
    LoginViewController *login = [[LoginViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
    UIWindow *window = self.view.window ?: [[UIApplication sharedApplication] keyWindow];
    window.rootViewController = nav;
    [window makeKeyAndVisible];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_saveCacheTimer invalidate];
}

- (void)handleCacheDidClear {
    [_saveCacheTimer invalidate];
    _saveCacheTimer = nil;
    [self.rooms removeAllObjects];
    [self.filteredRooms removeAllObjects];
    [_roomAvatars removeAllObjects];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        [self updateSubtitle];
    });
}

- (void)handleRoomBatch:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSDictionary *join = userInfo[@"join"];
    NSArray *leave = userInfo[@"leave"];
    if (![join isKindOfClass:[NSDictionary class]]) join = nil;
    if (![leave isKindOfClass:[NSArray class]]) leave = nil;

    BOOL changed = NO;

    // Rooms left / kicked
    for (NSString *roomId in leave) {
        if (![roomId isKindOfClass:[NSString class]]) continue;
        for (NSInteger i = 0; i < [self.rooms count]; i++) {
            MatrixRoom *r = [self.rooms objectAtIndex:i];
            if ([r.roomId isEqualToString:roomId]) {
                [self.rooms removeObjectAtIndex:i];
                [_roomAvatars removeObjectForKey:roomId];
                changed = YES;
                break;
            }
        }
    }

    if (join) {
        // Space/bridge map (m.space.child + uk.half-shot.bridge deltas) feeds the filters.
        [[SpaceManager sharedManager] buildSpaceMapFromSyncResponse:@{
            @"rooms": @{@"join": join}
        }];

        NSString *myId = [[MatrixAPIClient sharedClient] userId];
        NSMutableArray *pendingAvatarDownloads = nil;

        for (NSString *roomId in [join allKeys]) {
            if (![roomId isKindOfClass:[NSString class]]) continue;
            NSDictionary *roomData = [join objectForKey:roomId];
            if (![roomData isKindOfClass:[NSDictionary class]]) continue;

            MatrixRoom *room = nil;
            for (MatrixRoom *r in self.rooms) {
                if ([r.roomId isEqualToString:roomId]) { room = r; break; }
            }
            if (!room) {
                room = [[MatrixRoom alloc] initWithDictionary:@{@"room_id": roomId}];
                [self.rooms addObject:room];
                changed = YES;
            }

            if ([self applyRoomData:room data:roomData myUserId:myId]) {
                changed = YES;
                if ([room.avatarUrl length] > 0 && ![_roomAvatars objectForKey:roomId]) {
                    if (!pendingAvatarDownloads) pendingAvatarDownloads = [NSMutableArray array];
                    [pendingAvatarDownloads addObject:@[roomId, room.avatarUrl]];
                }
            }
        }

        if (changed) {
            for (NSArray *pair in pendingAvatarDownloads) {
                [[MatrixAPIClient sharedClient] downloadImageFromMXC:[pair objectAtIndex:1]
                                                          completion:^(UIImage *image, NSError *dlErr) {
                    if (image) {
                        [_roomAvatars setObject:image forKey:[pair objectAtIndex:0]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.tableView reloadData];
                        });
                    }
                }];
            }
        }
    }

    if (changed) {
        [self.rooms sortUsingComparator:^NSComparisonResult(MatrixRoom *r1, MatrixRoom *r2) {
            NSDate *d1 = r1.lastMessageDate;
            NSDate *d2 = r2.lastMessageDate;
            if (!d1 && !d2) return NSOrderedSame;
            if (!d1) return NSOrderedDescending;
            if (!d2) return NSOrderedAscending;
            return [d2 compare:d1];
        }];
        [self applyFilters];
        [self scheduleCacheSave];
    }
}

// Apply a /sync room batch as deltas on top of the persisted model (elementold
// style). Real state events (name/alias/avatar) always win; member-derived
// fallbacks apply ONLY when no explicit name/avatar has ever been seen — an
// incremental batch with no state can never clobber a good name.
- (BOOL)applyRoomData:(MatrixRoom *)room data:(NSDictionary *)roomData myUserId:(NSString *)myId {
    __block BOOL changed = NO;
    __block NSString *fallbackName = nil;
    __block NSString *fallbackAvatar = nil;
    void (^considerEvent)(NSDictionary *) = ^(NSDictionary *evt) {
        if (![evt isKindOfClass:[NSDictionary class]]) return;
        NSString *type = evt[@"type"];
        NSDictionary *content = evt[@"content"];
        if (![content isKindOfClass:[NSDictionary class]]) return;

        if ([type isEqualToString:@"m.room.name"]) {
            NSString *n = content[@"name"];
            if ([n isKindOfClass:[NSString class]] && [n length] > 0 && ![n isEqualToString:room.name]) {
                room.name = n;
                room.hasExplicitName = YES;
                changed = YES;
            }
        } else if ([type isEqualToString:@"m.room.canonical_alias"]) {
            NSString *a = content[@"alias"];
            if ([a isKindOfClass:[NSString class]] && [a length] > 0 && ![a isEqualToString:room.name]) {
                room.name = a;
                room.hasExplicitName = YES;
                changed = YES;
            }
        } else if ([type isEqualToString:@"m.room.avatar"]) {
            NSString *u = content[@"url"];
            if ([u isKindOfClass:[NSString class]] && [u length] > 0 && ![u isEqualToString:room.avatarUrl]) {
                room.avatarUrl = u;
                room.hasExplicitAvatar = YES;
                changed = YES;
            }
        } else if ([type isEqualToString:@"m.room.member"]) {
            NSString *membership = content[@"membership"];
            NSString *uid = evt[@"state_key"];
            if ([membership isEqualToString:@"join"] && [uid isKindOfClass:[NSString class]] &&
                myId && ![uid isEqualToString:myId]) {
                if (!fallbackName) {
                    NSString *dn = content[@"displayname"];
                    fallbackName = ([dn isKindOfClass:[NSString class]] && [dn length] > 0) ? dn : uid;
                }
                if (!fallbackAvatar) {
                    NSString *au = content[@"avatar_url"];
                    if ([au isKindOfClass:[NSString class]] && [au length] > 0) fallbackAvatar = au;
                }
            }
        } else if ([type isEqualToString:@"m.room.message"]) {
            NSDictionary *rel = content[@"m.relates_to"];
            if ([rel isKindOfClass:[NSDictionary class]] && [rel[@"rel_type"] isEqualToString:@"m.replace"]) {
                return;
            }
            NSString *body = content[@"body"];
            if ([body isKindOfClass:[NSString class]] && [body length] > 0 && ![body isEqualToString:room.lastMessage]) {
                room.lastMessage = body;
                id sender = evt[@"sender"];
                room.lastMessageSender = [sender isKindOfClass:[NSString class]] ? sender : @"";
                NSNumber *ts = evt[@"origin_server_ts"];
                if ([ts isKindOfClass:[NSNumber class]]) {
                    room.lastMessageDate = [NSDate dateWithTimeIntervalSince1970:[ts doubleValue] / 1000.0];
                }
                changed = YES;
            }
        }
    };

    NSArray *stateEvents = roomData[@"state"][@"events"];
    if ([stateEvents isKindOfClass:[NSArray class]]) {
        for (NSDictionary *evt in stateEvents) considerEvent(evt);
    }
    NSArray *timelineEvents = roomData[@"timeline"][@"events"];
    if ([timelineEvents isKindOfClass:[NSArray class]]) {
        for (NSDictionary *evt in timelineEvents) considerEvent(evt);
    }

    NSDictionary *summary = roomData[@"summary"];
    if ([summary isKindOfClass:[NSDictionary class]]) {
        int c = [summary[@"m.joined_member_count"] intValue];
        if (c == 0) c = [summary[@"joined_member_count"] intValue];
        if (c > 0 && room.memberCount != c) {
            room.memberCount = c;
            changed = YES;
        }
    }

    if (!room.hasExplicitName && fallbackName && ![fallbackName isEqualToString:room.name]) {
        room.name = fallbackName;
        changed = YES;
    }
    if (!room.hasExplicitAvatar && fallbackAvatar && ![fallbackAvatar isEqualToString:room.avatarUrl]) {
        room.avatarUrl = fallbackAvatar;
        changed = YES;
    }
    return changed;
}

- (void)scheduleCacheSave {
    if (self.spaceFilter != nil) return;
    [_saveCacheTimer invalidate];
    _saveCacheTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                       target:self
                                                     selector:@selector(saveRoomsToCache)
                                                     userInfo:nil
                                                      repeats:NO];
}

- (NSString *)roomCachePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:@"com.neo.roomCache.plist"];
}

- (void)loadRoomsFromCache {
    NSArray *cached = [NSArray arrayWithContentsOfFile:[self roomCachePath]];
    if (![cached isKindOfClass:[NSArray class]]) return;
    for (NSDictionary *d in cached) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        MatrixRoom *room = [[MatrixRoom alloc] init];
        room.roomId = d[@"roomId"] ?: @"";
        room.name = d[@"name"] ?: @"";
        room.memberCount = [d[@"memberCount"] integerValue];
        room.lastMessage = d[@"lastMessage"] ?: @"";
        room.lastMessageSender = d[@"lastMessageSender"] ?: @"";
        double ts = [d[@"lastMessageTs"] doubleValue];
        if (ts > 0) room.lastMessageDate = [NSDate dateWithTimeIntervalSince1970:ts];
        room.avatarUrl = d[@"avatarUrl"] ?: @"";
        room.hasExplicitName = [d[@"hasExplicitName"] boolValue];
        room.hasExplicitAvatar = [d[@"hasExplicitAvatar"] boolValue];
        [self.rooms addObject:room];
        
        if ([room.avatarUrl length] > 0) {
            UIImage *av = [[MatrixAPIClient sharedClient] cachedImageForMXC:room.avatarUrl];
            if (av) [_roomAvatars setObject:av forKey:room.roomId];
        }
    }
    [self applyFilters];
}

- (void)saveRoomsToCache {
    if (self.spaceFilter != nil) return;
    NSMutableArray *cached = [NSMutableArray array];
    for (MatrixRoom *r in self.rooms) {
        [cached addObject:@{
            @"roomId": r.roomId ?: @"",
            @"name": r.name ?: @"",
            @"memberCount": @(r.memberCount),
            @"lastMessage": r.lastMessage ?: @"",
            @"lastMessageSender": r.lastMessageSender ?: @"",
            @"lastMessageTs": r.lastMessageDate ? @([r.lastMessageDate timeIntervalSince1970]) : @0,
            @"avatarUrl": r.avatarUrl ?: @"",
            @"hasExplicitName": @(r.hasExplicitName),
            @"hasExplicitAvatar": @(r.hasExplicitAvatar)
        }];
    }
    [cached writeToFile:[self roomCachePath] atomically:YES];
}

- (void)handleUnreadUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSInteger total = [userInfo[@"total"] integerValue];
    if (total > 0) {
        self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%d", (int)total];
    } else {
        self.tabBarItem.badgeValue = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)handleDemoModeChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)handleThemeChanged {
    ThemeManager *tm = [ThemeManager sharedManager];
    if (self.spaceFilter == nil) {
        [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    } else if (tm.isDarkMode) {
        UIColor *tint = colorForTheme(self.theme);
        CGFloat r, g, b, a;
        [tint getRed:&r green:&g blue:&b alpha:&a];
        tint = [UIColor colorWithRed:r*0.3 green:g*0.3 blue:b*0.3 alpha:1.0];
        if (IS_IOS7_OR_LATER) {
            self.navigationController.navigationBar.barTintColor = tint;
        } else {
            self.navigationController.navigationBar.tintColor = tint;
        }
    } else {
        UIColor *tint = colorForTheme(self.theme);
        if (IS_IOS7_OR_LATER) {
            self.navigationController.navigationBar.barTintColor = tint;
        } else {
            self.navigationController.navigationBar.tintColor = tint;
        }
    }
    if (tm.isDarkMode) {
        if (!IS_IOS7_OR_LATER) self.navigationController.navigationBar.barStyle = [tm barStyle];
        self.tableView.backgroundColor = [tm backgroundColor];
        self.view.backgroundColor = [tm backgroundColor];
    } else if (self.spaceFilter == nil) {
        self.tableView.backgroundColor = [UIColor whiteColor];
        self.view.backgroundColor = [UIColor whiteColor];
    }
    if (tm.isDarkMode) {
        self.searchBar.barStyle = [tm barStyle];
        UIView *header = self.tableView.tableHeaderView;
        header.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    } else if (self.spaceFilter == nil) {
        self.searchBar.barStyle = [tm barStyle];
        UIView *header = self.tableView.tableHeaderView;
        header.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 100 && buttonIndex == 1) {
        NSString *userId = [[alertView textFieldAtIndex:0] text];
        if ([userId length] > 0) {
            MatrixRoom *room = [[MatrixRoom alloc] init];
            room.roomId = userId;
            room.name = userId;
            [self.rooms insertObject:room atIndex:0];
            [self applyFilters];

            ChatViewController *chat = [[ChatViewController alloc] init];
            chat.room = room;
            chat.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:chat animated:YES];
        }
    }
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.filteredRooms count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"RoomCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        ThemeManager *tm_bg = [ThemeManager sharedManager];
        if (tm_bg.isDarkMode) {
            cell.backgroundColor = [tm_bg cellBackgroundColor];
        } else {
            cell.backgroundColor = [UIColor whiteColor];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;

        UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(9, 10, 60, 60)];
        avatarView.tag = 99;
        avatarView.layer.cornerRadius = 30;
        avatarView.clipsToBounds = YES;
        avatarView.contentMode = UIViewContentModeScaleAspectFill;
        avatarView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        [cell.contentView addSubview:avatarView];

        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        nameLabel.tag = 91;
        nameLabel.font = [UIFont boldSystemFontOfSize:16];
        nameLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:nameLabel];

        UILabel *lastMsgLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        lastMsgLabel.tag = 92;
        lastMsgLabel.font = [UIFont systemFontOfSize:14];
        lastMsgLabel.textColor = [UIColor grayColor];
        lastMsgLabel.backgroundColor = [UIColor clearColor];
        lastMsgLabel.numberOfLines = 2;
        lastMsgLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell.contentView addSubview:lastMsgLabel];

        UIView *sep = [[UIView alloc] initWithFrame:CGRectZero];
        sep.tag = 98;
        sep.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        [cell.contentView addSubview:sep];

        UIImageView *badge = [[UIImageView alloc] initWithFrame:CGRectZero];
        badge.tag = 97;
        badge.hidden = YES;
        [cell.contentView addSubview:badge];

        UILabel *tsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        tsLabel.tag = 93;
        tsLabel.font = [UIFont systemFontOfSize:12];
        tsLabel.textAlignment = NSTextAlignmentRight;
        tsLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:tsLabel];

        UIView *unreadDot = [[UIView alloc] initWithFrame:CGRectZero];
        unreadDot.tag = 96;
        unreadDot.layer.cornerRadius = 5;
        unreadDot.hidden = YES;
        [cell.contentView addSubview:unreadDot];
    }

    MatrixRoom *room = nil;
    if (indexPath.row < [self.filteredRooms count]) {
        room = [self.filteredRooms objectAtIndex:indexPath.row];
    }
    if (!room) {
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    CGFloat cellW = cell.contentView.bounds.size.width;
    UIColor *tint = colorForTheme(self.theme);
    NSInteger unread = [[MatrixSyncManager sharedManager] unreadCountForRoom:room.roomId];

    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:91];
    UILabel *lastMsgLabel = (UILabel *)[cell.contentView viewWithTag:92];
    UILabel *tsLabel = (UILabel *)[cell.contentView viewWithTag:93];
    UIView *unreadDot = [cell.contentView viewWithTag:96];

    NSString *tsText = [self relativeDate:room.lastMessageDate];
    CGSize tsSize = [tsText sizeWithFont:[UIFont systemFontOfSize:12]];
    CGFloat tsW = MAX(tsSize.width + 6, 44);
    tsLabel.text = tsText;
    tsLabel.textColor = (unread > 0) ? tint : [UIColor grayColor];
    tsLabel.frame = CGRectMake(cellW - tsW - 22, 14, tsW, 18);

    nameLabel.frame = CGRectMake(78, 12, cellW - 78 - tsW - 24, 22);
    NSString *rawName = [MatrixAPIClient localNameForRoomId:room.roomId] ?: room.name;
    nameLabel.text = [[DemoModeManager sharedManager] obfuscateName:rawName];

    ThemeManager *tm = [ThemeManager sharedManager];
    if (tm.isDarkMode || self.spaceFilter == nil) {
        nameLabel.textColor = [tm primaryTextColor];
        lastMsgLabel.textColor = (unread > 0) ? [tm primaryTextColor] : [tm secondaryTextColor];
        cell.backgroundColor = [tm cellBackgroundColor];
    }

    NSString *subtitleText = @"";
    if ([room.lastMessage length] > 0) {
        subtitleText = room.lastMessage;
    } else if (room.memberCount > 0) {
        subtitleText = [NSString stringWithFormat:NSLocalizedString(@"%d members", nil),
                        (int)room.memberCount];
    }
    lastMsgLabel.text = [[DemoModeManager sharedManager] obfuscateMessage:subtitleText];
    lastMsgLabel.frame = CGRectMake(78, 34, cellW - 78 - 20, 34);

    if (unread > 0) {
        unreadDot.hidden = NO;
        unreadDot.backgroundColor = tint;
        unreadDot.frame = CGRectMake(cellW - 18, 34, 10, 10);
        nameLabel.font = [UIFont boldSystemFontOfSize:16];
    } else {
        unreadDot.hidden = YES;
        nameLabel.font = [UIFont boldSystemFontOfSize:16];
    }

    UIImageView *avatarView = (UIImageView *)[cell.contentView viewWithTag:99];
    UIImage *avatar = [_roomAvatars objectForKey:room.roomId];
    if (avatar) {
        if ([DemoModeManager sharedManager].demoModeEnabled) {
            NSString *cacheKey = [NSString stringWithFormat:@"blur_%@", room.roomId];
            UIImage *blurred = [_roomAvatars objectForKey:cacheKey];
            if (!blurred) {
                blurred = [avatar neo_blurredImageWithFactor:0.06];
                [_roomAvatars setObject:blurred forKey:cacheKey];
            }
            avatarView.image = blurred;
        } else {
            avatarView.image = avatar;
        }
        avatarView.backgroundColor = [UIColor clearColor];
    } else {
        avatarView.image = nil;
        BOOL isDM = [room.roomId hasPrefix:@"@"] || room.memberCount <= 2;
        UIImage *placeholder = nil;
        if (isDM) {
            placeholder = [UIImage imageNamed:@"PersonalChatOS6Large"];
        } else {
            placeholder = [UIImage imageNamed:@"GroupChatOS6Large"];
        }
        if ([DemoModeManager sharedManager].demoModeEnabled && placeholder) {
            NSString *cacheKey = [NSString stringWithFormat:@"blur_ph_%@", room.roomId];
            UIImage *blurred = [_roomAvatars objectForKey:cacheKey];
            if (!blurred) {
                blurred = [placeholder neo_blurredImageWithFactor:0.06];
                [_roomAvatars setObject:blurred forKey:cacheKey];
            }
            avatarView.image = blurred;
        } else {
            avatarView.image = placeholder;
        }
        avatarView.backgroundColor = [UIColor clearColor];
    }

    UIView *sep = (UIView *)[cell.contentView viewWithTag:98];
    sep.frame = CGRectMake(78, 75, cellW - 78, 1.0);

    UIImageView *badge = (UIImageView *)[cell.contentView viewWithTag:97];
    badge.hidden = YES;

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NSLocalizedString(@"Archive", nil);
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        MatrixRoom *room = [self.filteredRooms objectAtIndex:indexPath.row];
        [[ArchiveManager sharedManager] archiveRoomId:room.roomId];
        [self.filteredRooms removeObjectAtIndex:indexPath.row];
        [self.rooms removeObject:room];
        [tableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:UITableViewRowAnimationLeft];
        [self updateSubtitle];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MatrixRoom *room = [self.filteredRooms objectAtIndex:indexPath.row];
    ChatViewController *chat = [[ChatViewController alloc] init];
    chat.room = room;
    chat.hidesBottomBarWhenPushed = YES;
    if ([_roomAvatars objectForKey:room.roomId]) {
        chat.roomAvatar = [_roomAvatars objectForKey:room.roomId];
    }
    [self.navigationController pushViewController:chat animated:YES];
}

- (void)navigateToRoom:(NSString *)roomId {
    for (MatrixRoom *r in self.filteredRooms) {
        if ([r.roomId isEqualToString:roomId]) {
            ChatViewController *chat = [[ChatViewController alloc] init];
            chat.room = r;
            chat.hidesBottomBarWhenPushed = YES;
            if ([_roomAvatars objectForKey:r.roomId]) {
                chat.roomAvatar = [_roomAvatars objectForKey:r.roomId];
            }
            [self.navigationController pushViewController:chat animated:NO];
            return;
        }
    }

    for (MatrixRoom *r in self.rooms) {
        if ([r.roomId isEqualToString:roomId]) {
            [self applyFilters];
            ChatViewController *chat = [[ChatViewController alloc] init];
            chat.room = r;
            chat.hidesBottomBarWhenPushed = YES;
            if ([_roomAvatars objectForKey:r.roomId]) {
                chat.roomAvatar = [_roomAvatars objectForKey:r.roomId];
            }
            [self.navigationController pushViewController:chat animated:NO];
            return;
        }
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NeoOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

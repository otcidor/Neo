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
    NSTimeInterval _lastRoomLoad;
    NSMutableDictionary *_roomAvatars;
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

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    self.rooms = [NSMutableArray array];
    _roomAvatars = [NSMutableDictionary dictionary];

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

    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 36)];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
    titleLabel.text = self.title;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor whiteColor];
    [titleView addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 200, 14)];
    subLabel.tag = 88;
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.font = [UIFont systemFontOfSize:11];
    subLabel.backgroundColor = [UIColor clearColor];
    subLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    [titleView addSubview:subLabel];

    self.navigationItem.titleView = titleView;
    [self updateSubtitle];

    self.filteredRooms = [NSMutableArray array];
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

- (void)updateSubtitle {
    UILabel *sub = (UILabel *)[self.navigationItem.titleView viewWithTag:88];
    if (!sub) return;
    int cnt = (int)[self.filteredRooms count];
    if (cnt == 1) {
        sub.text = NSLocalizedString(@"1 chat", nil);
    } else {
        sub.text = [NSString stringWithFormat:NSLocalizedString(@"%d chats", nil), cnt];
    }
}

- (NSString *)relativeDate:(NSDate *)date {
    if (!date) return @"";
    NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:date];
    if (diff < 60) return NSLocalizedString(@"now", nil);
    if (diff < 3600) return [NSString stringWithFormat:NSLocalizedString(@"%dm", nil), (int)(diff/60)];
    if (diff < 86400) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = NSLocalizedString(@"HH:mm", nil);
        return [fmt stringFromDate:date];
    }
    if (diff < 172800) return NSLocalizedString(@"yesterday", nil);
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = NSLocalizedString(@"dd/MM/yy", nil);
    return [fmt stringFromDate:date];
}

- (void)applyFilters {
    NSString *query = [[self.searchBar.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
        lowercaseString];

    if ([query length] > 0) {
        NSMutableArray *tmp = [NSMutableArray array];
        for (MatrixRoom *r in self.rooms) {
            BOOL nameMatch = [[r.name lowercaseString]
                rangeOfString:query].location != NSNotFound;
            BOOL msgMatch = [[r.lastMessage lowercaseString]
                rangeOfString:query].location != NSNotFound;
            if (nameMatch || msgMatch) [tmp addObject:r];
        }
        self.filteredRooms = tmp;
    } else {
        self.filteredRooms = [NSMutableArray arrayWithArray:self.rooms];
    }

    [self.tableView reloadData];
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
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if ([self.rooms count] == 0 || now - _lastRoomLoad > 60.0) {
        [self loadRooms];
    } else {
        [self applyFilters];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUnreadUpdate:)
                                                 name:MatrixSyncUnreadUpdateNotification
                                               object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MatrixSyncUnreadUpdateNotification object:nil];
}

- (void)handleUnreadUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSInteger total = [userInfo[@"total"] integerValue];
    if (total > 0) {
        self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%d", (int)total];
    } else {
        self.tabBarItem.badgeValue = nil;
    }
    [self.tableView reloadData];
}

- (void)handleDemoModeChanged {
    [self.tableView reloadData];
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
    [self.tableView reloadData];
}

- (void)loadRooms {
    [self.spinner startAnimating];
    [[MatrixAPIClient sharedClient] getJoinedRoomsWithCompletion:^(NSDictionary *response, NSError *error) {
        [self.spinner stopAnimating];
        if (error) {
            if ([error code] == 401) {
                [[MatrixAPIClient sharedClient] clearCredentials];
                LoginViewController *login = [[LoginViewController alloc] init];
                [self.navigationController setViewControllers:@[login] animated:YES];
                return;
            }
            return;
        }

        NSArray *roomIds = response[@"joined_rooms"];
        [self.rooms removeAllObjects];

        for (NSString *roomId in roomIds) {
            MatrixRoom *room = [[MatrixRoom alloc] initWithDictionary:@{@"room_id": roomId}];
            [self.rooms addObject:room];
        }

        _lastRoomLoad = [[NSDate date] timeIntervalSince1970];

        [[MatrixAPIClient sharedClient] syncWithSince:nil timeout:30000 completion:^(NSDictionary *syncResp, NSError *syncErr) {
            if (syncResp) {
                [[SpaceManager sharedManager] buildSpaceMapFromSyncResponse:syncResp];

                NSDictionary *join = syncResp[@"rooms"][@"join"];
                [join enumerateKeysAndObjectsUsingBlock:^(NSString *roomId, NSDictionary *roomData, BOOL *stop) {
                    NSString *displayName = [MatrixRoom displayNameForRoomId:roomId fromSyncData:roomData];
                    NSDictionary *summary = roomData[@"summary"];
                    int count = [summary[@"m.joined_member_count"] intValue] ?: [summary[@"joined_member_count"] intValue];

                    NSString *avatarUrl = nil;
                    BOOL isDM = (count <= 2);
                    NSArray *stateEvents = roomData[@"state"][@"events"];
                    for (NSDictionary *evt in stateEvents) {
                        NSString *type = evt[@"type"];
                        if ([type isEqualToString:@"m.room.avatar"]) {
                            NSString *roomAvatar = evt[@"content"][@"url"];
                            if ([roomAvatar length] > 0) {
                                avatarUrl = roomAvatar;
                                break;
                            }
                        }
                        if (isDM && [type isEqualToString:@"m.room.member"]) {
                            NSString *userId = evt[@"state_key"];
                            NSString *myId = [[MatrixAPIClient sharedClient] userId];
                            if (![userId isEqualToString:myId]) {
                                NSString *memberAvatar = evt[@"content"][@"avatar_url"];
                                if ([memberAvatar length] > 0) {
                                    avatarUrl = memberAvatar;
                                }
                            }
                        }
                    }
                    // Fallback: member cache from API /members
                    if (!avatarUrl && isDM) {
                        NSDictionary *members = [[MatrixAPIClient sharedClient] cachedMembersForRoom:roomId];
                        NSString *myId = [[MatrixAPIClient sharedClient] userId];
                        for (NSString *uid in members) {
                            if (![uid isEqualToString:myId]) {
                                NSString *mAvatar = members[uid][@"avatar_url"];
                                if ([mAvatar length] > 0) {
                                    avatarUrl = mAvatar;
                                }
                                break;
                            }
                        }
                    }

                    NSString *lastMsgText = nil;
                    NSString *lastMsgTs = nil;
                    NSString *lastMsgSender = nil;
                    NSArray *timelineEvents = roomData[@"timeline"][@"events"];
                    if ([timelineEvents isKindOfClass:[NSArray class]]) {
                        for (NSDictionary *tev in [timelineEvents reverseObjectEnumerator]) {
                            if ([tev[@"type"] isEqualToString:@"m.room.message"]) {
                                lastMsgText = tev[@"content"][@"body"];
                                lastMsgTs = tev[@"origin_server_ts"];
                                lastMsgSender = tev[@"sender"];
                                break;
                            }
                        }
                    }

                    for (MatrixRoom *r in self.rooms) {
                        if ([r.roomId isEqualToString:roomId]) {
                            r.name = displayName;
                            r.memberCount = count;
                            r.lastMessage = lastMsgText;
                            r.lastMessageSender = lastMsgSender;
                            if (lastMsgTs) {
                                double ts = [lastMsgTs doubleValue] / 1000.0;
                                r.lastMessageDate = [NSDate dateWithTimeIntervalSince1970:ts];
                            }
                            NSDictionary *unread = roomData[@"unread_notifications"];
                            if (unread) {
                                r.unreadCount = [unread[@"notification_count"] integerValue];
                            }
                            break;
                        }
                    }

                    if (avatarUrl) {
                        [[MatrixAPIClient sharedClient] downloadImageFromMXC:avatarUrl completion:^(UIImage *image, NSError *dlErr) {
                            if (image) {
                                [_roomAvatars setObject:image forKey:roomId];
                                [self.tableView reloadData];
                            }
                        }];
                    }
                }];

                if ([self.spaceFilter length] > 0) {
                    NSMutableArray *filtered = [NSMutableArray array];
                    for (MatrixRoom *r in self.rooms) {
                        NSString *bridge = [[SpaceManager sharedManager] bridgeTypeForRoomId:r.roomId];
                        if (bridge && [bridge rangeOfString:self.spaceFilter
                                                     options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            [filtered addObject:r];
                        }
                    }
                    self.rooms = filtered;
                    NSLog(@"[Filter] '%@' → %d rooms", self.spaceFilter, (int)[self.rooms count]);
                }

                // Filter archived
                NSMutableArray *notArchived = [NSMutableArray array];
                for (MatrixRoom *r in self.rooms) {
                    if (![[ArchiveManager sharedManager] isArchivedRoomId:r.roomId]) {
                        [notArchived addObject:r];
                    }
                }
                self.rooms = notArchived;

                // Sort by last message, newest first
                [self.rooms sortUsingComparator:^NSComparisonResult(MatrixRoom *r1, MatrixRoom *r2) {
                    NSDate *d1 = r1.lastMessageDate;
                    NSDate *d2 = r2.lastMessageDate;
                    if (!d1 && !d2) return NSOrderedSame;
                    if (!d1) return NSOrderedAscending;
                    if (!d2) return NSOrderedDescending;
                    return [d2 compare:d1];
                }];

                [self applyFilters];
            }
        }];
    }];
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
    return 76;
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

        UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 56, 56)];
        avatarView.tag = 99;
        avatarView.layer.cornerRadius = 28;
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
        lastMsgLabel.font = [UIFont systemFontOfSize:13];
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

    MatrixRoom *room = [self.filteredRooms objectAtIndex:indexPath.row];
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
    tsLabel.frame = CGRectMake(cellW - tsW - 24, 12, tsW, 18);

    nameLabel.frame = CGRectMake(78, 12, cellW - 78 - tsW - 28, 22);
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
        if (room.memberCount > 2 && [room.lastMessageSender length] > 0) {
            NSString *senderShort = room.lastMessageSender;
            NSRange colon = [senderShort rangeOfString:@":"];
            if (colon.location != NSNotFound)
                senderShort = [senderShort substringToIndex:colon.location];
            if ([senderShort hasPrefix:@"@"])
                senderShort = [senderShort substringFromIndex:1];
            subtitleText = [NSString stringWithFormat:@"%@: %@",
                            senderShort, room.lastMessage];
        } else {
            subtitleText = room.lastMessage;
        }
    } else if (room.memberCount > 0) {
        subtitleText = [NSString stringWithFormat:NSLocalizedString(@"%d members", nil),
                        (int)room.memberCount];
    }
    lastMsgLabel.text = [[DemoModeManager sharedManager] obfuscateMessage:subtitleText];
    lastMsgLabel.frame = CGRectMake(78, 34, cellW - 78 - 20, 36);

    if (unread > 0) {
        unreadDot.hidden = NO;
        unreadDot.backgroundColor = tint;
        unreadDot.frame = CGRectMake(cellW - 16, 34, 10, 10);
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

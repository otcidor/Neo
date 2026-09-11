#import "NeoCompatibility.h"
#import "ProfileViewController.h"
#import "MatrixAPIClient.h"
#import "ThemeManager.h"
#import <QuartzCore/QuartzCore.h>
#import "DemoModeManager.h"
#import "UIImage+NeoBlur.h"

@implementation ProfileViewController {
    UITableView *_tableView;
    UIImageView *_avatarView;
    UILabel *_nameLabel;
    UILabel *_subLabel;
    NSString *_otherUserId;
}

- (void)loadView {
    [super loadView];
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 200)];
    headerView.tag = 1001;
    headerView.backgroundColor = [tm backgroundColor];

    CGFloat avatarSize = 100;
    _avatarView = [[UIImageView alloc] initWithFrame:
        CGRectMake((w - avatarSize) / 2, 30, avatarSize, avatarSize)];
    _avatarView.layer.cornerRadius = avatarSize / 2;
    _avatarView.clipsToBounds = YES;
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarView.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1.0];

    UIImage *placeholder = [UIImage imageNamed:@"PersonalChatOS6Large"];
    if (!placeholder) placeholder = [UIImage imageNamed:@"GroupChatOS6Large"];
    _avatarView.image = placeholder;

    if (self.roomAvatar) {
        _avatarView.image = self.roomAvatar;
    }
    [headerView addSubview:_avatarView];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 140, w - 16, 28)];
    NSString *localName = [MatrixAPIClient localNameForRoomId:self.room.roomId];
    _nameLabel.text = [[DemoModeManager sharedManager] obfuscateName:localName ?: (self.room.name ?: self.room.roomId)];
    _nameLabel.font = [UIFont boldSystemFontOfSize:20];
    _nameLabel.textColor = [tm primaryTextColor];
    _nameLabel.textAlignment = NSTextAlignmentCenter;
    _nameLabel.backgroundColor = [UIColor clearColor];
    [headerView addSubview:_nameLabel];

    _subLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 168, w - 16, 18)];
    if (self.room.memberCount > 2) {
        _subLabel.text = [NSString stringWithFormat:@"%d miembros", (int)self.room.memberCount];
    } else {
        NSString *sub = self.room.roomId;
        NSRange colon = [sub rangeOfString:@":"];
        if (colon.location != NSNotFound)
            sub = [sub substringToIndex:colon.location];
        if ([sub hasPrefix:@"!"]) sub = [sub substringFromIndex:1];
        _subLabel.text = sub;
    }
    _subLabel.font = [UIFont systemFontOfSize:13];
    _subLabel.textColor = [tm secondaryTextColor];
    _subLabel.textAlignment = NSTextAlignmentCenter;
    _subLabel.backgroundColor = [UIColor clearColor];
    [headerView addSubview:_subLabel];

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 200, w, h - 200)
                                              style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = [tm backgroundColor];
    _tableView.backgroundView = nil;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];

    [self.view addSubview:headerView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Profile", nil);

    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }

    [self applyTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDemoModeChanged)
                                                 name:NeoDemoModeDidChangeNotification
                                               object:nil];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedString(@"Back", nil)
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(backTapped)];

    if (!self.roomAvatar && self.room.roomId) {
        UIImage *cached = [[MatrixAPIClient sharedClient].avatarCache
            objectForKey:self.room.roomId];
        if (cached) {
            _avatarView.image = cached;
        }
    }

    // For DMs, find the other user
    if (self.room.memberCount <= 2) {
        NSDictionary *members = [[MatrixAPIClient sharedClient]
            cachedMembersForRoom:self.room.roomId];
        NSString *myId = [[MatrixAPIClient sharedClient] userId];
        for (NSString *userId in members) {
            if (![userId isEqualToString:myId]) {
                _otherUserId = userId;
                _subLabel.text = userId;
                if (!self.roomAvatar) {
                    NSDictionary *memberInfo = members[userId];
                    NSString *avatarMxc = memberInfo[@"avatar_url"];
                    if ([avatarMxc length] > 0) {
                        [[MatrixAPIClient sharedClient] downloadImageFromMXC:avatarMxc
                            completion:^(UIImage *img, NSError *err) {
                            if (img) {
                                _avatarView.image = img;
                            }
                        }];
                    }
                }
                break;
            }
        }
    }

    if ([DemoModeManager sharedManager].demoModeEnabled && _avatarView.image) {
        UIImage *blurred = [_avatarView.image neo_blurredImageWithFactor:0.06];
        _avatarView.image = blurred;
    }
}

- (void)handleDemoModeChanged {
    NSString *rawName = [MatrixAPIClient localNameForRoomId:self.room.roomId] ?: (self.room.name ?: self.room.roomId);
    _nameLabel.text = [[DemoModeManager sharedManager] obfuscateName:rawName];
    if ([DemoModeManager sharedManager].demoModeEnabled) {
        // re-fetch original image from cache and re-blur
        UIImage *original = self.roomAvatar;
        if (!original && self.room.roomId) {
            original = [[MatrixAPIClient sharedClient].avatarCache objectForKey:self.room.roomId];
        }
        if (!original) {
            original = [UIImage imageNamed:@"PersonalChatOS6Large"];
        }
        _avatarView.image = [original neo_blurredImageWithFactor:0.06];
    } else {
        UIImage *original = self.roomAvatar;
        if (!original && self.room.roomId) {
            original = [[MatrixAPIClient sharedClient].avatarCache objectForKey:self.room.roomId];
        }
        _avatarView.image = original ?: [UIImage imageNamed:@"PersonalChatOS6Large"];
    }
    [_tableView reloadData];
}

- (void)applyTheme {
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];
    _tableView.backgroundColor = [tm backgroundColor];
    _tableView.backgroundView = nil;
    UIView *header = [self.view viewWithTag:1001];
    if (header) {
        header.backgroundColor = [tm backgroundColor];
    }
    _nameLabel.textColor = [tm primaryTextColor];
    _subLabel.textColor = [tm secondaryTextColor];
    [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    if (!IS_IOS7_OR_LATER && !tm.isDarkGlass) self.navigationController.navigationBar.barStyle = [tm barStyle];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)backTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return NSLocalizedString(@"Info", nil);
        case 1: return NSLocalizedString(@"Moderation", nil);
        default: return nil;
    }
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
    return 10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    ThemeManager *tm = [ThemeManager sharedManager];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 10.0f)];
    v.backgroundColor = [tm backgroundColor];
    return v;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;
        case 1: return 2;
        default: return 0;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ProfileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellId];
    }
    ThemeManager *tm_cell = [ThemeManager sharedManager];
    CGFloat cellW = tableView.bounds.size.width;

    cell.backgroundColor = [tm_cell cellBackgroundColor];
    cell.textLabel.textColor = [tm_cell primaryTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.detailTextLabel.textColor = [tm_cell secondaryTextColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
    cell.detailTextLabel.text = nil;

    if (tm_cell.isDarkGlass) {
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.28 alpha:1.0];
        cell.selectedBackgroundView = selBg;
    } else {
        cell.selectedBackgroundView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"user"];
            NSString *displayId = _otherUserId ?: self.room.roomId;
            if ([DemoModeManager sharedManager].demoModeEnabled) {
                displayId = @"@demo:example.org";
            }
            cell.textLabel.text = displayId;
            cell.textLabel.font = [UIFont systemFontOfSize:14];
            cell.textLabel.textColor = [tm_cell secondaryTextColor];
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"rename"];
            cell.textLabel.text = NSLocalizedString(@"Rename", nil);
            if (tm_cell.isDarkGlass) {
                cell.accessoryView = [ThemeManager modernDisclosureIndicator];
            } else {
                cell.accessoryView = nil;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"mute"];
            cell.textLabel.text = NSLocalizedString(@"Mute notifications", nil);
            UISwitch *toggle = [cell.accessoryView isKindOfClass:[UISwitch class]] ? (UISwitch *)cell.accessoryView : nil;
            if (!toggle) {
                toggle = [[UISwitch alloc] init];
                toggle.on = NO;
                cell.accessoryView = toggle;
            }
            if ([toggle respondsToSelector:@selector(setOnTintColor:)]) {
                toggle.onTintColor = [UIColor colorWithRed:0.20 green:0.52 blue:0.98 alpha:1.0];
            }
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.imageView.image = [ThemeManager settingsIconNamed:@"delete"];
            cell.textLabel.text = NSLocalizedString(@"Delete chat", nil);
            cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
            if (tm_cell.isDarkGlass) {
                cell.accessoryView = [ThemeManager modernDisclosureIndicator];
            } else {
                cell.accessoryView = nil;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        }
    }

    NSInteger totalRows = [self tableView:tableView numberOfRowsInSection:indexPath.section];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 1) {
        NSString *currentName = [MatrixAPIClient localNameForRoomId:self.room.roomId]
            ?: (self.room.name ?: self.room.roomId);
        UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"Rename", nil)
                  message:NSLocalizedString(@"Local name (does not affect server)", nil)
                 delegate:self
        cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
        otherButtonTitles:NSLocalizedString(@"Save", nil), nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        [[alert textFieldAtIndex:0] setText:currentName];
        alert.tag = 50;
        [alert show];
    }
    if (indexPath.section == 1 && indexPath.row == 1) {
        UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"Delete chat", nil)
                  message:NSLocalizedString(@"Delete this chat? This cannot be undone.", nil)
                 delegate:self
        cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
        otherButtonTitles:NSLocalizedString(@"Delete", nil), nil];
        [alert show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) return;
    if (alertView.tag == 50) {
        NSString *newName = [[alertView textFieldAtIndex:0] text];
        if ([newName length] > 0) {
            [MatrixAPIClient setLocalName:newName forRoomId:self.room.roomId];
            _nameLabel.text = newName;
            [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

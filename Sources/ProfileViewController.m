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
    headerView.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];

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
    _nameLabel.textColor = [UIColor whiteColor];
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
    _subLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    _subLabel.textAlignment = NSTextAlignmentCenter;
    _subLabel.backgroundColor = [UIColor clearColor];
    [headerView addSubview:_subLabel];

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 200, w, h - 200)
                                              style:UITableViewStyleGrouped];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = [tm backgroundColor];
    _tableView.backgroundView = nil;
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
    _tableView.separatorColor = [tm separatorColor];
    [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
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
    cell.backgroundColor = [tm_cell cellBackgroundColor];
    cell.textLabel.textColor = [tm_cell primaryTextColor];
    cell.imageView.image = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            NSString *displayId = _otherUserId ?: self.room.roomId;
            if ([DemoModeManager sharedManager].demoModeEnabled) {
                displayId = @"@demo:example.org";
            }
            cell.textLabel.text = displayId;
            cell.textLabel.font = [UIFont systemFontOfSize:13];
            cell.textLabel.textColor = [tm_cell secondaryTextColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = NSLocalizedString(@"Rename", nil);
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.textLabel.textColor = [tm_cell primaryTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Mute notifications", nil);
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = NO;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = NSLocalizedString(@"Delete chat", nil);
            cell.textLabel.textColor = [UIColor redColor];
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
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

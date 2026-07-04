#import "NeoCompatibility.h"
#import "ProfileViewController.h"
#import "MatrixAPIClient.h"
#import <QuartzCore/QuartzCore.h>

@implementation ProfileViewController {
    UITableView *_tableView;
    UIImageView *_avatarView;
    UILabel *_nameLabel;
    UILabel *_subLabel;
    NSString *_otherUserId;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];

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
    _nameLabel.text = localName ?: (self.room.name ?: self.room.roomId);
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
    _tableView.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    [self.view addSubview:_tableView];

    [self.view addSubview:headerView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Perfil";

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Atrás"
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

    // Para DMs, encontrar el otro usuario
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
        case 0: return @"Información";
        case 1: return @"Moderación";
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
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.imageView.image = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            if (_otherUserId) {
                cell.textLabel.text = _otherUserId;
            } else {
                cell.textLabel.text = self.room.roomId;
            }
            cell.textLabel.font = [UIFont systemFontOfSize:13];
            cell.textLabel.textColor = [UIColor grayColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Cambiar nombre";
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.textLabel.textColor = [UIColor darkTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Silenciar notificaciones";
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = NO;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Eliminar chat";
            cell.textLabel.textColor = [UIColor redColor];
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 1) {
        NSString *currentName = [MatrixAPIClient localNameForRoomId:self.room.roomId]
            ?: (self.room.name ?: self.room.roomId);
        UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:@"Cambiar nombre"
                  message:@"Nombre local (no afecta al servidor)"
                 delegate:self
        cancelButtonTitle:@"Cancelar"
        otherButtonTitles:@"Guardar", nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        [[alert textFieldAtIndex:0] setText:currentName];
        alert.tag = 50;
        [alert show];
    }
    if (indexPath.section == 1 && indexPath.row == 1) {
        UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:@"Eliminar chat"
                  message:@"¿Eliminar este chat? No se puede deshacer."
                 delegate:self
        cancelButtonTitle:@"Cancelar"
        otherButtonTitles:@"Eliminar", nil];
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

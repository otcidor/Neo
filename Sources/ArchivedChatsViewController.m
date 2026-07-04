#import "NeoCompatibility.h"
#import "ArchivedChatsViewController.h"
#import "ArchiveManager.h"
#import "MatrixAPIClient.h"
#import "MatrixModels.h"
#import "ChatViewController.h"
#import <QuartzCore/QuartzCore.h>

@implementation ArchivedChatsViewController {
    UITableView *_tableView;
    NSMutableArray *_archivedRooms;
    NSMutableDictionary *_avatarCache;
}

- (void)loadView {
    [super loadView];
    self.title = NSLocalizedString(@"Archived", nil);
    self.view.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h)
                                              style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    UIImage *bgPattern = [UIImage imageNamed:@"tableViewBackground"];
    if (bgPattern) {
        _tableView.backgroundColor = [UIColor colorWithPatternImage:bgPattern];
    }
    [self.view addSubview:_tableView];

    _avatarCache = [NSMutableDictionary dictionary];
    _archivedRooms = [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadArchivedRooms];
}

- (void)loadArchivedRooms {
    [_archivedRooms removeAllObjects];
    NSArray *archivedIds = [[ArchiveManager sharedManager] archivedRoomIds];

    for (NSString *roomId in archivedIds) {
        MatrixRoom *room = [[MatrixRoom alloc] init];
        room.roomId = roomId;
        room.name = roomId;
        [_archivedRooms addObject:room];
    }

    [[MatrixAPIClient sharedClient] syncWithSince:nil
                                          timeout:0
                                       completion:^(NSDictionary *syncResp, NSError *err) {
        if (!syncResp) {
            [_tableView reloadData];
            return;
        }
        NSDictionary *join = syncResp[@"rooms"][@"join"];
        for (MatrixRoom *r in _archivedRooms) {
            NSDictionary *roomData = join[r.roomId];
            if (!roomData) continue;
            NSString *name = [MatrixRoom displayNameForRoomId:r.roomId
                                                 fromSyncData:roomData];
            if ([name length] > 0) r.name = name;

            NSArray *stateEvents = roomData[@"state"][@"events"];
            NSString *avatarUrl = nil;
            for (NSDictionary *evt in stateEvents) {
                if ([evt[@"type"] isEqualToString:@"m.room.avatar"]) {
                    avatarUrl = evt[@"content"][@"url"];
                    break;
                }
            }
            if (avatarUrl) {
                [[MatrixAPIClient sharedClient] downloadImageFromMXC:avatarUrl
                    completion:^(UIImage *img, NSError *dlErr) {
                    if (img) {
                        [_avatarCache setObject:img forKey:r.roomId];
                        [_tableView reloadData];
                    }
                }];
            }
        }
        [_tableView reloadData];
    }];

    [_tableView reloadData];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_archivedRooms count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ArchivedCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.backgroundColor = [UIColor whiteColor];

        UIImageView *avatarView = [[UIImageView alloc]
            initWithFrame:CGRectMake(8, 6, 48, 48)];
        avatarView.tag = 99;
        avatarView.layer.cornerRadius = 24;
        avatarView.clipsToBounds = YES;
        avatarView.contentMode = UIViewContentModeScaleAspectFill;
        avatarView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        [cell.contentView addSubview:avatarView];

        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        nameLabel.tag = 91;
        nameLabel.font = [UIFont boldSystemFontOfSize:16];
        nameLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:nameLabel];

        UILabel *sep = [[UILabel alloc] initWithFrame:CGRectZero];
        sep.tag = 98;
        sep.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
        [cell.contentView addSubview:sep];
    }

    MatrixRoom *room = [_archivedRooms objectAtIndex:indexPath.row];
    CGFloat cellW = cell.contentView.bounds.size.width;

    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:91];
    nameLabel.frame = CGRectMake(64, 18, cellW - 84, 22);
    nameLabel.text = room.name;

    UIImageView *avatarView = (UIImageView *)[cell.contentView viewWithTag:99];
    UIImage *avatar = [_avatarCache objectForKey:room.roomId];
    avatarView.image = avatar ?: [UIImage imageNamed:@"PersonalChatOS6Large"];

    UILabel *sep = (UILabel *)[cell.contentView viewWithTag:98];
    sep.frame = CGRectMake(64, 59, cellW - 64, 0.5);

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Desarchivar";
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        MatrixRoom *room = [_archivedRooms objectAtIndex:indexPath.row];
        [[ArchiveManager sharedManager] unarchiveRoomId:room.roomId];
        [_archivedRooms removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:UITableViewRowAnimationLeft];
    }
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MatrixRoom *room = [_archivedRooms objectAtIndex:indexPath.row];
    ChatViewController *chat = [[ChatViewController alloc] init];
    chat.room = room;
    [self.navigationController pushViewController:chat animated:YES];
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

#import "NeoAlert.h"
#import "NeoCompatibility.h"
#import "ChatViewController.h"
#import "MatrixAPIClient.h"
#import "ProfileViewController.h"
#import "MatrixBubbleMessageCell.h"
#import "MatrixSyncManager.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "AudioMessageView.h"
#import "VideoMessageView.h"
#import <MediaPlayer/MediaPlayer.h>

@interface ChatViewController () <UIActionSheetDelegate, UIAlertViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@end

@implementation ChatViewController {
    NSDictionary *_memberNames;
    NSTimeInterval _lastMessageLoad;
    BOOL _longPressAdded;
    NSInteger _selectedRow;
    BOOL _selectedIsSelf;
    BOOL _syncActive;
    NSMutableArray *_displayItems;
    BOOL _shouldAutoScroll;
    AVAudioRecorder *_audioRecorder;
    NSTimer *_recordingTimer;
    UILabel *_recordingLabel;
    BOOL _sendButtonIsMicMode;
}

- (void)loadView {
    [super loadView];
    self.title = [MatrixAPIClient localNameForRoomId:self.room.roomId] ?: (self.room.name ?: self.room.roomId);

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat inputH = 44;
    CGFloat tableH = h - inputH;

    UIImageView *wallpaper = [[UIImageView alloc] initWithFrame:self.view.bounds];
    NSString *wpName = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_wallpaper"] ?: @"wallpaper_61";
    wallpaper.image = [UIImage imageNamed:wpName];
    wallpaper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    wallpaper.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview:wallpaper];


    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, tableH)
                                                  style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];

    UIView *inputView = [[UIView alloc] initWithFrame:CGRectMake(0, tableH, w, inputH)];
    inputView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:inputView];

    UIImageView *inputBg = [[UIImageView alloc] initWithFrame:inputView.bounds];
    inputBg.image = [[UIImage imageNamed:@"input-bar"] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
    inputBg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [inputView addSubview:inputBg];

    self.messageField = [[UITextField alloc] initWithFrame:CGRectMake(46, 6, w - 96, 32)];
    self.messageField.placeholder = @"Type a message...";
    self.messageField.borderStyle = UITextBorderStyleNone;
    self.messageField.font = [UIFont systemFontOfSize:15];
    self.messageField.delegate = self;
    self.messageField.returnKeyType = UIReturnKeySend;
    self.messageField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.messageField.backgroundColor = [UIColor clearColor];
    self.messageField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 0)];
    self.messageField.leftView = paddingView;
    self.messageField.leftViewMode = UITextFieldViewModeAlways;
    UIImage *fieldImg = [UIImage imageNamed:@"input-field"];
    if (fieldImg) {
        self.messageField.background = [fieldImg stretchableImageWithLeftCapWidth:12 topCapHeight:12];
    }
    [inputView addSubview:self.messageField];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.frame = CGRectMake(w - 40, 5, 34, 34);
    [self.sendButton setImage:[UIImage imageNamed:@"send"] forState:UIControlStateNormal];
    [self.sendButton setImage:[UIImage imageNamed:@"send-highlighted"] forState:UIControlStateHighlighted];
    [self.sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [inputView addSubview:self.sendButton];

    UIButton *cameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cameraBtn.tag = 93;
    cameraBtn.frame = CGRectMake(8, 5, 34, 34);
    [cameraBtn setImage:[UIImage imageNamed:@"PhotoButton"] forState:UIControlStateNormal];
    [cameraBtn setImage:[UIImage imageNamed:@"PhotoButtonPressed"] forState:UIControlStateHighlighted];
    [cameraBtn addTarget:self action:@selector(cameraTapped) forControlEvents:UIControlEventTouchUpInside];
    cameraBtn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [inputView addSubview:cameraBtn];

    _sendButtonIsMicMode = NO;
    [self updateSendButtonAppearance];

    self.messages = [NSMutableArray array];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(w / 2, 60);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    _lastMessageLoad = 0;
    _displayItems = [NSMutableArray array];
    _shouldAutoScroll = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavBar];
    [self loadMemberNames];
    [self loadMessages];
    NSString *lastEventId = nil;
    for (MatrixMessage *m in [self.messages reverseObjectEnumerator]) {
        if (m.eventId) { lastEventId = m.eventId; break; }
    }
    [[MatrixSyncManager sharedManager] markRoomRead:self.room.roomId lastEventId:lastEventId];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    [self addSyncObservers];

    if (!_longPressAdded) {
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleLongPress:)];
        lp.minimumPressDuration = 0.5;
        lp.cancelsTouchesInView = YES;
        [self.tableView addGestureRecognizer:lp];
        _longPressAdded = YES;
    }

    if (!_syncActive && ![[MatrixSyncManager sharedManager] isSyncing]) {
        _syncActive = YES;
        MatrixAPIClient *client = [MatrixAPIClient sharedClient];
        [client syncWithSince:nil timeout:0 completion:^(NSDictionary *response, NSError *error) {
            if (response[@"next_batch"]) {
                client.nextBatchToken = response[@"next_batch"];
            }
            [self startSyncLoop];
        }];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:point];
    if (!ip) return;

    id item = [_displayItems objectAtIndex:ip.row];
    if (![item isKindOfClass:[MatrixMessage class]]) return;
    MatrixMessage *msg = (MatrixMessage *)item;
    NSInteger msgRow = [self.messages indexOfObject:msg];
    if (msgRow == NSNotFound) return;
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    _selectedIsSelf = (myId && [msg.sender isEqualToString:myId]);
    _selectedRow = msgRow;

    UIActionSheet *sheet;
    if (_selectedIsSelf) {
        sheet = [[UIActionSheet alloc]
            initWithTitle:nil
                 delegate:self
        cancelButtonTitle:@"Cancelar"
   destructiveButtonTitle:nil
        otherButtonTitles:@"👍", @"❤️", @"😂", @"😮", @"Custom…", @"Copiar", @"Editar", @"Eliminar", nil];
        sheet.tag = 200;
    } else {
        sheet = [[UIActionSheet alloc]
            initWithTitle:nil
                 delegate:self
        cancelButtonTitle:@"Cancelar"
   destructiveButtonTitle:nil
        otherButtonTitles:@"👍", @"❤️", @"😂", @"😮", @"Custom…", @"Copiar", nil];
        sheet.tag = 500;
    }
    [sheet showInView:self.view];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [self removeSyncObservers];
    _syncActive = NO;
}

- (void)addSyncObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSyncNewMessage:)
                                                 name:MatrixSyncNewMessageNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSyncUnreadUpdate:)
                                                 name:MatrixSyncUnreadUpdateNotification
                                               object:nil];
}

- (void)removeSyncObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MatrixSyncNewMessageNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MatrixSyncUnreadUpdateNotification object:nil];
}

- (void)handleSyncNewMessage:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSString *roomId = userInfo[@"room_id"];
    if (![roomId isEqualToString:self.room.roomId]) return;

    NSDictionary *evt = userInfo[@"event"];
    if (!evt) return;

    NSString *type = evt[@"type"];
    if (![type isEqualToString:@"m.room.message"]) return;

    NSDictionary *relatesTo = evt[@"content"][@"m.relates_to"];
    if ([relatesTo[@"rel_type"] isEqualToString:@"m.replace"]) return;

    BOOL exists = NO;
    for (MatrixMessage *existing in self.messages) {
        if ([existing.eventId isEqualToString:evt[@"event_id"]]) { exists = YES; break; }
    }
    if (exists) return;

    MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:evt roomId:self.room.roomId];
    [self.messages addObject:msg];
    [self buildDisplayItems];
    [self.tableView reloadData];

    CGFloat nearBottom = self.tableView.contentSize.height - self.tableView.contentOffset.y - self.tableView.bounds.size.height;
    CGFloat threshold = 60.0;
    if (nearBottom < threshold) {
        [self scrollToBottom];
    }
}

- (void)handleSyncUnreadUpdate:(NSNotification *)notification {
    // ChatViewController doesn't need badge — RoomListViewController handles it
}

- (void)setupNavBar {
    CGFloat titleW = 220;

    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, titleW, 40)];

    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, titleW, 20)];
    nameLabel.text = [MatrixAPIClient localNameForRoomId:self.room.roomId] ?: (self.room.name ?: self.room.roomId);
    nameLabel.font = [UIFont boldSystemFontOfSize:16];
    nameLabel.textColor = [UIColor whiteColor];
    nameLabel.backgroundColor = [UIColor clearColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    [titleView addSubview:nameLabel];

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, titleW, 14)];
    if (self.room.memberCount > 0) {
        subLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d members", nil), (int)self.room.memberCount];
    } else {
        subLabel.text = @"";
    }
    subLabel.font = [UIFont systemFontOfSize:11];
    subLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    subLabel.backgroundColor = [UIColor clearColor];
    subLabel.textAlignment = NSTextAlignmentCenter;
    [titleView addSubview:subLabel];

    UITapGestureRecognizer *titleTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(profileTapped)];
    [titleView addGestureRecognizer:titleTap];
    self.navigationItem.titleView = titleView;

    CGFloat avatarSize = 32;
    UIImageView *avatarImg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, avatarSize, avatarSize)];
    avatarImg.layer.cornerRadius = avatarSize / 2;
    avatarImg.clipsToBounds = YES;
    avatarImg.contentMode = UIViewContentModeScaleAspectFill;
    avatarImg.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    if (self.roomAvatar) {
        avatarImg.image = self.roomAvatar;
    } else {
        BOOL isDM = (self.room.memberCount <= 2);
        avatarImg.image = [UIImage imageNamed:isDM ? @"PersonalChatOS6Large" : @"GroupChatOS6Large"];
    }

    UIView *avatarContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, avatarSize + 8, avatarSize + 8)];
    avatarContainer.frame = CGRectOffset(avatarContainer.frame, 0, -4);
    avatarImg.center = CGPointMake(avatarContainer.frame.size.width / 2, avatarContainer.frame.size.height / 2);
    [avatarContainer addSubview:avatarImg];

    UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(profileTapped)];
    [avatarContainer addGestureRecognizer:avatarTap];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:avatarContainer];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) return;

    if (alertView.tag == 777) {
        NSString *mxcURL = objc_getAssociatedObject(alertView, "saveMXC");
        if (mxcURL) [self saveVideoToPhotosForMXC:mxcURL];
        return;
    }

    if (alertView.tag == 900) {
        MatrixMessage *msg = objc_getAssociatedObject(alertView, "reactionMsg");
        if (!msg) return;
        NSString *emoji = [[alertView textFieldAtIndex:0] text];
        if ([emoji length] == 0) return;
        if ([emoji length] > 2) emoji = [emoji substringToIndex:2];
        [self sendReaction:emoji toMessage:msg];
        return;
    }

    // Edit dialog (tag 300-499)
    if (alertView.tag >= 300 && alertView.tag < 500) {
        NSInteger row = alertView.tag - 300;
        if (row >= [self.messages count]) return;
        MatrixMessage *msg = [self.messages objectAtIndex:row];
        NSString *newBody = [[alertView textFieldAtIndex:0] text];
        if ([newBody length] == 0) return;
        [[MatrixAPIClient sharedClient] editMessage:newBody
                                             roomId:self.room.roomId
                                            eventId:msg.eventId
                                         completion:^(NSDictionary *resp, NSError *err) {
            if (!err) {
                msg.body = newBody;
                [self buildDisplayItems];
                [self.tableView reloadData];
            }
        }];
    }
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSInteger cancelIdx = [sheet cancelButtonIndex];
    if (buttonIndex == cancelIdx) return;

    if (_selectedRow >= [self.messages count]) return;
    MatrixMessage *msg = [self.messages objectAtIndex:_selectedRow];

    NSArray *emojis = @[@"👍", @"❤️", @"😂", @"😮"];

    if (sheet.tag == 500) {
        if (buttonIndex < [emojis count]) {
            [self sendReaction:emojis[buttonIndex] toMessage:msg];
        } else if (buttonIndex == 4) {
            [self promptCustomReactionForMessage:msg];
        } else if (buttonIndex == 5) {
            [self copyMessage:msg];
        }
        return;
    }

    if (sheet.tag == 200) {
        if (buttonIndex < [emojis count]) {
            [self sendReaction:emojis[buttonIndex] toMessage:msg];
        } else if (buttonIndex == 4) {
            [self promptCustomReactionForMessage:msg];
        } else if (buttonIndex == 5) {
            [self copyMessage:msg];
        } else if (buttonIndex == 6) {
            [self editMessage:msg row:_selectedRow];
        } else if (buttonIndex == 7) {
            [self deleteMessage:msg row:_selectedRow];
        }
    }
}

- (void)promptCustomReactionForMessage:(MatrixMessage *)msg {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Custom Reaction"
                                                    message:@"Enter emoji"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Send", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert textFieldAtIndex:0].placeholder = @"e.g. 😎";
    objc_setAssociatedObject(alert, "reactionMsg", msg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    alert.tag = 900;
    [alert show];
}

- (void)copyMessage:(MatrixMessage *)msg {
    [UIPasteboard generalPasteboard].string = msg.body;
}

- (void)sendReaction:(NSString *)emoji toMessage:(MatrixMessage *)msg {
    [[MatrixAPIClient sharedClient] sendReaction:emoji
                                          roomId:self.room.roomId
                                         eventId:msg.eventId
                                      completion:^(NSDictionary *resp, NSError *err) {
        if (!err) {
            if (!msg.reactions) msg.reactions = [NSMutableDictionary dictionary];
            NSNumber *count = msg.reactions[emoji] ?: @0;
            msg.reactions[emoji] = @([count intValue] + 1);
            [self buildDisplayItems];
            [self.tableView reloadData];
        }
    }];
}

- (void)editMessage:(MatrixMessage *)msg row:(NSInteger)row {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Edit Message"
                                                    message:nil
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [[alert textFieldAtIndex:0] setText:msg.body];
    alert.tag = 300 + row;
    [alert show];
}

- (void)deleteMessage:(MatrixMessage *)msg row:(NSInteger)row {
    [[MatrixAPIClient sharedClient] redactMessage:self.room.roomId
                                         eventId:msg.eventId
                                      completion:^(NSDictionary *resp, NSError *err) {
        if (err) {
            [NeoAlert showAlertWithTitle:@"Error" message:[err localizedDescription] cancelTitle:@"OK" controller:self];
        } else {
            [self.messages removeObjectAtIndex:row];
            [self buildDisplayItems];
            [self.tableView reloadData];
        }
    }];
}

- (void)profileTapped {
    ProfileViewController *profile = [[ProfileViewController alloc] init];
    profile.room = self.room;
    profile.roomAvatar = self.roomAvatar;
    [self.navigationController pushViewController:profile animated:YES];
}

- (void)loadMemberNames {
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSDictionary *cached = [client cachedMembersForRoom:self.room.roomId];
    if (cached) {
        _memberNames = cached;
        return;
    }

    [client getMembersForRoom:self.room.roomId completion:^(NSDictionary *members, NSError *error) {
        if (members) {
            _memberNames = members;
            [self buildDisplayItems];
            [self.tableView reloadData];
            if (_shouldAutoScroll) {
                [self scrollToBottom];
            }
        }
    }];
}

- (void)buildDisplayItems {
    [_displayItems removeAllObjects];
    NSString *lastDateStr = nil;
    NSDateFormatter *dayFmt = [[NSDateFormatter alloc] init];
    dayFmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"es_CL"];
    dayFmt.dateFormat = @"EEEE, MMMM d";

    for (MatrixMessage *msg in self.messages) {
        if (!msg.timestamp) {
            [_displayItems addObject:msg];
            continue;
        }
        NSString *dateStr = [dayFmt stringFromDate:msg.timestamp];
        if (!lastDateStr || ![dateStr isEqualToString:lastDateStr]) {
            [_displayItems addObject:dateStr];
            lastDateStr = dateStr;
        }
        [_displayItems addObject:msg];
    }
}

- (void)loadMessages {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _lastMessageLoad < 5.0 && [self.messages count] > 0) return;

    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSArray *cached = [client cachedMessagesForRoom:self.room.roomId];
    if (cached && [self.messages count] == 0) {
        [self.messages addObjectsFromArray:cached];
        [self buildDisplayItems];
        [self.tableView reloadData];
        [self scrollToBottom];
    }

    [self.spinner startAnimating];
    [client getRoomMessages:self.room.roomId completion:^(NSDictionary *response, NSError *error) {
        [self.spinner stopAnimating];
        if (error) return;
        [self.messages removeAllObjects];
        NSArray *chunk = response[@"chunk"];
        NSMutableArray *newMessages = [NSMutableArray array];
        NSMutableDictionary *msgByEventId = [NSMutableDictionary dictionary];
        for (NSDictionary *evt in [chunk reverseObjectEnumerator]) {
            NSString *type = evt[@"type"];

            if ([type isEqualToString:@"m.room.message"]) {
                NSDictionary *relatesto = evt[@"content"][@"m.relates_to"];
                if ([relatesto[@"rel_type"] isEqualToString:@"m.replace"]) continue;

                MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:evt
                                                                        roomId:self.room.roomId];
                [newMessages addObject:msg];
                if (msg.eventId) [msgByEventId setObject:msg forKey:msg.eventId];
            }

            if ([type isEqualToString:@"m.room.redaction"]) {
                NSString *redactedId = evt[@"redacts"];
                MatrixMessage *target = [msgByEventId objectForKey:redactedId];
                if (target) {
                    target.isRedacted = YES;
                    target.body = NSLocalizedString(@"Deleted message", nil);
                }
            }

            if ([type isEqualToString:@"m.reaction"]) {
                NSDictionary *relatesto = evt[@"content"][@"m.relates_to"];
                NSString *targetId = relatesto[@"event_id"];
                NSString *emoji = relatesto[@"key"];
                if (!targetId || !emoji) continue;
                MatrixMessage *target = [msgByEventId objectForKey:targetId];
                if (!target) continue;
                NSNumber *count = target.reactions[emoji] ?: @0;
                target.reactions[emoji] = @([count intValue] + 1);
            }
        }

        self.messages = newMessages;
        [client cacheMessages:[self.messages copy] forRoom:self.room.roomId];
        BOOL firstLoad = (_lastMessageLoad == 0);
        _lastMessageLoad = now;
        [self buildDisplayItems];
        [self.tableView reloadData];
        // Primera carga: siempre al fondo. Refrescos: solo si cerca del fondo
        CGFloat nearBottom = self.tableView.contentOffset.y + self.tableView.bounds.size.height;
        CGFloat threshold = self.tableView.contentSize.height - 60;
        if (firstLoad || nearBottom >= threshold) {
            [self scrollToBottom];
        }
    }];
}

- (void)startSyncLoop {
    if (!_syncActive) return;
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    [client syncWithSince:client.nextBatchToken timeout:20000 completion:^(NSDictionary *response, NSError *error) {
        if (!_syncActive) return;
        if (error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self startSyncLoop];
            });
            return;
        }

        NSString *nextBatch = response[@"next_batch"];
        if (nextBatch) client.nextBatchToken = nextBatch;

        NSDictionary *roomsJoin = response[@"rooms"][@"join"];
        NSDictionary *roomData = [roomsJoin objectForKey:self.room.roomId];
        if (roomData) {
            [self processSyncEvents:roomData[@"timeline"][@"events"]];
        }

        [self startSyncLoop];
    }];
}

- (void)processSyncEvents:(NSArray *)events {
    if ([events count] == 0) return;

    BOOL needsReload = NO;
    for (NSDictionary *evt in events) {
        NSString *type = evt[@"type"];

        if ([type isEqualToString:@"m.room.message"]) {
            NSDictionary *relatesto = evt[@"content"][@"m.relates_to"];
            if ([relatesto[@"rel_type"] isEqualToString:@"m.replace"]) continue;

            BOOL exists = NO;
            for (MatrixMessage *existing in self.messages) {
                if ([existing.eventId isEqualToString:evt[@"event_id"]]) { exists = YES; break; }
            }
            if (exists) continue;

            MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:evt roomId:self.room.roomId];
            [self.messages addObject:msg];
            needsReload = YES;
        }

        if ([type isEqualToString:@"m.room.redaction"]) {
            NSString *redactedId = evt[@"redacts"];
            for (MatrixMessage *msg in self.messages) {
                if ([msg.eventId isEqualToString:redactedId]) {
                    msg.isRedacted = YES;
                    msg.body = NSLocalizedString(@"Deleted message", nil);
                    needsReload = YES;
                    break;
                }
            }
        }

        if ([type isEqualToString:@"m.reaction"]) {
            NSDictionary *relatesto = evt[@"content"][@"m.relates_to"];
            NSString *targetId = relatesto[@"event_id"];
            NSString *emoji = relatesto[@"key"];
            if (!targetId || !emoji) continue;
            for (MatrixMessage *msg in self.messages) {
                if ([msg.eventId isEqualToString:targetId]) {
                    NSNumber *count = msg.reactions[emoji] ?: @0;
                    msg.reactions[emoji] = @([count intValue] + 1);
                    needsReload = YES;
                    break;
                }
            }
        }
    }

    if (needsReload) {
        [[MatrixAPIClient sharedClient] cacheMessages:[self.messages copy] forRoom:self.room.roomId];
        [self buildDisplayItems];
        [self.tableView reloadData];
        CGFloat nearBottom = self.tableView.contentOffset.y + self.tableView.bounds.size.height;
        if (nearBottom >= self.tableView.contentSize.height - 60) {
            [self scrollToBottom];
        }
    }
}

- (void)scrollToBottom {
    NSInteger lastRow = [_displayItems count] - 1;
    if (lastRow < 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:lastRow inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}

- (NSString *)displayNameForSender:(NSString *)sender {
    NSDictionary *info = [_memberNames objectForKey:sender];
    if (info) {
        NSString *name = info[@"displayname"];
        if ([name length] > 0) return name;
    }
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    if ([sender isEqualToString:myId]) return @"You";
    NSRange colon = [sender rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        NSString *localpart = [sender substringToIndex:colon.location];
        if ([localpart hasPrefix:@"@"]) return [localpart substringFromIndex:1];
        return localpart;
    }
    return sender;
}

- (void)sendTapped {
    NSString *text = self.messageField.text;
    if ([text length] == 0) return;

    self.messageField.text = @"";
    [self updateSendButtonAppearance];
    self.sendButton.enabled = NO;

    [[MatrixAPIClient sharedClient] sendMessage:text roomId:self.room.roomId completion:^(NSDictionary *response, NSError *error) {
        self.sendButton.enabled = YES;
        if (error) {
            [NeoAlert showAlertWithTitle:@"Error" message:[error localizedDescription] cancelTitle:@"OK" controller:self];
            return;
        }
        NSString *eventId = response[@"event_id"];
        if (!eventId) return;

        BOOL alreadyExists = NO;
        for (MatrixMessage *m in self.messages) {
            if ([m.eventId isEqualToString:eventId]) { alreadyExists = YES; break; }
        }
        if (alreadyExists) return;

        MatrixMessage *msg = [[MatrixMessage alloc] init];
        msg.eventId = eventId;
        msg.sender = [[MatrixAPIClient sharedClient] userId];
        msg.body = text;
        msg.msgType = @"m.text";
        msg.roomId = self.room.roomId;
        msg.timestamp = [NSDate date];
        [self.messages addObject:msg];
        [self buildDisplayItems];
        [self.tableView reloadData];
        [self scrollToBottom];
    }];
}

#pragma mark - Audio Recording

- (void)startRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatAppleIMA4),
        AVSampleRateKey: @44100.0f,
        AVNumberOfChannelsKey: @1,
        AVEncoderBitDepthHintKey: @16,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
    };

    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.caf"];
    NSURL *url = [NSURL fileURLWithPath:tmpPath];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    NSError *error = nil;
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
    if (error || !_audioRecorder) {
        NSLog(@"Recorder error: %@", error);
        return;
    }
    [_audioRecorder prepareToRecord];
    [_audioRecorder record];

    if (!_recordingLabel) {
        _recordingLabel = [[UILabel alloc] initWithFrame:CGRectMake(84, 6, 200, 32)];
        _recordingLabel.font = [UIFont boldSystemFontOfSize:15];
        _recordingLabel.textColor = [UIColor redColor];
        _recordingLabel.backgroundColor = [UIColor clearColor];
        [self.inputView addSubview:_recordingLabel];
    }
    _recordingLabel.hidden = NO;
    self.messageField.hidden = YES;

    _recordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateRecordingTimer) userInfo:nil repeats:YES];
}

- (void)stopRecordingAndSend:(BOOL)shouldSend {
    [_recordingTimer invalidate];
    _recordingTimer = nil;

    if (!_audioRecorder) return;

    [_audioRecorder stop];
    _recordingLabel.hidden = YES;
    self.messageField.hidden = NO;

    if (!shouldSend) {
        _audioRecorder = nil;
        return;
    }

    NSTimeInterval duration = _audioRecorder.currentTime;
    NSURL *url = _audioRecorder.url;
    NSData *audioData = [NSData dataWithContentsOfURL:url];
    _audioRecorder = nil;

    if (!audioData) return;

    [self uploadAndSendAudio:audioData duration:duration];
}

- (void)updateRecordingTimer {
    if (_audioRecorder && _audioRecorder.recording) {
        NSTimeInterval t = _audioRecorder.currentTime;
        _recordingLabel.text = [NSString stringWithFormat:@"🔴 %d:%02d", (int)t / 60, (int)t % 60];
    }
}

- (void)uploadAndSendAudio:(NSData *)audioData duration:(NSTimeInterval)duration {
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSString *path = @"/_matrix/media/r0/upload?filename=audio.caf";
    NSMutableURLRequest *req = [client requestWithPath:path method:@"POST"];
    [req setValue:@"audio/mp4" forHTTPHeaderField:@"Content-Type"];
    [req setHTTPBody:audioData];

    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error) {
        if (error || !data) {
            NSLog(@"Audio upload error: %@", error);
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *contentURI = json[@"content_uri"];
        if (!contentURI) return;

        NSDictionary *body = @{
            @"msgtype": @"m.audio",
            @"body": @"Voice message",
            @"url": contentURI,
            @"info": @{
                @"duration": @((NSInteger)(duration * 1000)),
                @"size": @([audioData length]),
                @"mimetype": @"audio/mp4"
            }
        };

        NSMutableURLRequest *msgReq = [client requestWithPath:[NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@", self.room.roomId, [[NSUUID UUID] UUIDString]] method:@"PUT"];
        [msgReq setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [msgReq setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];

        [NSURLConnection sendAsynchronousRequest:msgReq queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
            if (e) {
                NSLog(@"Audio message send error: %@", e);
                return;
            }
            NSDictionary *respJSON = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            NSString *eventId = respJSON[@"event_id"];
            if (!eventId) return;

            BOOL alreadyExists = NO;
            for (MatrixMessage *m in self.messages) {
                if ([m.eventId isEqualToString:eventId]) { alreadyExists = YES; break; }
            }
            if (alreadyExists) return;

            MatrixMessage *msg = [[MatrixMessage alloc] init];
            msg.eventId = eventId;
            msg.sender = client.userId;
            msg.body = @"🎤 Voice message";
            msg.msgType = @"m.audio";
            msg.roomId = self.room.roomId;
            msg.timestamp = [NSDate date];
            msg.audioURL = contentURI;
            msg.audioDuration = @((NSInteger)(duration * 1000));
            [self.messages addObject:msg];
            [self buildDisplayItems];
            [self.tableView reloadData];
            [self scrollToBottom];
        }];
    }];
}

- (void)updateSendButtonAppearance {
    BOOL isEmpty = ([self.messageField.text length] == 0);
    if (isEmpty == _sendButtonIsMicMode) return;

    _sendButtonIsMicMode = isEmpty;

    [self.sendButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];

    self.sendButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.sendButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.sendButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;

    if (isEmpty) {
        [self.sendButton setImage:[UIImage imageNamed:@"MicBtn"] forState:UIControlStateNormal];
        [self.sendButton setImage:[UIImage imageNamed:@"MicRecBtn"] forState:UIControlStateHighlighted];
        [self.sendButton addTarget:self action:@selector(micTouchDown) forControlEvents:UIControlEventTouchDown];
        [self.sendButton addTarget:self action:@selector(micTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        [self.sendButton addTarget:self action:@selector(micTouchUpOutside) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchDragExit];
    } else {
        [self.sendButton setImage:[UIImage imageNamed:@"send"] forState:UIControlStateNormal];
        [self.sendButton setImage:[UIImage imageNamed:@"send-highlighted"] forState:UIControlStateHighlighted];
        [self.sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
        replacementString:(NSString *)string {
    if (textField == self.messageField) {
        NSString *resultText = [textField.text stringByReplacingCharactersInRange:range withString:string];
        BOOL willBeEmpty = ([resultText length] == 0);
        BOOL isEmptyNow = ([self.messageField.text length] == 0);
        if (willBeEmpty != isEmptyNow) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateSendButtonAppearance];
            });
        }
    }
    return YES;
}

- (void)micTouchDown {
    [self startRecording];
}

- (void)micTouchUpInside {
    NSTimeInterval dur = _audioRecorder.currentTime;
    if (dur < 1.0) {
        [self stopRecordingAndSend:NO];
        return;
    }
    [self stopRecordingAndSend:YES];
}

- (void)micTouchUpOutside {
    [self stopRecordingAndSend:NO];
}

- (void)cameraTapped {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    BOOL isVideo = [mediaType isEqualToString:@"public.movie"];

    if (isVideo) {
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        if (!videoURL) return;

        NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
        if (!videoData) return;

        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        CGFloat w = 0, h = 0;
        if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0) {
            AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo][0];
            CGSize size = track.naturalSize;
            w = size.width;
            h = size.height;
        }
        CMTime durationTime = asset.duration;
        NSInteger durationMs = (NSInteger)(CMTimeGetSeconds(durationTime) * 1000);

        // Generate thumbnail
        AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        gen.appliesPreferredTrackTransform = YES;
        CMTime thumbTime = CMTimeMake(1, 1);
        CGImageRef thumbRef = [gen copyCGImageAtTime:thumbTime actualTime:NULL error:nil];
        UIImage *thumbnail = thumbRef ? [UIImage imageWithCGImage:thumbRef] : nil;
        if (thumbRef) CGImageRelease(thumbRef);

        UIAlertView *uploadAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Uploading video...", nil)
                                                               message:nil
                                                              delegate:nil
                                                     cancelButtonTitle:nil
                                                     otherButtonTitles:nil];
        [uploadAlert show];

        MatrixAPIClient *client = [MatrixAPIClient sharedClient];

        if (thumbnail) {
            NSData *thumbData = UIImageJPEGRepresentation(thumbnail, 0.7);
            [client uploadData:thumbData mimeType:@"image/jpeg" filename:@"video_thumb.jpg" completion:^(NSString *thumbURI, NSError *thumbErr) {
                [self sendVideoAfterUpload:videoData videoURL:videoURL thumbnailURI:thumbURI width:w height:h durationMs:durationMs uploadAlert:uploadAlert];
            }];
        } else {
            [self sendVideoAfterUpload:videoData videoURL:videoURL thumbnailURI:nil width:w height:h durationMs:durationMs uploadAlert:uploadAlert];
        }
    } else {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        if (!image) return;

        [[MatrixAPIClient sharedClient] uploadImage:image completion:^(NSString *contentURI, NSError *err) {
            if (err) {
                [NeoAlert showAlertWithTitle:@"Upload Error" message:[err localizedDescription] cancelTitle:@"OK" controller:self];
                return;
            }
            [[MatrixAPIClient sharedClient] sendImageMessage:contentURI
                                                       roomId:self.room.roomId
                                                      caption:@"Photo"
                                                   completion:^(NSDictionary *resp, NSError *sendErr) {
                if (sendErr) {
                    [NeoAlert showAlertWithTitle:@"Send Error" message:[sendErr localizedDescription] cancelTitle:@"OK" controller:self];
                    return;
                }
                MatrixMessage *msg = [[MatrixMessage alloc] init];
                msg.eventId = resp[@"event_id"];
                msg.sender = [[MatrixAPIClient sharedClient] userId];
                msg.body = @"Photo";
                msg.msgType = @"m.image";
                msg.imageURL = contentURI;
                msg.roomId = self.room.roomId;
                msg.timestamp = [NSDate date];
                [self.messages addObject:msg];
            [self buildDisplayItems];
            [self.tableView reloadData];
            if (_shouldAutoScroll) {
                [self scrollToBottom];
            }
        }];
        }];
    }
}

- (void)sendVideoAfterUpload:(NSData *)videoData videoURL:(NSURL *)videoURL thumbnailURI:(NSString *)thumbURI width:(CGFloat)w height:(CGFloat)h durationMs:(NSInteger)durationMs uploadAlert:(UIAlertView *)alert {
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    [client uploadData:videoData mimeType:@"video/mp4" filename:@"video.mp4" completion:^(NSString *videoURI, NSError *videoErr) {
        [alert dismissWithClickedButtonIndex:0 animated:YES];
        if (videoErr) {
            [NeoAlert showAlertWithTitle:@"Upload Error" message:[videoErr localizedDescription] cancelTitle:@"OK" controller:self];
            return;
        }
        [client sendVideoMessage:videoURI
                          roomId:self.room.roomId
                       thumbnail:thumbURI
                        duration:durationMs
                           width:w
                          height:h
                            size:(NSInteger)[videoData length]
                      completion:^(NSDictionary *resp, NSError *sendErr) {
            if (sendErr) {
                [NeoAlert showAlertWithTitle:@"Send Error" message:[sendErr localizedDescription] cancelTitle:@"OK" controller:self];
                return;
            }
            MatrixMessage *msg = [[MatrixMessage alloc] init];
            msg.eventId = resp[@"event_id"];
            msg.sender = client.userId;
            msg.body = @"Video";
            msg.msgType = @"m.video";
            msg.videoURL = videoURI;
            msg.videoThumbnailURL = thumbURI;
            msg.videoDuration = @(durationMs);
            msg.videoWidth = w;
            msg.videoHeight = h;
            msg.roomId = self.room.roomId;
            msg.timestamp = [NSDate date];
            [self.messages addObject:msg];
            [self buildDisplayItems];
            [self.tableView reloadData];
            if (_shouldAutoScroll) {
                [self scrollToBottom];
            }
        }];
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendTapped];
    return YES;
}

#pragma mark - Scroll tracking

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _shouldAutoScroll = NO;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self checkScrollAtBottom:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self checkScrollAtBottom:scrollView];
}

- (void)checkScrollAtBottom:(UIScrollView *)scrollView {
    CGFloat bottomEdge = scrollView.contentOffset.y + scrollView.bounds.size.height;
    if (bottomEdge >= scrollView.contentSize.height - 44) {
        _shouldAutoScroll = YES;
    }
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)note {
    NSDictionary *info = [note userInfo];
    CGRect kbFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat kbHeight = kbFrame.size.height;
    CGFloat duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    CGRect tableFrame = self.tableView.frame;
    CGRect inputFrame = self.messageField.superview.frame;
    inputFrame.origin.y = self.view.bounds.size.height - kbHeight - inputFrame.size.height;
    tableFrame.size.height = inputFrame.origin.y;

    [UIView animateWithDuration:duration animations:^{
        self.tableView.frame = tableFrame;
        self.messageField.superview.frame = inputFrame;
    }];
    [self scrollToBottom];
}

- (void)keyboardWillHide:(NSNotification *)note {
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat tableH = h - 44;

    [UIView animateWithDuration:duration animations:^{
        self.tableView.frame = CGRectMake(0, 0, w, tableH);
        self.messageField.superview.frame = CGRectMake(0, tableH, w, 44);
    }];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_displayItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = [_displayItems objectAtIndex:indexPath.row];

    // Date separator cell
    if ([item isKindOfClass:[NSString class]]) {
        static NSString *dateCellId = @"DateCell";
        MatrixBubbleMessageCell *dateCell = [tableView dequeueReusableCellWithIdentifier:dateCellId];
        if (!dateCell) {
            dateCell = [[MatrixBubbleMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:dateCellId];
            dateCell.backgroundColor = [UIColor clearColor];
        }
        [dateCell configureWithType:MatrixBubbleMessageTypeIncoming
                              msgId:nil
                          showUser:NO
                     showTimestamp:NO
                          hasMedia:NO
                         mediaView:nil
                   dateSeparator:(NSString *)item];
        return dateCell;
    }

    // Message cell
    MatrixMessage *msg = (MatrixMessage *)item;
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    BOOL isSelf = (myId && [msg.sender isEqualToString:myId]);
    BOOL isGroupChat = YES;

    MatrixBubbleMessageType type = isSelf ? MatrixBubbleMessageTypeOutgoing : MatrixBubbleMessageTypeIncoming;
    BOOL isFirstInGroup = [self isFirstInGroupAtIndexPath:indexPath];
    BOOL showUser = (!isSelf && isGroupChat && isFirstInGroup);
    BOOL showTimestamp = YES;
    BOOL isAudio = [msg.msgType isEqualToString:@"m.audio"];
    BOOL isVideo = [msg.msgType isEqualToString:@"m.video"];
    BOOL hasMedia = ([msg.msgType isEqualToString:@"m.image"] ||
                     [msg.body hasPrefix:@"mxc://"] ||
                     isAudio ||
                     isVideo);

    NSString *cellId = [NSString stringWithFormat:@"MsgCell_%d_%d_%d_%d", type, showUser, showTimestamp, isAudio || isVideo];
    MatrixBubbleMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];

    UIView *mediaView = nil;
    if (isVideo) {
        CGFloat vidW = 200;
        CGFloat vidH = 140;
        if (msg.videoWidth > 0 && msg.videoHeight > 0) {
            CGFloat ratio = msg.videoHeight / msg.videoWidth;
            vidH = vidW * ratio;
            if (vidH > 200) { vidH = 200; vidW = vidH / ratio; }
        }
        VideoMessageView *videoView = [[VideoMessageView alloc] initWithFrame:CGRectMake(0, 0, vidW, vidH)];
        videoView.videoMxcURL = msg.videoURL;
        videoView.thumbnailMxcURL = msg.videoThumbnailURL;
        videoView.duration = msg.videoDuration;
        if (msg.cachedVideoThumbnail) {
            videoView.thumbnailImage = msg.cachedVideoThumbnail;
        } else {
            [videoView startThumbnailDownload];
        }
        mediaView = videoView;
    } else if (isAudio) {
        AudioMessageView *audioView = [[AudioMessageView alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
        audioView.mxcURL = msg.audioURL;
        audioView.duration = msg.audioDuration;
        mediaView = audioView;
    } else if (hasMedia) {
        UIImageView *preview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 150, 130)];
        preview.contentMode = UIViewContentModeScaleAspectFill;
        preview.clipsToBounds = YES;
        preview.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
        preview.layer.cornerRadius = 6;

        if (msg.cachedImage) {
            preview.image = msg.cachedImage;
        } else {
            NSIndexPath *cellPath = indexPath;
            [[MatrixAPIClient sharedClient] downloadImageFromMXC:msg.imageURL
                completion:^(UIImage *img, NSError *err) {
                if (img) {
                    msg.cachedImage = img;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [tableView reloadRowsAtIndexPaths:@[cellPath]
                                         withRowAnimation:UITableViewRowAnimationNone];
                    });
                }
            }];
        }
        mediaView = preview;
    }

    if (!cell) {
        cell = [[MatrixBubbleMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
    }

    [cell configureWithType:type
                     msgId:msg.eventId
                 showUser:showUser
            showTimestamp:showTimestamp
                 hasMedia:hasMedia
                mediaView:mediaView
          dateSeparator:nil];
    [cell setMessage:msg.body];
    [cell setTimestamp:msg.timestamp];
    [cell setIsRedacted:msg.isRedacted];
    [cell setUserWrited:[self displayNameForSender:msg.sender]];

    if (isSelf) {
        [cell setAck:1];
    }

    // Reacciones
    UILabel *reactionLabel = (UILabel *)[cell.contentView viewWithTag:90];
    if (!reactionLabel) {
        reactionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        reactionLabel.tag = 90;
        reactionLabel.font = [UIFont systemFontOfSize:14];
        reactionLabel.backgroundColor = [UIColor clearColor];
        reactionLabel.hidden = YES;
        [cell.contentView addSubview:reactionLabel];
    }

    if ([msg.reactions count] > 0) {
        // Top 5 reacciones por frecuencia
        NSArray *sorted = [[msg.reactions allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *e1, NSString *e2) {
            return [msg.reactions[e2] compare:msg.reactions[e1]];
        }];
        NSInteger limit = MIN(5, (NSInteger)[sorted count]);

        NSMutableString *reactionStr = [NSMutableString string];
        for (NSInteger i = 0; i < limit; i++) {
            NSString *emoji = sorted[i];
            NSNumber *count = msg.reactions[emoji];
            if ([count intValue] > 1) {
                [reactionStr appendFormat:@"%@ %d  ", emoji, [count intValue]];
            } else {
                [reactionStr appendFormat:@"%@  ", emoji];
            }
        }
        reactionLabel.text = reactionStr;
        CGSize reactionSize = [reactionStr sizeWithFont:[UIFont systemFontOfSize:14]];

        CGRect bf = [cell.bubbleView bubbleFrame];
        // Mitad dentro / mitad fuera del borde inferior de la burbuja
        CGFloat reactionY = CGRectGetMaxY(bf) - 8;

        CGFloat reactionX = isSelf
            ? (CGRectGetMaxX(bf) - reactionSize.width - 8)
            : CGRectGetMinX(bf) + [MatrixBubbleView textXOffsetForType:MatrixBubbleMessageTypeIncoming];

        reactionLabel.frame = CGRectMake(reactionX, reactionY, reactionSize.width + 8, 20);
        reactionLabel.hidden = NO;
    } else {
        reactionLabel.hidden = YES;
        reactionLabel.text = @"";
    }

    return cell;
}

- (NSString *)cachePathForMXC:(NSString *)mxcURL {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
                          stringByAppendingPathComponent:@"MediaCache"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString *safeName = [mxcURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    safeName = [safeName stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    return [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", safeName]];
}

- (void)saveVideoToPhotosForMXC:(NSString *)mxcURL {
    NSString *cachePath = [self cachePathForMXC:mxcURL];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        UISaveVideoAtPathToSavedPhotosAlbum(cachePath, self,
            @selector(video:didFinishSavingWithError:contextInfo:), NULL);
    }
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        [NeoAlert showAlertWithTitle:NSLocalizedString(@"Error", nil)
                             message:[error localizedDescription]
                         cancelTitle:@"OK"
                          controller:self];
    } else {
        [NeoAlert showAlertWithTitle:NSLocalizedString(@"Saved", nil)
                             message:NSLocalizedString(@"Video saved to Photos", nil)
                         cancelTitle:@"OK"
                          controller:self];
    }
}

- (void)playVideoWithMXC:(NSString *)mxcURL {
    if ([mxcURL length] == 0) return;

    NSString *cachePath = [self cachePathForMXC:mxcURL];

    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        MatrixAPIClient *client = [MatrixAPIClient sharedClient];
        NSString *httpURL = [client mxcURLToHTTP:mxcURL];
        if (!httpURL) return;

        UIAlertView *loadingAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Loading video...", nil)
                                                               message:nil
                                                              delegate:nil
                                                     cancelButtonTitle:nil
                                                     otherButtonTitles:nil];
        [loadingAlert show];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:httpURL]];
            if (client.accessToken) {
                [req setValue:[NSString stringWithFormat:@"Bearer %@", client.accessToken] forHTTPHeaderField:@"Authorization"];
            }
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];

            dispatch_async(dispatch_get_main_queue(), ^{
                [loadingAlert dismissWithClickedButtonIndex:0 animated:YES];
                if (error || !data) {
                    [NeoAlert showAlertWithTitle:NSLocalizedString(@"Error", nil)
                                         message:NSLocalizedString(@"Could not load video", nil)
                                     cancelTitle:@"OK"
                                      controller:self];
                    return;
                }
                [data writeToFile:cachePath atomically:YES];
                [self playVideoFromCache:cachePath mxcURL:mxcURL];
            });
        });
    } else {
        [self playVideoFromCache:cachePath mxcURL:mxcURL];
    }
}

- (void)playVideoFromCache:(NSString *)cachePath mxcURL:(NSString *)mxcURL {
    NSString *savedMXC = [mxcURL copy];
    objc_setAssociatedObject(self, "pendingSaveMXC", savedMXC, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(videoPlayerDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:nil];

    NSURL *videoURL = [NSURL fileURLWithPath:cachePath];
    MPMoviePlayerViewController *player = [[MPMoviePlayerViewController alloc] initWithContentURL:videoURL];
    [self presentMoviePlayerViewControllerAnimated:player];
}

- (void)videoPlayerDidFinish:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:MPMoviePlayerPlaybackDidFinishNotification
                                                  object:nil];

    NSString *mxcURL = objc_getAssociatedObject(self, "pendingSaveMXC");
    if (!mxcURL) return;

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Video", nil)
                                                    message:NSLocalizedString(@"Save this video to Photos?", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"No", nil)
                                          otherButtonTitles:NSLocalizedString(@"Save", nil), nil];
    alert.tag = 777;
    objc_setAssociatedObject(alert, "saveMXC", mxcURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [alert show];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id item = [_displayItems objectAtIndex:indexPath.row];
    if (![item isKindOfClass:[MatrixMessage class]]) return;
    MatrixMessage *msg = (MatrixMessage *)item;

    if ([msg.msgType isEqualToString:@"m.video"]) {
        [self playVideoWithMXC:msg.videoURL];
        return;
    }

    if (![msg.msgType isEqualToString:@"m.image"] && ![msg.body hasPrefix:@"mxc://"]) return;

    if ([msg.imageURL length] == 0) return;

    UIViewController *viewer = [[UIViewController alloc] init];
    viewer.view.backgroundColor = [UIColor blackColor];
    viewer.title = @"Photo";

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:viewer.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.minimumZoomScale = 1.0;
    scroll.maximumZoomScale = 4.0;
    scroll.delegate = (id<UIScrollViewDelegate>)viewer;
    [viewer.view addSubview:scroll];

    UIImageView *imgView = [[UIImageView alloc] initWithFrame:scroll.bounds];
    imgView.contentMode = UIViewContentModeScaleAspectFit;
    imgView.tag = 77;
    [scroll addSubview:imgView];

    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                                 style:UIBarButtonItemStyleDone
                                                                target:self
                                                                action:@selector(dismissViewer)];
    viewer.navigationItem.rightBarButtonItem = closeBtn;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:viewer];
    [self presentViewController:nav animated:YES completion:nil];

    [[MatrixAPIClient sharedClient] downloadImageFromMXC:msg.imageURL completion:^(UIImage *image, NSError *err) {
        if (image) {
            imgView.image = image;
            CGSize fitSize = [self fitSize:image.size inSize:scroll.bounds.size];
            imgView.frame = CGRectMake(0, 0, fitSize.width, fitSize.height);
            scroll.contentSize = fitSize;
        }
    }];
}

- (CGSize)fitSize:(CGSize)from inSize:(CGSize)to {
    CGFloat scale = MIN(to.width / from.width, to.height / from.height);
    return CGSizeMake(from.width * scale, from.height * scale);
}

- (void)dismissViewer {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = [_displayItems objectAtIndex:indexPath.row];

    if ([item isKindOfClass:[NSString class]]) {
        return 28;
    }

    MatrixMessage *msg = (MatrixMessage *)item;
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    BOOL isSelf = (myId && [msg.sender isEqualToString:myId]);
    BOOL isGroupChat = YES;
    BOOL isFirstInGroup = [self isFirstInGroupAtIndexPath:indexPath];
    BOOL showUser = (!isSelf && isGroupChat && isFirstInGroup);
    BOOL showTimestamp = YES;
    BOOL isAudio = [msg.msgType isEqualToString:@"m.audio"];
    BOOL isVideo = [msg.msgType isEqualToString:@"m.video"];
    BOOL hasMedia = ([msg.msgType isEqualToString:@"m.image"] ||
                     [msg.body hasPrefix:@"mxc://"] ||
                     isAudio ||
                     isVideo);

    CGFloat bubbleH;
    if (isAudio) {
        bubbleH = [MatrixBubbleView cellHeightForMediaWithText:msg.body
                                                       showUser:showUser
                                                  showTimestamp:showTimestamp
                                                     isRedacted:msg.isRedacted
                                                    mediaHeight:50];
    } else if (isVideo) {
        CGFloat vidW = 200;
        CGFloat vidH = 140;
        if (msg.videoWidth > 0 && msg.videoHeight > 0) {
            CGFloat ratio = msg.videoHeight / msg.videoWidth;
            vidH = vidW * ratio;
            if (vidH > 200) { vidH = 200; vidW = vidH / ratio; }
        }
        bubbleH = [MatrixBubbleView cellHeightForMediaWithText:msg.body
                                                       showUser:showUser
                                                  showTimestamp:showTimestamp
                                                     isRedacted:msg.isRedacted
                                                    mediaHeight:vidH];
    } else if (hasMedia) {
        bubbleH = [MatrixBubbleView cellHeightForMediaWithText:msg.body
                                                       showUser:showUser
                                                  showTimestamp:showTimestamp
                                                     isRedacted:msg.isRedacted
                                                    mediaHeight:130];
    } else {
        bubbleH = [MatrixBubbleView cellHeightForText:msg.body
                                             showUser:showUser
                                        showTimestamp:showTimestamp
                                           isRedacted:msg.isRedacted];
    }

    CGFloat reactionH = ([msg.reactions count] > 0) ? 22 : 0;
    return bubbleH + reactionH;
}

#pragma mark - Helpers

- (BOOL)isFirstInGroupAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) return YES;

    id currentItem = [_displayItems objectAtIndex:indexPath.row];
    if (![currentItem isKindOfClass:[MatrixMessage class]]) return YES;
    MatrixMessage *currentMsg = (MatrixMessage *)currentItem;

    id prevItem = [_displayItems objectAtIndex:indexPath.row - 1];

    if ([prevItem isKindOfClass:[NSString class]]) return YES;

    MatrixMessage *prevMsg = (MatrixMessage *)prevItem;
    return ![prevMsg.sender isEqualToString:currentMsg.sender];
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

#pragma mark - Disable system copy menu

- (BOOL)tableView:(UITableView *)tableView
        shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView
        canPerformAction:(SEL)action
        forRowAtIndexPath:(NSIndexPath *)indexPath
        withSender:(id)sender {
    return NO;
}

- (void)tableView:(UITableView *)tableView
     performAction:(SEL)action
 forRowAtIndexPath:(NSIndexPath *)indexPath
        withSender:(id)sender {
}

@end

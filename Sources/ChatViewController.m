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
#import <AudioToolbox/AudioToolbox.h>
#import "AudioMessageView.h"
#import "NeoReactionPillView.h"
#import "VideoMessageView.h"
#import <MediaPlayer/MediaPlayer.h>
#import "DemoModeManager.h"
#import "ReplyBubbleView.h"
#import "PhotoViewerController.h"
#import "FileMessageView.h"
#import "ForwardPickerController.h"
#import "NeoSyncProcessor.h"
#import "NeoReactionViewBuilder.h"
#import "TGTableDeltaUpdater.h"
#import "NeoProgressSpinnerView.h"

@interface NeoDisplayAdapter : NSObject <TGTableItem>
@property (nonatomic, copy) NSString *ident;
@end
@implementation NeoDisplayAdapter
- (NSString *)uniqueIdentifier { return _ident ?: @""; }
@end

@interface NeoInputFieldView : UIView
@end
@implementation NeoInputFieldView
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectInset(self.bounds, 1.0f, 1.0f);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:8.0f];
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 1.0f, [UIColor colorWithWhite:0 alpha:0.15].CGColor);
    [[UIColor whiteColor] setFill];
    [path fill];
    CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
    [[UIColor colorWithWhite:0.72 alpha:1.0] setStroke];
    path.lineWidth = 1.0f;
    [path stroke];
}
@end

@interface ChatViewController () <UIActionSheetDelegate, UIAlertViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, NSURLConnectionDataDelegate>
@end

@implementation ChatViewController {
    NSDictionary *_memberNames;
    NSTimeInterval _lastMessageLoad;
    BOOL _longPressAdded;
    NSInteger _selectedRow;
    BOOL _selectedIsSelf;
    BOOL _syncActive;
    NSMutableArray *_displayItems;
    NSArray *_displayItemsSnapshot;
    BOOL _shouldAutoScroll;
    AVAudioRecorder *_audioRecorder;
    NSTimer *_recordingTimer;
    UILabel *_recordingLabel;
    BOOL _sendButtonIsMicMode;
    NSString *_prevBatchToken;
    BOOL _loadingMore;
    NSInteger _loadPageSize;
    CGFloat _keyboardHeight;
    NSInteger _savePhotoButtonIndex;
    UIView *_originalTitleView;
    NSInteger _downloadButtonIndex;
    NSInteger _openInButtonIndex;
    NSMutableDictionary *_activeDownloads;
    NSInteger _recordingState; // 0=idle 1=recording 2=stopped
    NSMutableDictionary *_messagesByEventId;
    NeoSyncProcessor *_syncProcessor;
    NSTimeInterval _syncBackoff;
    NSMutableSet *_readEventIds;
    NSMutableArray *_typingUserIds;
    NSTimeInterval _lastTypingSent;
    UIView *_fieldBgView;
    UILabel *_placeholderLabel;
    CGFloat _inputBarHeight;
}

static const CGFloat kNeoInputBarBaseH = 44.0f;
static const CGFloat kNeoInputFieldMinH = 34.0f;
static const CGFloat kNeoInputFieldMaxH = 68.0f;

- (void)loadView {
    [super loadView];

    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }

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
    self.inputContainer = inputView;
    _inputBarHeight = kNeoInputBarBaseH;

    UIImageView *inputBg = [[UIImageView alloc] initWithFrame:inputView.bounds];
    inputBg.image = [[UIImage imageNamed:@"input-bar"] stretchableImageWithLeftCapWidth:10 topCapHeight:14];
    inputBg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [inputView addSubview:inputBg];

    _fieldBgView = [[NeoInputFieldView alloc] initWithFrame:CGRectMake(46, 5, w - 96, kNeoInputFieldMinH)];
    [inputView addSubview:_fieldBgView];

    self.messageField = [[UITextView alloc] initWithFrame:_fieldBgView.frame];
    self.messageField.delegate = self;
    self.messageField.font = [UIFont systemFontOfSize:15];
    self.messageField.returnKeyType = UIReturnKeyDefault;
    self.messageField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.messageField.backgroundColor = [UIColor clearColor];
    self.messageField.scrollEnabled = NO;
    self.messageField.bounces = NO;
    if (IS_IOS7_OR_LATER) {
        self.messageField.textContainerInset = UIEdgeInsetsMake(5, 8, 5, 0);
    } else {
        self.messageField.contentInset = UIEdgeInsetsMake(6, 8, 6, 0);
    }
    [inputView addSubview:self.messageField];

    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(46 + 10, 0, w - 96 - 30, kNeoInputFieldMinH)];
    _placeholderLabel.font = [UIFont systemFontOfSize:15];
    _placeholderLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    _placeholderLabel.backgroundColor = [UIColor clearColor];
    _placeholderLabel.userInteractionEnabled = NO;
    _placeholderLabel.text = @"Type a message...";
    [inputView addSubview:_placeholderLabel];

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

    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleInputBarSwipeDown)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [inputView addGestureRecognizer:swipeDown];

    self.messages = [NSMutableArray array];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(w / 2, 60);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    _lastMessageLoad = 0;
    _displayItems = [NSMutableArray array];
    _shouldAutoScroll = YES;
    _loadPageSize = 30;
    _activeDownloads = [[NSMutableDictionary alloc] init];
    _messagesByEventId = [NSMutableDictionary dictionary];
    _syncProcessor = [[NeoSyncProcessor alloc] init];
    _syncBackoff = 1.0;
    _readEventIds = [NSMutableSet set];
    _typingUserIds = [NSMutableArray array];
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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDemoModeChanged)
                                                 name:NeoDemoModeDidChangeNotification
                                               object:nil];

    if (!_longPressAdded) {
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleLongPress:)];
        lp.minimumPressDuration = 0.5;
        lp.cancelsTouchesInView = YES;
        [self.tableView addGestureRecognizer:lp];
        _longPressAdded = YES;
    }
}

- (void)handleDemoModeChanged {
    [self setupNavBar];
    [self.tableView reloadData];
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

    if (msg.failed) {
        UIActionSheet *failSheet = [[UIActionSheet alloc] init];
        failSheet.delegate = self;
        failSheet.tag = 303;
        [failSheet addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
        [failSheet addButtonWithTitle:NSLocalizedString(@"Delete", nil)];
        [failSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        failSheet.cancelButtonIndex = 2;
        [failSheet showInView:self.view];
        return;
    }

    BOOL isImage = [msg.msgType isEqualToString:@"m.image"] || [msg.body hasPrefix:@"mxc://"];
    BOOL isFile = [msg.msgType isEqualToString:@"m.file"];
    BOOL fileDownloaded = isFile && msg.cachedFileData != nil;

    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    _savePhotoButtonIndex = -1;
    _downloadButtonIndex = -1;
    _openInButtonIndex = -1;

    if (isImage) {
        sheet.tag = 300;
        [sheet addButtonWithTitle:NSLocalizedString(@"Reply", nil)];
        _savePhotoButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Save Photo", nil)];
    } else if (isFile && fileDownloaded) {
        sheet.tag = 301;
        _openInButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Open in...", nil)];
    } else if (isFile) {
        sheet.tag = 302;
        [sheet addButtonWithTitle:NSLocalizedString(@"Reply", nil)];
        _downloadButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Download", nil)];
    } else {
        sheet.tag = _selectedIsSelf ? 200 : 500;
        [sheet addButtonWithTitle:NSLocalizedString(@"Reply", nil)];
    }
    [sheet addButtonWithTitle:@"👍"];
    [sheet addButtonWithTitle:@"❤️"];
    [sheet addButtonWithTitle:@"😂"];
    [sheet addButtonWithTitle:@"😮"];
    [sheet addButtonWithTitle:NSLocalizedString(@"Custom", nil)];
    [sheet addButtonWithTitle:NSLocalizedString(@"Copy", nil)];
    [sheet addButtonWithTitle:NSLocalizedString(@"Forward", nil)];
    if (_selectedIsSelf) {
        [sheet addButtonWithTitle:NSLocalizedString(@"Edit", nil)];
        [sheet addButtonWithTitle:NSLocalizedString(@"Delete", nil)];
    }
    [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    sheet.cancelButtonIndex = [sheet numberOfButtons] - 1;

    [sheet showInView:self.view];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (_audioRecorder && _audioRecorder.recording) {
        [self cancelRecordingTapped];
    }
    [self dismissReply];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NeoDemoModeDidChangeNotification object:nil];
    [self removeSyncObservers];
    _syncActive = NO;
}

- (void)addSyncObservers {
    // The global engine (MatrixSyncManager) owns the /sync stream; this VC is a
    // consumer of the per-room batches while it is open (elementold-style).
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSyncBatch:)
                                                 name:MatrixRoomBatchNotification
                                               object:nil];
}

- (void)removeSyncObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MatrixRoomBatchNotification object:nil];
}

- (void)handleSyncBatch:(NSNotification *)notification {
    if (!self.room.roomId) return;
    NSDictionary *join = [notification userInfo][@"join"];
    if (![join isKindOfClass:[NSDictionary class]]) return;

    NSDictionary *roomData = [join objectForKey:self.room.roomId];
    if (![roomData isKindOfClass:[NSDictionary class]]) return;

    [self.room updateNameFromStateEvents:roomData[@"state"][@"events"]
                           timelineEvents:roomData[@"timeline"][@"events"]];
    [self setupNavBar];
    [self processEphemeralEvents:roomData[@"ephemeral"][@"events"]];
    [self processSyncEvents:roomData[@"timeline"][@"events"]];
}

- (void)setupNavBar {
    CGFloat navW = self.navigationController.navigationBar.frame.size.width;
    if (navW < 1) navW = 320;
    CGFloat titleW = fminf(navW * 0.65, navW - 140);

    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, titleW, 40)];
    titleView.backgroundColor = [UIColor clearColor];
    titleView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 4, titleW, 20)];
    NSString *rawTitle = [MatrixAPIClient localNameForRoomId:self.room.roomId] ?: (self.room.name ?: self.room.roomId);
    NSString *obfuscated = [[DemoModeManager sharedManager] obfuscateName:rawTitle];
    nameLabel.text = [obfuscated length] > 20 ? [[obfuscated substringToIndex:20] stringByAppendingString:@"…"] : obfuscated;
    nameLabel.font = [UIFont boldSystemFontOfSize:16];
    nameLabel.textColor = [UIColor whiteColor];
    nameLabel.backgroundColor = [UIColor clearColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [titleView addSubview:nameLabel];

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 24, titleW, 14)];
    subLabel.tag = 2001;
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
    if (alertView.tag == 888) {
        NSString *fileURL = objc_getAssociatedObject(alertView, @"fileURL");
        if (fileURL) {
            NSMutableDictionary *info = _activeDownloads[fileURL];
            [info[@"connection"] cancel];
            [_activeDownloads removeObjectForKey:fileURL];
        }
        [alertView dismissWithClickedButtonIndex:0 animated:YES];
        return;
    }

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

    NSInteger tag = sheet.tag;

    if (tag == 303) {
        if (buttonIndex == 0) {
            [self retryFailedMessage:msg];
        } else if (buttonIndex == 1) {
            [self deleteFailedMessage:msg];
        }
        return;
    }

    if (tag == 301) {
        if (buttonIndex == _openInButtonIndex) {
            [self downloadAndOpenFile:msg];
        } else {
            NSInteger emojiStart = _openInButtonIndex + 1;
            [self handleActionSheetReaction:msg buttonIndex:buttonIndex emojiStart:emojiStart isSelf:_selectedIsSelf];
        }
        return;
    }

    if (tag == 302) {
        if (buttonIndex == 0) {
            [self startReplyToMessage:msg];
            return;
        }
        if (buttonIndex == _downloadButtonIndex) {
            [self downloadAndOpenFile:msg];
            return;
        }
        NSInteger emojiStart = _downloadButtonIndex + 1;
        [self handleActionSheetReaction:msg buttonIndex:buttonIndex emojiStart:emojiStart isSelf:_selectedIsSelf];
        return;
    }

    if (tag == 300 || tag == 200 || tag == 500) {
        BOOL isImage = (tag == 300);
        BOOL isSelf = _selectedIsSelf;

        if (buttonIndex == 0) {
            [self startReplyToMessage:msg];
            return;
        }

        if (isImage && buttonIndex == _savePhotoButtonIndex) {
            [self savePhoto:msg];
            return;
        }

        NSInteger emojiStart = isImage ? 2 : 1;
        [self handleActionSheetReaction:msg buttonIndex:buttonIndex emojiStart:emojiStart isSelf:isSelf];
    }
}

- (void)handleActionSheetReaction:(MatrixMessage *)msg buttonIndex:(NSInteger)buttonIndex emojiStart:(NSInteger)emojiStart {
    [self handleActionSheetReaction:msg buttonIndex:buttonIndex emojiStart:emojiStart isSelf:NO];
}

- (void)handleActionSheetReaction:(MatrixMessage *)msg buttonIndex:(NSInteger)buttonIndex emojiStart:(NSInteger)emojiStart isSelf:(BOOL)isSelf {
    NSInteger adjIdx = buttonIndex - emojiStart;
    NSArray *emojis = @[@"👍", @"❤️", @"😂", @"😮"];

    if (adjIdx < [emojis count]) {
        [self sendReaction:emojis[adjIdx] toMessage:msg];
    } else if (adjIdx == 4) {
        [self promptCustomReactionForMessage:msg];
    } else if (adjIdx == 5) {
        [self copyMessage:msg];
    } else if (adjIdx == 6) {
        [self forwardMessage:msg];
    } else if (isSelf && adjIdx == 7) {
        [self editMessage:msg row:_selectedRow];
    } else if (isSelf && adjIdx == 8) {
        [self deleteMessage:msg row:_selectedRow];
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

- (void)forwardMessage:(MatrixMessage *)msg {
    ForwardPickerController *picker = [[ForwardPickerController alloc] init];
    picker.message = msg;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)savePhoto:(MatrixMessage *)msg {
    if ([msg.imageURL length] == 0) return;

    void (^save)(UIImage *) = ^(UIImage *img) {
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
        [NeoAlert showAlertWithTitle:nil
                            message:NSLocalizedString(@"Saved", nil)
                        cancelTitle:@"OK"
                         controller:self];
    };

    if (msg.cachedImage) {
        save(msg.cachedImage);
        return;
    }

    [[MatrixAPIClient sharedClient] downloadImageFromMXC:msg.imageURL
                                              completion:^(UIImage *img, NSError *err) {
        if (img) {
            msg.cachedImage = img;
            save(img);
        } else {
            [NeoAlert showAlertWithTitle:NSLocalizedString(@"Error", nil)
                                message:[err localizedDescription]
                            cancelTitle:@"OK"
                             controller:self];
        }
    }];
}

- (void)reactionPillTapped:(NeoReactionPillView *)pill {
    MatrixMessage *msg = objc_getAssociatedObject(pill, "msg");
    NSString *emoji = objc_getAssociatedObject(pill, "emojiKey");
    if (!msg || !emoji) return;
    [self sendReaction:emoji toMessage:msg];
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
            if (!msg.myReactions) msg.myReactions = [NSMutableDictionary dictionary];
            msg.myReactions[emoji] = @YES;
            [self reloadTableAnimatedWithAutoScroll:NO];
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
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    
    [client deleteCachedMediaForMXC:msg.imageURL];
    [client deleteCachedMediaForMXC:msg.videoURL];
    [client deleteCachedMediaForMXC:msg.videoThumbnailURL];
    [client deleteCachedMediaForMXC:msg.fileURL];
    [client deleteCachedMediaForMXC:msg.audioURL];
    
    if (msg.eventId) {
        [_messagesByEventId removeObjectForKey:msg.eventId];
    }
    
    [client redactMessage:self.room.roomId
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

- (void)startReplyToMessage:(MatrixMessage *)msg {
    self.replyToMessage = msg;

    NSString *senderName = [self displayNameForSender:msg.sender];
    if (!self.replyPreviewView) {
        CGFloat w = self.view.bounds.size.width;
        self.replyPreviewView = [[ReplyBubbleView alloc] initWithFrame:CGRectMake(0, 0, w, [ReplyBubbleView viewHeight])];
        self.replyPreviewView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _replyPreviewView.backgroundColor = [UIColor clearColor];

        self.replyCloseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.replyCloseButton setTitle:@"✕" forState:UIControlStateNormal];
        [self.replyCloseButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        self.replyCloseButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [self.replyCloseButton addTarget:self action:@selector(dismissReply) forControlEvents:UIControlEventTouchUpInside];
        [self.replyPreviewView addSubview:self.replyCloseButton];

        [self.view addSubview:self.replyPreviewView];
    }
    self.replyPreviewView.senderName = senderName;
    self.replyPreviewView.body = msg.body;
    self.replyPreviewView.outgoing = NO;
    self.replyPreviewView.hidden = NO;

    CGFloat w = self.view.bounds.size.width;
    CGFloat rpH = [ReplyBubbleView viewHeight];
    self.replyCloseButton.frame = CGRectMake(w - 28, 0, 28, rpH);

    UIView *inputToolbar = self.messageField.superview;
    CGFloat tableH = inputToolbar.frame.origin.y - rpH;
    self.tableView.frame = CGRectMake(0, 0, w, tableH);
    self.replyPreviewView.frame = CGRectMake(0, tableH, w, rpH);
    inputToolbar.frame = CGRectMake(0, tableH + rpH, w, _inputBarHeight);

    [self.messageField becomeFirstResponder];
}

- (void)dismissReply {
    if (!self.replyPreviewView || self.replyPreviewView.hidden) return;
    self.replyPreviewView.hidden = YES;
    self.replyToMessage = nil;
    [self layoutInputWithBarHeight:_inputBarHeight animated:NO];
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
    NSString *lastDayLabel = nil;

    for (MatrixMessage *msg in self.messages) {
        if (!msg.timestamp) {
            [_displayItems addObject:msg];
            continue;
        }

        NSString *dayLabel = [self dayLabelForTimestamp:msg.timestamp];
        if (!lastDayLabel || ![dayLabel isEqualToString:lastDayLabel]) {
            [_displayItems addObject:dayLabel];
            lastDayLabel = dayLabel;
        }
        [_displayItems addObject:msg];
    }
}

- (NSString *)dayLabelForTimestamp:(NSDate *)date {
    if (!date) return @"";
    time_t now = time(NULL);
    time_t t = [date timeIntervalSince1970];
    struct tm nowTm, dateTm;
    localtime_r(&now, &nowTm);
    localtime_r(&t, &dateTm);

    if (nowTm.tm_year == dateTm.tm_year && nowTm.tm_yday == dateTm.tm_yday) {
        return NSLocalizedString(@"Today", nil);
    }
    if (nowTm.tm_year == dateTm.tm_year && nowTm.tm_yday - dateTm.tm_yday == 1) {
        return NSLocalizedString(@"Yesterday", nil);
    }
    if (nowTm.tm_year == dateTm.tm_year) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"EEEE, MMMM d";
        return [fmt stringFromDate:date];
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"EEEE, MMMM d, yyyy";
    return [fmt stringFromDate:date];
}

- (void)loadMessages {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _lastMessageLoad < 5.0 && [self.messages count] > 0) return;

    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSArray *cached = [client cachedMessagesForRoom:self.room.roomId];
    if (cached && [self.messages count] == 0) {
        [self.messages addObjectsFromArray:cached];
        [self rebuildMessagesByEventId];
        [self buildDisplayItems];
        _displayItemsSnapshot = [_displayItems copy];
        [self.tableView reloadData];
        [self scrollToBottom];
    }

    [self.spinner startAnimating];
    [client getRoomMessages:self.room.roomId completion:^(NSDictionary *response, NSError *error) {
        [self.spinner stopAnimating];
        if (error) return;
        NSMutableArray *pendingLocal = [NSMutableArray array];
        for (MatrixMessage *m in self.messages) {
            if ([m.eventId hasPrefix:@"local_"]) {
                [pendingLocal addObject:m];
            }
        }
        [self.messages removeAllObjects];
        NSArray *chunk = response[@"chunk"];
        _prevBatchToken = response[@"end"];
        NSMutableArray *newMessages = [NSMutableArray array];
        NSMutableDictionary *msgByEventId = [NSMutableDictionary dictionary];
        for (NSDictionary *evt in [chunk reverseObjectEnumerator]) {
            NSString *type = evt[@"type"];

            if ([type isEqualToString:@"m.room.message"] || [type isEqualToString:@"m.room.encrypted"]) {
                NSDictionary *relatesto = evt[@"content"][@"m.relates_to"];
                if ([relatesto[@"rel_type"] isEqualToString:@"m.replace"]) {
                    NSString *targetId = relatesto[@"event_id"];
                    NSString *newBody = evt[@"content"][@"m.new_content"][@"body"];
                    MatrixMessage *targetMsg = [msgByEventId objectForKey:targetId];
                    if (targetMsg && newBody) {
                        targetMsg.body = newBody;
                    } else if (targetId && newBody) {
                        [_syncProcessor.pendingEdits setObject:newBody forKey:targetId];
                    }
                    continue;
                }

                MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:evt
                                                                        roomId:self.room.roomId];
                [newMessages addObject:msg];
                if (msg.eventId) [msgByEventId setObject:msg forKey:msg.eventId];
            }

            if ([type isEqualToString:@"m.room.redaction"]) {
                NSString *redactedId = evt[@"redacts"];
                if (!redactedId && [evt[@"content"] isKindOfClass:[NSDictionary class]]) {
                    redactedId = evt[@"content"][@"redacts"];
                }
                if (redactedId) {
                    MatrixMessage *target = [msgByEventId objectForKey:redactedId];
                    if (target) {
                        target.isRedacted = YES;
                        target.body = NSLocalizedString(@"Deleted message", nil);
                    }
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
        if ([pendingLocal count] > 0) {
            [self.messages addObjectsFromArray:pendingLocal];
        }
        [self trimMessagesToLimit];
        [self rebuildMessagesByEventId];
        [self resolveAllReplies];
        [client cacheMessages:[self.messages copy] forRoom:self.room.roomId];
        [client saveMessageEvents:response[@"chunk"] forRoom:self.room.roomId];
        BOOL firstLoad = (_lastMessageLoad == 0);
        _lastMessageLoad = now;
        [self buildDisplayItems];
        _displayItemsSnapshot = [_displayItems copy];
        [self.tableView reloadData];
        // First load: always bottom. Refresh: only if near bottom
        CGFloat nearBottom = self.tableView.contentOffset.y + self.tableView.bounds.size.height;
        CGFloat threshold = self.tableView.contentSize.height - 60;
        if (firstLoad || nearBottom >= threshold) {
            [self scrollToBottom];
        }
    }];
}

- (void)loadMoreMessages {
    if (_loadingMore || !_prevBatchToken) return;
    _loadingMore = YES;
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSString *encodedId = NeoURLEncode(self.room.roomId);
    NSString *encodedFrom = NeoURLEncode(_prevBatchToken);
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/messages?dir=b&limit=%d&from=%@",
                      encodedId, (int)_loadPageSize, encodedFrom];
    NSMutableURLRequest *req = [client requestWithPath:path method:@"GET"];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        _loadingMore = NO;
        if (err) return;
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![response isKindOfClass:[NSDictionary class]]) return;
        NSArray *chunk = response[@"chunk"];
        if ([chunk count] == 0) {
            _prevBatchToken = nil;
            return;
        }
        _prevBatchToken = response[@"end"];
        NSMutableArray *olderMessages = [NSMutableArray array];
        for (NSDictionary *evt in [chunk reverseObjectEnumerator]) {
            NSString *type = evt[@"type"];
            if (![type isEqualToString:@"m.room.message"] && ![type isEqualToString:@"m.room.encrypted"]) continue;
            NSString *eid = evt[@"event_id"];
            if ([eid isKindOfClass:[NSString class]] && [_messagesByEventId objectForKey:eid]) continue;
            NSDictionary *relatesto = evt[@"content"][@"m.relates_to"];
            if ([relatesto[@"rel_type"] isEqualToString:@"m.replace"]) {
                NSString *targetId = relatesto[@"event_id"];
                NSString *newBody = evt[@"content"][@"m.new_content"][@"body"];
                if (targetId && newBody) {
                    MatrixMessage *target = [targetId isKindOfClass:[NSString class]] ? [_messagesByEventId objectForKey:targetId] : nil;
                    if (target) {
                        target.body = newBody;
                    } else if ([targetId isKindOfClass:[NSString class]]) {
                        [_syncProcessor.pendingEdits setObject:newBody forKey:targetId];
                    }
                }
                continue;
            }
            MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:evt
                                                                    roomId:self.room.roomId];
            [olderMessages addObject:msg];
        }
        if ([olderMessages count] == 0) return;
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [olderMessages count])];
        [self.messages insertObjects:olderMessages atIndexes:indexes];
        [self rebuildMessagesByEventId];
        [client cacheMessages:[self.messages copy] forRoom:self.room.roomId];
        [self resolveAllReplies];
        CGFloat oldOffset = self.tableView.contentSize.height;
        [self buildDisplayItems];
        _displayItemsSnapshot = [_displayItems copy];
        [self.tableView reloadData];
        CGFloat heightGain = self.tableView.contentSize.height - oldOffset;
        if (heightGain > 0) {
            self.tableView.contentOffset = CGPointMake(0, heightGain);
        }
    }];
}

- (void)handleInputBarSwipeDown {
    if ([self.messageField isFirstResponder]) {
        [self.messageField resignFirstResponder];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y < -30 && !_loadingMore && _prevBatchToken) {
        [self loadMoreMessages];
    }
}

- (void)processEphemeralEvents:(NSArray *)events {
    if (![events isKindOfClass:[NSArray class]] || [events count] == 0) return;
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    BOOL typingChanged = NO;
    BOOL receiptsChanged = NO;

    for (NSDictionary *evt in events) {
        if (![evt isKindOfClass:[NSDictionary class]]) continue;
        NSString *type = evt[@"type"];

        if ([type isEqualToString:@"m.typing"]) {
            NSArray *userIds = evt[@"content"][@"user_ids"];
            if (![userIds isKindOfClass:[NSArray class]]) continue;
            NSMutableArray *others = [NSMutableArray array];
            for (NSString *uid in userIds) {
                if ([uid isKindOfClass:[NSString class]] && ![uid isEqualToString:myId]) {
                    [others addObject:uid];
                }
            }
            if (![others isEqualToArray:_typingUserIds]) {
                _typingUserIds = others;
                typingChanged = YES;
            }
        }

        if ([type isEqualToString:@"m.receipt"]) {
            NSDictionary *content = evt[@"content"];
            if (![content isKindOfClass:[NSDictionary class]]) continue;
            for (NSString *eventId in content) {
                if (![eventId isKindOfClass:[NSString class]]) continue;
                NSDictionary *receiptTypes = content[eventId];
                if (![receiptTypes isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *readReceipts = receiptTypes[@"m.read"];
                if (![readReceipts isKindOfClass:[NSDictionary class]]) continue;
                for (NSString *uid in readReceipts) {
                    if ([uid isKindOfClass:[NSString class]] && ![uid isEqualToString:myId]) {
                        if (![_readEventIds containsObject:eventId]) {
                            [_readEventIds addObject:eventId];
                            receiptsChanged = YES;
                        }
                        break;
                    }
                }
            }
        }
    }

    if (typingChanged) {
        [self updateTypingIndicator];
    }
    if (receiptsChanged) {
        [self markReadMessages];
        [self.tableView reloadData];
    }
}

- (void)updateTypingIndicator {
    if (_recordingState != 0) return;
    // NSString *baseName = [MatrixAPIClient localNameForRoomId:self.room.roomId] ?: (self.room.name ?: self.room.roomId);
    UIView *titleView = self.navigationItem.titleView;
    UILabel *subLabel = (UILabel *)[titleView viewWithTag:2001];
    if (!subLabel) return;

    if ([_typingUserIds count] == 0) {
        NSInteger count = [self.room memberCount];
        subLabel.text = count > 0 ? [NSString stringWithFormat:NSLocalizedString(@"%d members", nil), (int)count] : @"";
    } else if ([_typingUserIds count] == 1) {
        subLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ is typing…", nil),
                         [self displayNameForSender:[_typingUserIds objectAtIndex:0]]];
    } else {
        subLabel.text = NSLocalizedString(@"Several people are typing…", nil);
    }
}

- (void)processSyncEvents:(NSArray *)events {
    if ([events count] == 0) return;

    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    BOOL changed = [_syncProcessor applyEvents:events
                                      messages:self.messages
                             messagesByEventId:_messagesByEventId
                                          room:self.room
                                      myUserId:myId
                                 roomNameChanged:^(NSString *newName) {
        (void)newName;
        [self setupNavBar];
    }];

    if (changed) {
        [self trimMessagesToLimit];
        [self markReadMessages];
        [[MatrixAPIClient sharedClient] cacheMessages:[self.messages copy] forRoom:self.room.roomId];
        [self resolveAllReplies];
        [self reloadTableAnimatedWithAutoScroll:_shouldAutoScroll];
    }
}

- (void)trimMessagesToLimit {
    NSInteger limit = [[NSUserDefaults standardUserDefaults] integerForKey:@"neo_message_limit"];
    if (limit <= 0) return;
    NSMutableArray *msgs = self.messages;
    if ([msgs count] <= limit) return;
    [msgs removeObjectsInRange:NSMakeRange(0, [msgs count] - limit)];
    [self rebuildMessagesByEventId];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSInteger limit = [[NSUserDefaults standardUserDefaults] integerForKey:@"neo_message_limit"];
    if (limit > 0 && [self.messages count] > limit) {
        [self trimMessagesToLimit];
        [self buildDisplayItems];
        _displayItemsSnapshot = [_displayItems copy];
        [self.tableView reloadData];
    }
}

- (NSArray *)displayAdaptersForItems:(NSArray *)items {
    NSMutableArray *adapters = [NSMutableArray arrayWithCapacity:[items count]];
    for (id item in items) {
        NeoDisplayAdapter *a = [[NeoDisplayAdapter alloc] init];
        if ([item isKindOfClass:[NSString class]]) {
            a.ident = [NSString stringWithFormat:@"sep:%@", item];
        } else if ([item isKindOfClass:[MatrixMessage class]]) {
            a.ident = [(MatrixMessage *)item eventId] ?: @"";
        } else {
            a.ident = [NSString stringWithFormat:@"obj:%p", item];
        }
        [adapters addObject:a];
    }
    return adapters;
}

- (void)reloadTableAnimatedWithAutoScroll:(BOOL)autoScroll {
    NSArray *oldItems = _displayItemsSnapshot;
    [self buildDisplayItems];
    _displayItemsSnapshot = [_displayItems copy];

    if ([oldItems count] == 0 || [self.tableView numberOfSections] == 0) {
        [self.tableView reloadData];
        if (autoScroll) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self scrollToBottom];
            });
        }
        return;
    }

    NSArray *oldAdapters = [self displayAdaptersForItems:oldItems];
    NSArray *newAdapters = [self displayAdaptersForItems:_displayItems];

    __block NSInteger totalOps = 0;
    __block NSMutableArray *deleteIPs = [NSMutableArray array];
    __block NSMutableArray *insertIPs = [NSMutableArray array];

    [TGTableDeltaUpdater replaceItemsInTable:oldAdapters
                                withNewItems:newAdapters
                           singleUpdateBlock:^(NSArray<TGTableAlignment *> *deletes, NSArray<TGTableAlignment *> *inserts) {
        for (TGTableAlignment *a in deletes) {
            totalOps += a.len;
            for (NSInteger i = 0; i < a.len; i++) {
                [deleteIPs addObject:[NSIndexPath indexPathForRow:a.pos + i inSection:0]];
            }
        }
        for (TGTableAlignment *a in inserts) {
            totalOps += a.len;
            for (NSInteger i = 0; i < a.len; i++) {
                [insertIPs addObject:[NSIndexPath indexPathForRow:a.pos + i inSection:0]];
            }
        }
    }];

    if (totalOps == 0) {
        // Same rows, content may have changed (edits, reactions, acks)
        [self.tableView reloadData];
        return;
    }

    if (totalOps > 60) {
        [self.tableView reloadData];
        if (autoScroll) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self scrollToBottom];
            });
        }
        return;
    }

    [self.tableView beginUpdates];
    if ([deleteIPs count] > 0) {
        [self.tableView deleteRowsAtIndexPaths:deleteIPs withRowAnimation:UITableViewRowAnimationFade];
    }
    if ([insertIPs count] > 0) {
        [self.tableView insertRowsAtIndexPaths:insertIPs withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.tableView endUpdates];

    if (autoScroll) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottom];
        });
    }
}

- (void)markReadMessages {
    if ([_readEventIds count] == 0) return;
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    for (MatrixMessage *msg in self.messages) {
        if (!msg.readByOther && myId && [msg.sender isEqualToString:myId] &&
            msg.eventId && [_readEventIds containsObject:msg.eventId]) {
            msg.readByOther = YES;
        }
    }
}

- (void)scrollToBottom {
    NSInteger lastRow = [_displayItems count] - 1;
    if (lastRow < 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:lastRow inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}

- (void)resolveAllReplies {
    NSMutableDictionary *byId = [NSMutableDictionary dictionaryWithCapacity:[self.messages count]];
    for (MatrixMessage *m in self.messages) {
        if (m.eventId) [byId setObject:m forKey:m.eventId];
    }
    for (MatrixMessage *msg in self.messages) {
        if (msg.replyToEventId && [msg.replyToEventId length] > 0 && !msg.replyToBody) {
            [msg resolveReplyFromDict:byId];
        }
    }
}

- (void)rebuildMessagesByEventId {
    [_messagesByEventId removeAllObjects];
    NSMutableDictionary *pending = _syncProcessor.pendingEdits;
    for (MatrixMessage *m in self.messages) {
        if ([m.eventId length] == 0) continue;
        [_messagesByEventId setObject:m forKey:m.eventId];
        NSString *pendingBody = [pending objectForKey:m.eventId];
        if (pendingBody) {
            m.body = pendingBody;
            [pending removeObjectForKey:m.eventId];
        }
    }
}

#pragma mark - Optimistic sends

- (NSString *)pendingUploadsDir {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
                     stringByAppendingPathComponent:@"PendingUploads"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return dir;
}

- (NSString *)savePendingData:(NSData *)data extension:(NSString *)ext {
    if (!data) return nil;
    NSString *name = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], ext];
    NSString *path = [[self pendingUploadsDir] stringByAppendingPathComponent:name];
    [data writeToFile:path atomically:NO];
    return path;
}

- (void)deletePendingFileForMessage:(MatrixMessage *)msg {
    if ([msg.pendingLocalPath length] > 0) {
        [[NSFileManager defaultManager] removeItemAtPath:msg.pendingLocalPath error:nil];
        msg.pendingLocalPath = nil;
    }
}

- (void)finalizeLocalMessage:(MatrixMessage *)localMsg withEventId:(NSString *)realEventId {
    MatrixMessage *synced = [realEventId isKindOfClass:[NSString class]] ? [_messagesByEventId objectForKey:realEventId] : nil;
    if (synced && synced != localMsg) {
        // Sync already delivered the real message — drop optimistic copy
        [self.messages removeObject:localMsg];
        [_messagesByEventId removeObjectForKey:localMsg.eventId];
    } else {
        [_messagesByEventId removeObjectForKey:localMsg.eventId];
        localMsg.eventId = realEventId;
        [_messagesByEventId setObject:localMsg forKey:realEventId];
        if (![self.messages containsObject:localMsg]) {
            [self.messages addObject:localMsg];
        }
    }
    localMsg.uploading = NO;
    localMsg.failed = NO;
    [self deletePendingFileForMessage:localMsg];
    [[MatrixAPIClient sharedClient] cacheMessages:[self.messages copy] forRoom:self.room.roomId];
    [self reloadTableAnimatedWithAutoScroll:_shouldAutoScroll];
}

- (void)failLocalMessage:(MatrixMessage *)msg {
    msg.uploading = NO;
    msg.failed = YES;
    [[MatrixAPIClient sharedClient] cacheMessages:[self.messages copy] forRoom:self.room.roomId];
    [self reloadTableAnimatedWithAutoScroll:NO];
}

- (void)dispatchSendForMessage:(MatrixMessage *)msg {
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSString *type = msg.msgType;

    if ([type isEqualToString:@"m.text"]) {
        void (^completion)(NSDictionary *, NSError *) = ^(NSDictionary *resp, NSError *err) {
            NSString *eid = [resp isKindOfClass:[NSDictionary class]] ? resp[@"event_id"] : nil;
            if (err || ![eid isKindOfClass:[NSString class]]) { [self failLocalMessage:msg]; return; }
            [self finalizeLocalMessage:msg withEventId:eid];
        };
        if ([msg.replyToEventId length] > 0) {
            [client sendReply:msg.body roomId:self.room.roomId replyToEventId:msg.replyToEventId completion:completion];
        } else {
            [client sendMessage:msg.body roomId:self.room.roomId completion:completion];
        }
        return;
    }

    if ([type isEqualToString:@"m.image"]) {
        NSString *filePath = msg.pendingLocalPath;
        if ([filePath length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            if (msg.cachedImage) {
                NSData *data = UIImageJPEGRepresentation(msg.cachedImage, 0.85);
                if (data) {
                    filePath = [self savePendingData:data extension:@"jpg"];
                    msg.pendingLocalPath = filePath;
                }
            }
        }
        if ([filePath length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            NSLog(@"[Neo] Cannot send image: no image file found");
            [self failLocalMessage:msg];
            return;
        }

        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        NSInteger size = [attrs[NSFileSize] integerValue];
        CGFloat w = msg.imageWidth > 0 ? msg.imageWidth : (msg.cachedImage ? msg.cachedImage.size.width : 0);
        CGFloat h = msg.imageHeight > 0 ? msg.imageHeight : (msg.cachedImage ? msg.cachedImage.size.height : 0);

        [client uploadFileAtPath:filePath
                        mimeType:@"image/jpeg"
                        filename:@"image.jpg"
                        progress:nil
                      completion:^(NSString *contentURI, NSError *err) {
            if (err || !contentURI) {
                NSLog(@"[Neo] Image upload failed: %@", err);
                [self failLocalMessage:msg];
                return;
            }
            msg.imageURL = contentURI;
            [client sendImageMessage:contentURI
                              roomId:self.room.roomId
                             caption:msg.body
                               width:w
                              height:h
                                size:size
                          completion:^(NSDictionary *resp, NSError *sendErr) {
                NSString *eid = [resp isKindOfClass:[NSDictionary class]] ? resp[@"event_id"] : nil;
                if (sendErr || ![eid isKindOfClass:[NSString class]]) {
                    NSLog(@"[Neo] Send image message event failed: %@", sendErr);
                    [self failLocalMessage:msg];
                    return;
                }
                [self finalizeLocalMessage:msg withEventId:eid];
            }];
        }];
        return;
    }

    if ([type isEqualToString:@"m.audio"]) {
        NSString *filePath = msg.pendingLocalPath;
        if ([filePath length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            [self failLocalMessage:msg];
            return;
        }
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        NSInteger size = [attrs[NSFileSize] integerValue];

        [client uploadFileAtPath:filePath
                        mimeType:@"audio/mp4"
                        filename:@"voice.m4a"
                        progress:nil
                      completion:^(NSString *contentURI, NSError *err) {
            if (err || !contentURI) {
                NSLog(@"[Neo] Audio upload failed: %@", err);
                [self failLocalMessage:msg];
                return;
            }
            msg.audioURL = contentURI;
            [client sendAudioMessage:contentURI
                              roomId:self.room.roomId
                            filename:NSLocalizedString(@"Voice message", nil)
                            mimeType:@"audio/mp4"
                            duration:[msg.audioDuration integerValue]
                                size:size
                          completion:^(NSDictionary *resp, NSError *sendErr) {
                NSString *eid = [resp isKindOfClass:[NSDictionary class]] ? resp[@"event_id"] : nil;
                if (sendErr || ![eid isKindOfClass:[NSString class]]) {
                    NSLog(@"[Neo] Send audio message event failed: %@", sendErr);
                    [self failLocalMessage:msg];
                    return;
                }
                [self finalizeLocalMessage:msg withEventId:eid];
            }];
        }];
        return;
    }

    if ([type isEqualToString:@"m.video"]) {
        NSString *filePath = msg.pendingLocalPath;
        if ([filePath length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            NSLog(@"[Neo] Cannot send video: no pending file at %@", msg.pendingLocalPath);
            [self failLocalMessage:msg];
            return;
        }
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        NSInteger size = [attrs[NSFileSize] integerValue];

        [client uploadFileAtPath:filePath
                        mimeType:@"video/mp4"
                        filename:@"video.mp4"
                        progress:nil
                      completion:^(NSString *contentURI, NSError *err) {
            if (err || !contentURI) {
                NSLog(@"[Neo] Video upload failed: %@", err);
                [self failLocalMessage:msg];
                return;
            }
            msg.videoURL = contentURI;
            void (^sendWithThumb)(NSString *) = ^(NSString *thumbURI) {
                [client sendVideoMessage:contentURI
                                  roomId:self.room.roomId
                               thumbnail:thumbURI
                                duration:[msg.videoDuration integerValue]
                                   width:msg.videoWidth
                                  height:msg.videoHeight
                                    size:size
                              completion:^(NSDictionary *resp, NSError *sendErr) {
                    NSString *eid = [resp isKindOfClass:[NSDictionary class]] ? resp[@"event_id"] : nil;
                    if (sendErr || ![eid isKindOfClass:[NSString class]]) {
                        NSLog(@"[Neo] Send video message event failed: %@", sendErr);
                        [self failLocalMessage:msg];
                        return;
                    }
                    msg.videoThumbnailURL = thumbURI;
                    [self finalizeLocalMessage:msg withEventId:eid];
                }];
            };
            UIImage *thumb = msg.cachedVideoThumbnail;
            if (!thumb && [msg.pendingLocalPath length] > 0) {
                AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:msg.pendingLocalPath]];
                AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
                gen.appliesPreferredTrackTransform = YES;
                gen.maximumSize = CGSizeMake(480, 480);
                CGImageRef tRef = [gen copyCGImageAtTime:CMTimeMake(1, 1) actualTime:NULL error:nil];
                if (tRef) {
                    thumb = [UIImage imageWithCGImage:tRef];
                    CGImageRelease(tRef);
                    msg.cachedVideoThumbnail = thumb;
                }
            }
            if (thumb) {
                NSData *thumbData = UIImageJPEGRepresentation(thumb, 0.7);
                [client uploadData:thumbData mimeType:@"image/jpeg" filename:@"video_thumb.jpg" completion:^(NSString *thumbURI, NSError *thumbErr) {
                    sendWithThumb(thumbURI);
                }];
            } else {
                sendWithThumb(nil);
            }
        }];
        return;
    }

    [self failLocalMessage:msg];
}

- (void)retryFailedMessage:(MatrixMessage *)msg {
    msg.failed = NO;
    msg.uploading = YES;
    [self reloadTableAnimatedWithAutoScroll:NO];
    [self dispatchSendForMessage:msg];
}

- (void)deleteFailedMessage:(MatrixMessage *)msg {
    [self.messages removeObject:msg];
    if ([msg.eventId length] > 0) [_messagesByEventId removeObjectForKey:msg.eventId];
    [self deletePendingFileForMessage:msg];
    [[MatrixAPIClient sharedClient] cacheMessages:[self.messages copy] forRoom:self.room.roomId];
    [self reloadTableAnimatedWithAutoScroll:NO];
}

- (NSString *)displayNameForSender:(NSString *)sender {
    NSDictionary *info = [_memberNames objectForKey:sender];
    NSString *resolvedName = nil;
    if (info) {
        NSString *name = info[@"displayname"];
        if ([name length] > 0) resolvedName = name;
    }
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    if ([sender isEqualToString:myId]) return @"You";
    if (!resolvedName) {
        NSRange colon = [sender rangeOfString:@":"];
        if (colon.location != NSNotFound) {
            NSString *localpart = [sender substringToIndex:colon.location];
            resolvedName = [localpart hasPrefix:@"@"] ? [localpart substringFromIndex:1] : localpart;
        } else {
            resolvedName = sender;
        }
    }
    return [[DemoModeManager sharedManager] obfuscateName:resolvedName];
}

- (void)playSentSound {
    static SystemSoundID sentSound = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"sent" withExtension:@"caf"];
        if (url) AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &sentSound);
    });
    if (sentSound) AudioServicesPlaySystemSound(sentSound);
}

- (void)sendTapped {
    NSString *text = self.messageField.text;
    if ([text length] == 0) return;

    self.messageField.text = @"";
    [self updateSendButtonAppearance];
    [self updatePlaceholderVisibility];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateInputBarSize];
    });
    [self.messageField resignFirstResponder];

    [[MatrixAPIClient sharedClient] sendTyping:NO roomId:self.room.roomId completion:nil];

    MatrixMessage *localMsg = [[MatrixMessage alloc] init];
    localMsg.eventId = [NSString stringWithFormat:@"local_%@", [[NSUUID UUID] UUIDString]];
    localMsg.sender = [[MatrixAPIClient sharedClient] userId];
    localMsg.body = text;
    localMsg.msgType = @"m.text";
    localMsg.roomId = self.room.roomId;
    localMsg.timestamp = [NSDate date];
    if (self.replyToMessage) {
        localMsg.replyToEventId = self.replyToMessage.eventId;
        localMsg.replyToSender = self.replyToMessage.sender;
        localMsg.replyToBody = self.replyToMessage.body;
    }
    [self.messages addObject:localMsg];
    [_messagesByEventId setObject:localMsg forKey:localMsg.eventId];
    [self dismissReply];
    [self reloadTableAnimatedWithAutoScroll:YES];
    [self playSentSound];

    [self dispatchSendForMessage:localMsg];
}

#pragma mark - Audio Recording

- (void)startRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100.0f,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
    };

    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.m4a"];
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

    _originalTitleView = self.navigationItem.titleView;

    CGFloat navW = self.navigationController.navigationBar.frame.size.width;
    if (navW < 1) navW = 320;
    UIView *recordingNavView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
    recordingNavView.backgroundColor = [UIColor clearColor];

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 12, 13, 13)];
    icon.image = [UIImage imageNamed:@"record"];
    [recordingNavView addSubview:icon];

    UILabel *timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 6, 100, 28)];
    timerLabel.tag = 999;
    timerLabel.font = [UIFont boldSystemFontOfSize:14];
    timerLabel.textColor = [UIColor redColor];
    timerLabel.backgroundColor = [UIColor clearColor];
    timerLabel.text = @"0:00";
    [recordingNavView addSubview:timerLabel];

    self.navigationItem.titleView = recordingNavView;

    _recordingLabel.hidden = YES;
    [self setInputEditingHidden:YES];

    _recordingState = 1;
    [self updateRecordingButtons];

    _recordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateRecordingTimer) userInfo:nil repeats:YES];
}

- (void)updateRecordingButtons {
    UIButton *leftBtn = (UIButton *)[self.inputContainer viewWithTag:93];
    UIButton *rightBtn = self.sendButton;

    if (_recordingState == 1) {
        // Recording: left = cancel (x), right = stop (record icon)
        [leftBtn setImage:nil forState:UIControlStateNormal];
        [leftBtn setTitle:@"✕" forState:UIControlStateNormal];
        [leftBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        leftBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [leftBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [leftBtn addTarget:self action:@selector(cancelRecordingTapped) forControlEvents:UIControlEventTouchUpInside];

        [rightBtn setImage:[UIImage imageNamed:@"record"] forState:UIControlStateNormal];
        [rightBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [rightBtn addTarget:self action:@selector(stopRecordingTapped) forControlEvents:UIControlEventTouchUpInside];
    } else if (_recordingState == 2) {
        // Stopped: left = cancel, right = send
        [rightBtn setImage:[UIImage imageNamed:@"send"] forState:UIControlStateNormal];
        [rightBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [rightBtn addTarget:self action:@selector(sendRecordingTapped) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)resetRecordingButtons {
    UIButton *leftBtn = (UIButton *)[self.inputContainer viewWithTag:93];
    [leftBtn setImage:[UIImage imageNamed:@"PhotoButton"] forState:UIControlStateNormal];
    [leftBtn setImage:[UIImage imageNamed:@"PhotoButtonPressed"] forState:UIControlStateHighlighted];
    [leftBtn setTitle:nil forState:UIControlStateNormal];
    [leftBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [leftBtn addTarget:self action:@selector(cameraTapped) forControlEvents:UIControlEventTouchUpInside];

    _sendButtonIsMicMode = NO;
    [self updateSendButtonAppearance];
    _recordingState = 0;
}

- (void)cancelRecordingTapped {
    [_recordingTimer invalidate];
    _recordingTimer = nil;
    if (_originalTitleView) {
        self.navigationItem.titleView = _originalTitleView;
        _originalTitleView = nil;
    }
    _audioRecorder = nil;
    _recordingLabel.hidden = YES;
    [self setInputEditingHidden:NO];
    [self resetRecordingButtons];
}

- (void)stopRecordingTapped {
    [_audioRecorder stop];
    _recordingState = 2;
    [self updateRecordingButtons];
}

- (void)sendRecordingTapped {
    [_recordingTimer invalidate];
    _recordingTimer = nil;
    if (_originalTitleView) {
        self.navigationItem.titleView = _originalTitleView;
        _originalTitleView = nil;
    }
    _recordingLabel.hidden = YES;
    [self setInputEditingHidden:NO];

    NSTimeInterval duration = _audioRecorder.currentTime;
    NSURL *url = _audioRecorder.url;
    NSData *audioData = [NSData dataWithContentsOfURL:url];
    _audioRecorder = nil;

    [self resetRecordingButtons];

    if (audioData) {
        [self uploadAndSendAudio:audioData duration:duration];
    }
}

- (void)stopRecordingAndSend:(BOOL)shouldSend {
    if (!_audioRecorder) return;

    [_audioRecorder stop];

    if (!shouldSend) return;

    [_recordingTimer invalidate];
    _recordingTimer = nil;

    if (_originalTitleView) {
        self.navigationItem.titleView = _originalTitleView;
        _originalTitleView = nil;
    }

    _recordingLabel.hidden = YES;
    [self setInputEditingHidden:NO];

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
        NSString *txt = [NSString stringWithFormat:@"%d:%02d", (int)t / 60, (int)t % 60];
        UILabel *navLabel = (UILabel *)[self.navigationItem.titleView viewWithTag:999];
        if (navLabel) navLabel.text = txt;
        _recordingLabel.text = txt;
    }
}

- (void)dealloc {
    [_recordingTimer invalidate];
    _recordingTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)uploadAndSendAudio:(NSData *)audioData duration:(NSTimeInterval)duration {
    if (!audioData) return;

    MatrixMessage *localMsg = [[MatrixMessage alloc] init];
    localMsg.eventId = [NSString stringWithFormat:@"local_%@", [[NSUUID UUID] UUIDString]];
    localMsg.sender = [[MatrixAPIClient sharedClient] userId];
    localMsg.body = @"🎤 Voice message";
    localMsg.msgType = @"m.audio";
    localMsg.roomId = self.room.roomId;
    localMsg.timestamp = [NSDate date];
    localMsg.audioDuration = @((NSInteger)(duration * 1000));
    localMsg.uploading = YES;
    localMsg.pendingLocalPath = [self savePendingData:audioData extension:@"m4a"];
    [self.messages addObject:localMsg];
    [_messagesByEventId setObject:localMsg forKey:localMsg.eventId];
    [self reloadTableAnimatedWithAutoScroll:YES];

    [self dispatchSendForMessage:localMsg];
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

- (void)textViewDidChange:(UITextView *)textView {
    [self updateSendButtonAppearance];
    [self updatePlaceholderVisibility];

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if ([self.messageField.text length] > 0 && now - _lastTypingSent > 10.0) {
        _lastTypingSent = now;
        [[MatrixAPIClient sharedClient] sendTyping:YES roomId:self.room.roomId completion:nil];
    }
    self.messageField.scrollEnabled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateInputBarSize];
    });
}

- (void)setInputEditingHidden:(BOOL)hidden {
    self.messageField.hidden = hidden;
    _fieldBgView.hidden = hidden;
    if (hidden) {
        _placeholderLabel.hidden = YES;
    } else {
        [self updatePlaceholderVisibility];
    }
}

- (void)updatePlaceholderVisibility {
    _placeholderLabel.hidden = ([self.messageField.text length] > 0);
}

- (void)micTouchDown {
    // recording starts on touch up via micTouchUpInside
}

- (void)micTouchUpInside {
    [self startRecording];
}

- (void)micTouchUpOutside {
    // cancelled
}

- (UIImage *)resizeImageForUpload:(UIImage *)image {
    CGFloat maxDim = 2560.0f;
    CGSize size = image.size;
    CGFloat width = size.width;
    CGFloat height = size.height;

    if (width <= maxDim && height <= maxDim && image.imageOrientation == UIImageOrientationUp) {
        return image;
    }

    CGFloat ratio = 1.0f;
    if (width > maxDim || height > maxDim) {
        ratio = MIN(maxDim / width, maxDim / height);
    }
    CGSize newSize = CGSizeMake(roundf(width * ratio), roundf(height * ratio));

    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0f);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resized ?: image;
}

- (void)compressAndSaveVideoAtURL:(NSURL *)videoURL completion:(void(^)(NSString *outputPath, CGSize naturalSize, NSTimeInterval duration, UIImage *thumbnail))completion {
    AVAsset *asset = [AVAsset assetWithURL:videoURL];

    // Extract natural size taking preferredTransform into account
    CGFloat w = 0, h = 0;
    if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0) {
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo][0];
        CGSize size = track.naturalSize;
        CGAffineTransform t = track.preferredTransform;
        if (t.a == 0 && (t.b == 1.0 || t.b == -1.0)) {
            w = size.height;
            h = size.width;
        } else {
            w = size.width;
            h = size.height;
        }
    }
    NSTimeInterval duration = CMTimeGetSeconds(asset.duration);

    // Generate lightweight thumbnail
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    gen.maximumSize = CGSizeMake(480, 480);
    CMTime thumbTime = CMTimeMakeWithSeconds(MIN(1.0, duration * 0.5), 600);
    CGImageRef thumbRef = [gen copyCGImageAtTime:thumbTime actualTime:NULL error:nil];
    UIImage *thumbnail = thumbRef ? [UIImage imageWithCGImage:thumbRef] : nil;
    if (thumbRef) CGImageRelease(thumbRef);

    NSString *pendingName = [NSString stringWithFormat:@"%@.mp4", [[NSUUID UUID] UUIDString]];
    NSString *outputPath = [[self pendingUploadsDir] stringByAppendingPathComponent:pendingName];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    NSString *preset = nil;
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    if (exporter && [exporter.supportedFileTypes containsObject:AVFileTypeMPEG4]) {
        preset = AVAssetExportPresetPassthrough;
    } else {
        exporter = nil;
        if ([compatiblePresets containsObject:AVAssetExportPresetMediumQuality]) {
            preset = AVAssetExportPresetMediumQuality;
        } else if ([compatiblePresets containsObject:AVAssetExportPreset640x480]) {
            preset = AVAssetExportPreset640x480;
        }
        if (preset) {
            exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
        }
    }

    if (exporter) {
        exporter.outputURL = outputURL;
        exporter.outputFileType = AVFileTypeMPEG4;
        exporter.shouldOptimizeForNetworkUse = YES;

        [exporter exportAsynchronouslyWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (exporter.status == AVAssetExportSessionStatusCompleted && [[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
                    AVAsset *exportedAsset = [AVAsset assetWithURL:outputURL];
                    CGFloat expW = w, expH = h;
                    if ([[exportedAsset tracksWithMediaType:AVMediaTypeVideo] count] > 0) {
                        AVAssetTrack *expTrack = [exportedAsset tracksWithMediaType:AVMediaTypeVideo][0];
                        CGSize expSize = expTrack.naturalSize;
                        CGAffineTransform t = expTrack.preferredTransform;
                        if (t.a == 0 && (t.b == 1.0 || t.b == -1.0)) {
                            expW = expSize.height;
                            expH = expSize.width;
                        } else {
                            expW = expSize.width;
                            expH = expSize.height;
                        }
                    }
                    if (completion) completion(outputPath, CGSizeMake(expW, expH), duration, thumbnail);
                } else {
                    NSLog(@"[Neo] Video export failed with status %ld: %@. Falling back to direct copy.", (long)exporter.status, exporter.error);
                    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
                    NSError *cpErr = nil;
                    [[NSFileManager defaultManager] copyItemAtPath:[videoURL path] toPath:outputPath error:&cpErr];
                    if (completion) completion(outputPath, CGSizeMake(w, h), duration, thumbnail);
                }
            });
        }];
    } else {
        NSError *cpErr = nil;
        [[NSFileManager defaultManager] copyItemAtPath:[videoURL path] toPath:outputPath error:&cpErr];
        if (completion) completion(outputPath, CGSizeMake(w, h), duration, thumbnail);
    }
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

        MatrixMessage *localMsg = [[MatrixMessage alloc] init];
        localMsg.eventId = [NSString stringWithFormat:@"local_%@", [[NSUUID UUID] UUIDString]];
        localMsg.sender = [[MatrixAPIClient sharedClient] userId];
        localMsg.body = @"Video";
        localMsg.msgType = @"m.video";
        localMsg.roomId = self.room.roomId;
        localMsg.timestamp = [NSDate date];
        localMsg.uploading = YES;
        [self.messages addObject:localMsg];
        [_messagesByEventId setObject:localMsg forKey:localMsg.eventId];
        [self reloadTableAnimatedWithAutoScroll:YES];

        __weak typeof(self) weakSelf = self;
        [self compressAndSaveVideoAtURL:videoURL completion:^(NSString *outputPath, CGSize naturalSize, NSTimeInterval duration, UIImage *thumbnail) {
            typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!outputPath) {
                [strongSelf failLocalMessage:localMsg];
                return;
            }
            localMsg.pendingLocalPath = outputPath;
            localMsg.videoWidth = naturalSize.width;
            localMsg.videoHeight = naturalSize.height;
            localMsg.videoDuration = @((NSInteger)(duration * 1000));
            localMsg.cachedVideoThumbnail = thumbnail;
            [strongSelf reloadTableAnimatedWithAutoScroll:NO];
            [strongSelf dispatchSendForMessage:localMsg];
        }];
    } else {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        if (!image) return;
        UIImage *resized = [self resizeImageForUpload:image];
        NSData *imageData = UIImageJPEGRepresentation(resized, 0.85);
        if (!imageData) {
            imageData = UIImageJPEGRepresentation(resized, 0.60);
        }

        MatrixMessage *localMsg = [[MatrixMessage alloc] init];
        localMsg.eventId = [NSString stringWithFormat:@"local_%@", [[NSUUID UUID] UUIDString]];
        localMsg.sender = [[MatrixAPIClient sharedClient] userId];
        localMsg.body = @"Photo";
        localMsg.msgType = @"m.image";
        localMsg.roomId = self.room.roomId;
        localMsg.timestamp = [NSDate date];
        localMsg.cachedImage = resized;
        localMsg.imageWidth = resized.size.width;
        localMsg.imageHeight = resized.size.height;
        localMsg.uploading = YES;
        localMsg.pendingLocalPath = [self savePendingData:imageData extension:@"jpg"];
        [self.messages addObject:localMsg];
        [_messagesByEventId setObject:localMsg forKey:localMsg.eventId];
        [self reloadTableAnimatedWithAutoScroll:YES];

        [self dispatchSendForMessage:localMsg];
    }
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

#pragma mark - Input bar

- (void)updateInputBarSize {
    UITextView *tv = self.messageField;
    CGFloat textH;
    if (IS_IOS7_OR_LATER) {
        CGFloat cw = tv.bounds.size.width - tv.textContainerInset.left - tv.textContainerInset.right;
        tv.textContainer.size = CGSizeMake(cw, CGFLOAT_MAX);
        textH = [tv.layoutManager usedRectForTextContainer:tv.textContainer].size.height;
    } else {
        tv.contentSize = CGSizeMake(tv.bounds.size.width, tv.contentSize.height);
        CGFloat insetsV = tv.contentInset.top + tv.contentInset.bottom;
        textH = MAX(tv.contentSize.height - insetsV, 0.0f);
    }
    CGFloat baseInsetsV = 10.0f;
    CGFloat contentFieldH = textH + baseInsetsV;
    CGFloat fieldH = MIN(MAX(contentFieldH, kNeoInputFieldMinH), kNeoInputFieldMaxH);
    tv.scrollEnabled = (contentFieldH > kNeoInputFieldMaxH - 1.0f);
    if (fieldH > contentFieldH + 0.5f) {
        CGFloat slack = fieldH - contentFieldH;
        if (IS_IOS7_OR_LATER) {
            CGFloat side = (10.0f + slack) / 2.0f;
            tv.textContainerInset = UIEdgeInsetsMake(side, 8, side, 0);
        } else {
            CGFloat side = (12.0f + slack) / 2.0f;
            tv.contentInset = UIEdgeInsetsMake(side, 8, side, 0);
        }
    } else {
        if (IS_IOS7_OR_LATER) {
            tv.textContainerInset = UIEdgeInsetsMake(5, 8, 5, 0);
        } else {
            tv.contentInset = UIEdgeInsetsMake(6, 8, 6, 0);
        }
    }
    if (fabsf(fieldH - tv.frame.size.height) < 0.5f) return;
    [self setInputBarHeight:kNeoInputBarBaseH + (fieldH - kNeoInputFieldMinH) animated:YES];
}

- (void)setInputBarHeight:(CGFloat)newH animated:(BOOL)animated {
    if (fabsf(newH - _inputBarHeight) < 0.5f) return;
    [self layoutInputWithBarHeight:newH animated:animated];
}

- (void)layoutInputWithBarHeight:(CGFloat)barH animated:(BOOL)animated {
    _inputBarHeight = barH;

    CGFloat replyH = (self.replyPreviewView && !self.replyPreviewView.hidden) ? [ReplyBubbleView viewHeight] : 0;
    CGFloat w = self.view.bounds.size.width;
    CGFloat tableH = self.view.bounds.size.height - _keyboardHeight - replyH - barH;
    CGFloat fieldH = kNeoInputFieldMinH + (barH - kNeoInputBarBaseH);
    CGFloat fieldX = 46;
    CGFloat fieldW = w - 96;
    CGFloat fieldY = (barH - fieldH) / 2.0f;

    void (^apply)(void) = ^{
        self.tableView.frame = CGRectMake(0, 0, w, tableH);
        self.inputContainer.frame = CGRectMake(0, tableH + replyH, w, barH);
        self.messageField.frame = CGRectMake(fieldX, fieldY, fieldW, fieldH);
        if (IS_IOS7_OR_LATER) {
            UIEdgeInsets ti = self.messageField.textContainerInset;
            self.messageField.textContainer.size = CGSizeMake(fieldW - ti.left - ti.right, fieldH - ti.top - ti.bottom);
        }
        _fieldBgView.frame = CGRectMake(fieldX, fieldY, fieldW, fieldH);
        _placeholderLabel.frame = CGRectMake(fieldX + 10, fieldY, fieldW - 30, fieldH);
        self.sendButton.frame = CGRectMake(w - 40, barH - 39, 34, 34);
        UIButton *cameraBtn = (UIButton *)[self.inputContainer viewWithTag:93];
        cameraBtn.frame = CGRectMake(8, barH - 39, 34, 34);
        if (replyH > 0 && self.replyPreviewView) {
            self.replyPreviewView.frame = CGRectMake(0, tableH, w, replyH);
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.2 animations:apply];
    } else {
        apply();
    }
    if (_shouldAutoScroll) [self scrollToBottom];
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)note {
    NSDictionary *info = [note userInfo];
    CGRect kbFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat kbHeight = kbFrame.size.height;

    _keyboardHeight = kbHeight;
    [self layoutInputWithBarHeight:_inputBarHeight animated:YES];
}

- (void)keyboardWillHide:(NSNotification *)note {
    _keyboardHeight = 0;
    [self layoutInputWithBarHeight:_inputBarHeight animated:YES];
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
    BOOL isAudio = [msg.msgType isEqualToString:@"m.audio"] || [msg.msgType isEqualToString:@"m.voice"];
    BOOL isVideo = [msg.msgType isEqualToString:@"m.video"];
    BOOL isFile = [msg.msgType isEqualToString:@"m.file"];
    BOOL hasMedia = ([msg.msgType isEqualToString:@"m.image"] ||
                     [msg.body hasPrefix:@"mxc://"] ||
                     isAudio ||
                     isVideo ||
                     isFile);

    BOOL isEmojiOnly = NO;
    BOOL isText = [msg.msgType isEqualToString:@"m.text"] || [msg.msgType isEqualToString:@"m.notice"] || [msg.msgType isEqualToString:@"m.emote"];
    if (!hasMedia && isText && [msg.body length] > 0) {
        NSUInteger count = 0;
        isEmojiOnly = [MatrixBubbleView stringContainsEmojiOnly:msg.body length:&count] && count <= 3;
    }

    NSString *cellId = [NSString stringWithFormat:@"MsgCell_%d_%d_%d_%d_%d", type, showUser, showTimestamp, isAudio || isVideo || isFile, isEmojiOnly];
    MatrixBubbleMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];

    UIView *mediaView = nil;
    if (isFile) {
        FileMessageView *fileView = [[FileMessageView alloc] initWithFrame:CGRectMake(0, 0, 240, 60)];
        fileView.mxcURL = msg.fileURL;
        fileView.fileName = msg.fileName;
        fileView.fileSize = msg.fileSize;
        fileView.fileMimeType = msg.fileMimeType;
        if (msg.cachedFileData) {
            [fileView setDownloadedData:msg.cachedFileData];
        } else {
            fileView.downloadLabel.text = NSLocalizedString(@"Tap to download", nil);
        }
        mediaView = fileView;
    } else if (isVideo) {
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
        } else if ([msg.pendingLocalPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:msg.pendingLocalPath]) {
            AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:msg.pendingLocalPath]];
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            gen.appliesPreferredTrackTransform = YES;
            gen.maximumSize = CGSizeMake(480, 480);
            CGImageRef tRef = [gen copyCGImageAtTime:CMTimeMake(1, 1) actualTime:NULL error:nil];
            if (tRef) {
                msg.cachedVideoThumbnail = [UIImage imageWithCGImage:tRef];
                CGImageRelease(tRef);
                videoView.thumbnailImage = msg.cachedVideoThumbnail;
            }
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
        } else if ([msg.pendingLocalPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:msg.pendingLocalPath]) {
            NSData *pData = [NSData dataWithContentsOfFile:msg.pendingLocalPath options:NSDataReadingMappedIfSafe error:nil];
            if (pData) {
                msg.cachedImage = [UIImage imageWithData:pData];
                preview.image = msg.cachedImage;
            }
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

    // Resolve reply details
    if (msg.replyToEventId && [msg.replyToEventId length] > 0) {
        if (!msg.replyToSender || !msg.replyToBody) {
            [msg resolveReplyFromDict:_messagesByEventId];
        }
    }

    [cell configureWithType:type
                     msgId:msg.eventId
                 showUser:showUser
            showTimestamp:showTimestamp
                 hasMedia:hasMedia
                mediaView:mediaView
           dateSeparator:nil];
    NSString *displayBody = [[DemoModeManager sharedManager] obfuscateMessage:msg.body];
    [cell setMessage:msg.isRedacted ? msg.body : displayBody];
    cell.bubbleView.isEmojiOnly = isEmojiOnly;
    [cell setTimestamp:msg.timestamp];
    [cell setIsRedacted:msg.isRedacted];
    [cell setUserWrited:[self displayNameForSender:msg.sender]];
    cell.bubbleView.senderId = msg.sender;

    // Reply quote
    if (msg.replyToEventId && msg.replyToBody && [msg.replyToBody length] > 0) {
        NSString *repliedName = msg.replyToSender ? [self displayNameForSender:msg.replyToSender] : NSLocalizedString(@"Unknown", nil);
        [cell setReplySender:repliedName replyBody:msg.replyToBody];
    } else {
        [cell setReplySender:nil replyBody:nil];
    }

    if (isSelf) {
        BOOL isPendingLocal = [msg.eventId hasPrefix:@"local_"];
        NSInteger ackVal;
        if (msg.failed) {
            ackVal = 3;
        } else if (isPendingLocal && !hasMedia) {
            ackVal = 0;
        } else {
            ackVal = msg.readByOther ? 2 : 1;
        }
        [cell setAck:ackVal];
    }

    // Upload progress overlay
    if (msg.uploading && mediaView) {
        UIView *overlay = [[UIView alloc] initWithFrame:mediaView.bounds];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
        NeoProgressSpinnerView *spinner = [[NeoProgressSpinnerView alloc] initWithFrame:CGRectMake(0, 0, 40, 40) light:NO];
        spinner.center = CGPointMake(overlay.bounds.size.width / 2, overlay.bounds.size.height / 2);
        spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                   UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [overlay addSubview:spinner];
        [spinner setProgress];
        [mediaView addSubview:overlay];
    }

    // Reactions — pill buttons
    UIView *pillContainer = (UIView *)[cell.contentView viewWithTag:91];
    if (!pillContainer) {
        pillContainer = [[UIView alloc] initWithFrame:CGRectZero];
        pillContainer.tag = 91;
        pillContainer.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:pillContainer];
    }

    if ([msg.reactions count] > 0) {
        CGRect bf = [cell.bubbleView bubbleFrame];
        CGFloat pillY = CGRectGetMaxY(bf) + 2;
        [NeoReactionViewBuilder populatePillContainer:pillContainer
                                           forMessage:msg
                                          bubbleFrame:bf
                                               isSelf:isSelf
                                               target:self
                                               action:@selector(reactionPillTapped:)];
        pillContainer.frame = CGRectMake(0, pillY, self.tableView.frame.size.width, 26);
        pillContainer.hidden = NO;
    } else {
        for (UIView *v in pillContainer.subviews) [v removeFromSuperview];
        pillContainer.hidden = YES;
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

    if ([msg.msgType isEqualToString:@"m.file"]) {
        [self downloadAndOpenFile:msg];
        return;
    }

    if (![msg.msgType isEqualToString:@"m.image"] && ![msg.body hasPrefix:@"mxc://"]) return;

    if ([msg.imageURL length] == 0) return;

    PhotoViewerController *viewer = [[PhotoViewerController alloc] init];
    viewer.title = @"Photo";

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:viewer];
    [self presentViewController:nav animated:YES completion:nil];

    [[MatrixAPIClient sharedClient] downloadImageFromMXC:msg.imageURL completion:^(UIImage *image, NSError *err) {
        if (image) {
            [viewer updateImage:image];
        }
    }];
}

- (void)downloadAndOpenFile:(MatrixMessage *)msg {
    if ([msg.fileURL length] == 0) return;

    NSString *cachePath = [self fileCachePathForMXC:msg.fileURL fileName:msg.fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        [self openFileAtPath:cachePath];
        return;
    }

    if (_activeDownloads[msg.fileURL]) return;

    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSString *httpURL = [client mxcURLToHTTP:msg.fileURL];
    if (!httpURL) return;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:httpURL]];
    if (client.accessToken) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", client.accessToken] forHTTPHeaderField:@"Authorization"];
    }

    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"connection"] = connection;
    info[@"data"] = [NSMutableData data];
    info[@"cachePath"] = cachePath;
    info[@"fileName"] = msg.fileName ?: @"";
    info[@"message"] = msg;
    _activeDownloads[msg.fileURL] = info;

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Downloading", nil)
                                                    message:[NSString stringWithFormat:NSLocalizedString(@"Downloading %@...", nil), msg.fileName]
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:nil];
    alert.tag = 888;
    objc_setAssociatedObject(alert, @"fileURL", msg.fileURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [alert show];

    [connection start];
}

#pragma mark - NSURLConnectionDataDelegate (File Downloads)

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSString *key = [self keyForConnection:connection];
    if (!key) return;
    NSMutableDictionary *info = _activeDownloads[key];
    [(NSMutableData *)info[@"data"] setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSString *key = [self keyForConnection:connection];
    if (!key) return;
    NSMutableDictionary *info = _activeDownloads[key];
    [(NSMutableData *)info[@"data"] appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *key = [self keyForConnection:connection];
    if (!key) return;
    [self finishDownloadWithKey:key error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSString *key = [self keyForConnection:connection];
    if (!key) return;
    [self finishDownloadWithKey:key error:error];
}

- (NSString *)keyForConnection:(NSURLConnection *)connection {
    for (NSString *key in _activeDownloads) {
        if (_activeDownloads[key][@"connection"] == connection) return key;
    }
    return nil;
}

- (void)finishDownloadWithKey:(NSString *)key error:(NSError *)error {
    NSMutableDictionary *info = _activeDownloads[key];
    if (!info) return;

    NSString *cachePath = info[@"cachePath"];
    MatrixMessage *msg = info[@"message"];
    NSData *data = (NSData *)info[@"data"];
    [_activeDownloads removeObjectForKey:key];

    [self dismissDownloadAlertForKey:key];

    if (error || !data || [data length] == 0) {
        [NeoAlert showAlertWithTitle:NSLocalizedString(@"Error", nil)
                             message:error ? [error localizedDescription] : NSLocalizedString(@"Download failed", nil)
                         cancelTitle:@"OK"
                          controller:self];
        return;
    }

    [data writeToFile:cachePath atomically:YES];
    msg.cachedFileData = data;
    [self.tableView reloadData];
    [self openFileAtPath:cachePath];
}

- (void)dismissDownloadAlertForKey:(NSString *)key {
    for (UIView *v in [[[UIApplication sharedApplication] keyWindow] subviews]) {
        if ([v isKindOfClass:[UIAlertView class]]) {
            UIAlertView *av = (UIAlertView *)v;
            if (av.tag == 888) {
                NSString *alertURL = objc_getAssociatedObject(av, @"fileURL");
                if ([alertURL isEqualToString:key]) {
                    [av dismissWithClickedButtonIndex:av.cancelButtonIndex animated:YES];
                    return;
                }
            }
        }
    }
}

- (NSString *)fileCachePathForMXC:(NSString *)mxcURL fileName:(NSString *)fileName {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
                          stringByAppendingPathComponent:@"FileCache"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString *safeName = [mxcURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    safeName = [safeName stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    NSString *ext = [fileName pathExtension];
    if ([ext length] > 0) {
        return [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", safeName, ext]];
    }
    return [cacheDir stringByAppendingPathComponent:safeName];
}

- (void)openFileAtPath:(NSString *)filePath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) return;

    if (IS_IOS7_OR_LATER) {
        NSString *filzaURLStr = [NSString stringWithFormat:@"filza://%@", filePath];
        NSURL *filzaURL = [NSURL URLWithString:filzaURLStr];
        if ([[UIApplication sharedApplication] canOpenURL:filzaURL]) {
            [[UIApplication sharedApplication] openURL:filzaURL];
            return;
        }
    }

    NSString *ifileURLStr = [NSString stringWithFormat:@"ifile://%@", filePath];
    NSURL *ifileURL = [NSURL URLWithString:ifileURLStr];
    if ([[UIApplication sharedApplication] canOpenURL:ifileURL]) {
        [[UIApplication sharedApplication] openURL:ifileURL];
        return;
    }

    [NeoAlert showAlertWithTitle:NSLocalizedString(@"No file viewer found", nil)
                         message:NSLocalizedString(@"Install iFile or Filza to open files", nil)
                     cancelTitle:@"OK"
                      controller:self];
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
    BOOL isAudio = [msg.msgType isEqualToString:@"m.audio"] || [msg.msgType isEqualToString:@"m.voice"];
    BOOL isVideo = [msg.msgType isEqualToString:@"m.video"];
    BOOL isFile = [msg.msgType isEqualToString:@"m.file"];
    BOOL hasMedia = ([msg.msgType isEqualToString:@"m.image"] ||
                     [msg.body hasPrefix:@"mxc://"] ||
                     isAudio ||
                     isVideo ||
                     isFile);

    CGFloat bubbleH;
    if (isFile) {
        bubbleH = [MatrixBubbleView cellHeightForMediaWithText:msg.fileName
                                                       showUser:showUser
                                                  showTimestamp:showTimestamp
                                                     isRedacted:msg.isRedacted
                                                    mediaHeight:60];
    } else if (isAudio) {
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
        NSUInteger emojiCount = 0;
        BOOL emojiOnly = ![msg.msgType isEqualToString:@"m.image"] && ![msg.body hasPrefix:@"mxc://"]
            && [MatrixBubbleView stringContainsEmojiOnly:msg.body length:&emojiCount] && emojiCount <= 3;
        if (emojiOnly) {
            bubbleH = [MatrixBubbleView cellHeightForEmojiOnly:msg.body];
        } else {
            bubbleH = [MatrixBubbleView cellHeightForText:msg.body
                                                 showUser:showUser
                                            showTimestamp:showTimestamp
                                               isRedacted:msg.isRedacted];
        }
    }

    CGFloat reactionH = ([msg.reactions count] > 0) ? 26 : 0;
    CGFloat replyH = (msg.replyToEventId && [msg.replyToEventId length] > 0) ? [MatrixBubbleView replyPreviewHeight] : 0;
    return bubbleH + reactionH + replyH;
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

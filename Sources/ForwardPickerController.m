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

    NSString *cachePath = [[MatrixAPIClient sharedClient] roomCachePath];
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

    MatrixMessage *msg = self.message;
    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    NSString *msgType = msg.msgType;

    [self dismissViewControllerAnimated:YES completion:nil];

    if ([msgType isEqualToString:@"m.image"] && [msg.imageURL length] > 0) {
        [self forwardImage:msg toRoom:roomId client:client];
        return;
    }
    if ([msgType isEqualToString:@"m.video"] && [msg.videoURL length] > 0) {
        [self forwardVideo:msg toRoom:roomId client:client];
        return;
    }
    if (([msgType isEqualToString:@"m.audio"] || [msgType isEqualToString:@"m.voice"]) && [msg.audioURL length] > 0) {
        [self forwardAudio:msg toRoom:roomId client:client];
        return;
    }
    if ([msgType isEqualToString:@"m.file"] && [msg.fileURL length] > 0) {
        [self forwardFile:msg toRoom:roomId client:client];
        return;
    }
    if ([msg.body length] > 0) {
        [client sendMessage:msg.body roomId:roomId completion:nil];
    }
}

- (void)forwardImage:(MatrixMessage *)msg toRoom:(NSString *)roomId client:(MatrixAPIClient *)client {
    [client downloadDataFromMXC:msg.imageURL completion:^(NSData *data, NSString *mimeType, NSError *error) {
        if (!data) return;
        NSString *mime = [mimeType length] > 0 ? mimeType : @"image/jpeg";
        [client uploadData:data mimeType:mime filename:@"photo.jpg" completion:^(NSString *contentURI, NSError *err) {
            if (!contentURI) return;
            [client sendImageMessage:contentURI roomId:roomId caption:msg.body completion:nil];
        }];
    }];
}

- (void)forwardVideo:(MatrixMessage *)msg toRoom:(NSString *)roomId client:(MatrixAPIClient *)client {
    [client downloadDataFromMXC:msg.videoURL completion:^(NSData *data, NSString *mimeType, NSError *error) {
        if (!data) return;
        NSString *mime = [mimeType length] > 0 ? mimeType : @"video/mp4";
        NSInteger size = [data length];
        [client uploadData:data mimeType:mime filename:@"video.mp4" completion:^(NSString *contentURI, NSError *err) {
            if (!contentURI) return;
            void (^sendWithThumb)(NSString *) = ^(NSString *thumbURI) {
                [client sendVideoMessage:contentURI
                                  roomId:roomId
                               thumbnail:thumbURI
                                duration:[msg.videoDuration integerValue]
                                   width:msg.videoWidth
                                  height:msg.videoHeight
                                    size:size
                              completion:nil];
            };
            if ([msg.videoThumbnailURL length] > 0) {
                [client downloadDataFromMXC:msg.videoThumbnailURL completion:^(NSData *thumbData, NSString *thumbMime, NSError *thumbErr) {
                    if (!thumbData) {
                        sendWithThumb(nil);
                        return;
                    }
                    NSString *tm = [thumbMime length] > 0 ? thumbMime : @"image/jpeg";
                    [client uploadData:thumbData mimeType:tm filename:@"thumb.jpg" completion:^(NSString *thumbURI, NSError *upErr) {
                        sendWithThumb(thumbURI);
                    }];
                }];
            } else {
                sendWithThumb(nil);
            }
        }];
    }];
}

- (void)forwardAudio:(MatrixMessage *)msg toRoom:(NSString *)roomId client:(MatrixAPIClient *)client {
    [client downloadDataFromMXC:msg.audioURL completion:^(NSData *data, NSString *mimeType, NSError *error) {
        if (!data) return;
        NSString *mime = [mimeType length] > 0 ? mimeType : @"audio/mp4";
        NSInteger size = [data length];
        [client uploadData:data mimeType:mime filename:@"voice.m4a" completion:^(NSString *contentURI, NSError *err) {
            if (!contentURI) return;
            [client sendAudioMessage:contentURI
                              roomId:roomId
                            filename:NSLocalizedString(@"Voice message", nil)
                            mimeType:mime
                            duration:[msg.audioDuration integerValue]
                                size:size
                          completion:nil];
        }];
    }];
}

- (void)forwardFile:(MatrixMessage *)msg toRoom:(NSString *)roomId client:(MatrixAPIClient *)client {
    NSString *name = [msg.fileName length] > 0 ? msg.fileName : @"file";
    NSString *fallbackMime = [msg.fileMimeType length] > 0 ? msg.fileMimeType : @"application/octet-stream";

    void (^uploadAndSend)(NSData *) = ^(NSData *data) {
        NSString *mime = [msg.fileMimeType length] > 0 ? msg.fileMimeType : fallbackMime;
        [client uploadData:data mimeType:mime filename:name completion:^(NSString *contentURI, NSError *err) {
            if (!contentURI) return;
            [client sendFileMessage:contentURI
                             roomId:roomId
                           filename:name
                           mimeType:mime
                               size:[data length]
                         completion:nil];
        }];
    };

    if (msg.cachedFileData) {
        uploadAndSend(msg.cachedFileData);
        return;
    }
    [client downloadDataFromMXC:msg.fileURL completion:^(NSData *data, NSString *mimeType, NSError *error) {
        if (!data) return;
        if ([mimeType length] > 0 && [msg.fileMimeType length] == 0) {
            msg.fileMimeType = mimeType;
        }
        uploadAndSend(data);
    }];
}

@end

#import "MatrixAPIClient.h"
#import "MatrixModels.h"
#import "NeoCompatibility.h"
#import "NeoCurlTransport.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

static const NSInteger kMaxConcurrentImageDownloads = 4;

static void IMGLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[IMG] %@", msg);
    NSString *path = @"/var/mobile/Library/MatrixClient/imglog.txt";
    NSString *line = [NSString stringWithFormat:@"%@: %@\n", [NSDate date], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [line writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

static NSString *const kDefaultsKeyHomeserver = @"matrix_homeserver";
static NSString *const kDefaultsKeyAccessToken = @"matrix_access_token";
static NSString *const kDefaultsKeyDeviceId = @"matrix_device_id";
static NSString *const kDefaultsKeyUserId = @"matrix_user_id";
static NSString *const kDefaultsKeyNextBatch = @"matrix_next_batch";

NSString *const NeoCacheDidClearNotification = @"NeoCacheDidClearNotification";

@implementation MatrixAPIClient {
    NSInteger _activeImageDownloads;
    NSMutableArray *_pendingImageDownloads;
    NSTimeInterval _lastImgActivity;
}

+ (instancetype)sharedClient {
    static MatrixAPIClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        instance.homeserver = [defaults stringForKey:kDefaultsKeyHomeserver];
        instance.accessToken = [defaults stringForKey:kDefaultsKeyAccessToken];
        instance.deviceId = [defaults stringForKey:kDefaultsKeyDeviceId];
        instance.userId = [defaults stringForKey:kDefaultsKeyUserId];
        instance.nextBatchToken = [defaults stringForKey:kDefaultsKeyNextBatch];
        instance.messageCache = [[NSCache alloc] init];
        instance.messageCache.countLimit = 30;
        instance.memberCache = [[NSCache alloc] init];
        instance.memberCache.countLimit = 40;
        instance.avatarCache = [[NSCache alloc] init];
        instance.avatarCache.countLimit = 200;
        instance.avatarCache.totalCostLimit = 48 * 1024 * 1024;
        instance->_lastImgActivity = [NSDate timeIntervalSinceReferenceDate];
    });
    return instance;
}

- (void)setNextBatchToken:(NSString *)nextBatchToken {
    _nextBatchToken = [nextBatchToken copy];
    [[NSUserDefaults standardUserDefaults] setObject:_nextBatchToken forKey:kDefaultsKeyNextBatch];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveCredentials {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.homeserver forKey:kDefaultsKeyHomeserver];
    [defaults setObject:self.accessToken forKey:kDefaultsKeyAccessToken];
    [defaults setObject:self.deviceId forKey:kDefaultsKeyDeviceId];
    [defaults setObject:self.userId forKey:kDefaultsKeyUserId];
    [defaults synchronize];
}

- (void)clearCredentials {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kDefaultsKeyAccessToken];
    [defaults removeObjectForKey:kDefaultsKeyDeviceId];
    [defaults removeObjectForKey:kDefaultsKeyUserId];
    [defaults synchronize];
    self.accessToken = nil;
    self.deviceId = nil;
    self.userId = nil;
}

- (void)clearAllCaches {
    self.nextBatchToken = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKeyNextBatch];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self.messageCache removeAllObjects];
    [self.memberCache removeAllObjects];
    [self.avatarCache removeAllObjects];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *cachesRoot = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    NSArray *cacheDirs = @[
        [cachesRoot stringByAppendingPathComponent:@"com.neo.messageCache"],
        [cachesRoot stringByAppendingPathComponent:@"com.neo.memberCache"],
        [cachesRoot stringByAppendingPathComponent:@"com.neo.avatarCache"],
        [cachesRoot stringByAppendingPathComponent:@"com.neo.FileCache"],
        [cachesRoot stringByAppendingPathComponent:@"MediaCache"],
    ];
    for (NSString *dir in cacheDirs) {
        [fm removeItemAtPath:dir error:nil];
    }
    NSArray *cacheFiles = @[
        [cachesRoot stringByAppendingPathComponent:@"com.neo.roomCache.plist"],
    ];
    for (NSString *file in cacheFiles) {
        [fm removeItemAtPath:file error:nil];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:NeoCacheDidClearNotification object:nil];
}

#pragma mark - HTTP

- (NSMutableURLRequest *)requestWithPath:(NSString *)path method:(NSString *)method {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.homeserver, path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setHTTPMethod:method];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"MatrixClient-iOS6/1.0" forHTTPHeaderField:@"User-Agent"];
    if (self.accessToken) {
        NSString *auth = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [req setValue:auth forHTTPHeaderField:@"Authorization"];
    }
    [req setTimeoutInterval:30];
    return req;
}

- (void)sendRequest:(NSURLRequest *)request completion:(MatrixCompletion)completion {
    void (^safeCompletion)(NSDictionary *, NSError *) = ^(NSDictionary *resp, NSError *err) {
        if (completion) completion(resp, err);
    };
    void (^handleResp)(NSURLResponse *, NSData *, NSError *) = ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            safeCompletion(nil, connectionError);
            return;
        }
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        if (httpResp.statusCode >= 400) {
            NSString *body = @"";
            if (data) {
                body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            NSDictionary *errInfo = @{@"statusCode": @(httpResp.statusCode),
                                      @"body": body,
                                      @"error": [NSHTTPURLResponse localizedStringForStatusCode:httpResp.statusCode]};
            NSError *err = [NSError errorWithDomain:@"MatrixAPI" code:httpResp.statusCode
                                           userInfo:errInfo];
            safeCompletion(nil, err);
            return;
        }
        if (!data) {
            safeCompletion(@{}, nil);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&jsonError];
        if (jsonError) {
            safeCompletion(nil, jsonError);
        } else {
            safeCompletion(json, nil);
        }
    };

    if (IS_IOS7_OR_LATER) {
        NSURLSession *session = [NSURLSession sharedSession];
        [[session dataTaskWithRequest:request
                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handleResp(response, data, error);
            });
        }] resume];
    } else {
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:handleResp];
    }
}

#pragma mark - API Methods

- (void)loginWithUser:(NSString *)user
             password:(NSString *)password
           completion:(MatrixCompletion)completion {
    NSMutableURLRequest *req = [self requestWithPath:@"/_matrix/client/r0/login" method:@"POST"];
    NSDictionary *body = @{
        @"type": @"m.login.password",
        @"user": user,
        @"password": password,
        @"initial_device_display_name": @"MatrixClient iOS 6"
    };
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&err];
    if (err) {
        completion(nil, err);
        return;
    }
    [req setHTTPBody:jsonData];

    [self sendRequest:req completion:^(NSDictionary *response, NSError *error) {
        if (response) {
            self.accessToken = response[@"access_token"];
            self.deviceId = response[@"device_id"];
            self.userId = response[@"user_id"];
            [self saveCredentials];
        }
        completion(response, error);
    }];
}

- (void)getJoinedRoomsWithCompletion:(MatrixCompletion)completion {
    NSURLRequest *req = [self requestWithPath:@"/_matrix/client/r0/joined_rooms" method:@"GET"];
    [self sendRequest:req completion:completion];
}

- (void)syncWithSince:(NSString *)since
              timeout:(NSInteger)timeout
           completion:(MatrixCompletion)completion {
    NSString *filterJSON = @"{\"room\":{\"state\":{\"lazy_load_members\":true},\"timeline\":{\"limit\":50}}}";
    NSString *encodedFilter = [filterJSON stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *path;
    if (since) {
        path = [NSString stringWithFormat:@"/_matrix/client/r0/sync?since=%@&timeout=%ld&filter=%@",
                since, (long)timeout, encodedFilter];
    } else {
        path = [NSString stringWithFormat:@"/_matrix/client/r0/sync?timeout=%ld&filter=%@",
                (long)timeout, encodedFilter];
    }
    NSURLRequest *req = [self requestWithPath:path method:@"GET"];
    [self sendRequest:req completion:completion];
}

- (void)sendMessage:(NSString *)body
             roomId:(NSString *)roomId
         completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
                      NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];
    NSDictionary *msgBody = @{
        @"msgtype": @"m.text",
        @"body": body
    };
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody options:0 error:&err];
    if (err) {
        completion(nil, err);
        return;
    }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)sendReply:(NSString *)body
           roomId:(NSString *)roomId
    replyToEventId:(NSString *)replyToEventId
        completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
                      NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];
    NSDictionary *msgBody = @{
        @"msgtype": @"m.text",
        @"body": body,
        @"m.relates_to": @{
            @"m.in_reply_to": @{@"event_id": replyToEventId}
        }
    };
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody options:0 error:&err];
    if (err) {
        completion(nil, err);
        return;
    }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)editMessage:(NSString *)newBody
             roomId:(NSString *)roomId
            eventId:(NSString *)eventId
         completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:
        @"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
        NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];
    NSDictionary *msgBody = @{
        @"msgtype": @"m.text",
        @"body": [NSString stringWithFormat:@"* %@", newBody],
        @"m.new_content": @{
            @"msgtype": @"m.text",
            @"body": newBody
        },
        @"m.relates_to": @{
            @"rel_type": @"m.replace",
            @"event_id": eventId
        }
    };
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody
                                                       options:0
                                                         error:&err];
    if (err) { completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)sendReaction:(NSString *)emoji
              roomId:(NSString *)roomId
             eventId:(NSString *)eventId
          completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:
        @"/_matrix/client/r0/rooms/%@/send/m.reaction/%@",
        NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];
    NSDictionary *body = @{
        @"m.relates_to": @{
            @"rel_type": @"m.annotation",
            @"event_id": eventId,
            @"key": emoji
        }
    };
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body
                                                       options:0
                                                         error:&err];
    if (err) { completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)redactMessage:(NSString *)roomId
              eventId:(NSString *)eventId
           completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/redact/%@/%@",
                     NeoURLEncode(roomId), NeoURLEncode(eventId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];
    NSDictionary *body = @{@"reason": @"Deleted"};
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&err];
    if (err) { completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)sendReadReceipt:(NSString *)roomId
                 eventId:(NSString *)eventId
              completion:(MatrixCompletion)completion {
    if (!roomId || !eventId) {
        if (completion) completion(nil, [NSError errorWithDomain:@"MatrixAPI" code:-1 userInfo:nil]);
        return;
    }
    NSString *path = [NSString stringWithFormat:
        @"/_matrix/client/r0/rooms/%@/receipt/m.read/%@", NeoURLEncode(roomId), NeoURLEncode(eventId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"POST"];
    NSData *emptyJson = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:nil];
    [req setHTTPBody:emptyJson];
    [self sendRequest:req completion:completion ?: ^(NSDictionary *r, NSError *e) {
        if (e) NSLog(@"[ReadReceipt] Error enviando receipt: %@", e);
    }];
}

- (void)sendTyping:(BOOL)typing
            roomId:(NSString *)roomId
        completion:(MatrixCompletion)completion {
    if (!self.userId || [roomId length] == 0) {
        if (completion) completion(nil, nil);
        return;
    }
    NSString *escapedUser = NeoURLEncode(self.userId);
    NSString *path = [NSString stringWithFormat:
        @"/_matrix/client/r0/rooms/%@/typing/%@", NeoURLEncode(roomId), escapedUser];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"typing"] = @(typing);
    if (typing) body[@"timeout"] = @4000;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [req setHTTPBody:json];
    [self sendRequest:req completion:completion];
}

- (void)sendVideoMessage:(NSString *)videoURL
                  roomId:(NSString *)roomId
                thumbnail:(NSString *)thumbnailURL
                duration:(NSInteger)duration
                   width:(CGFloat)width
                  height:(CGFloat)height
                    size:(NSInteger)size
              completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
                      NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];

    NSMutableDictionary *msgBody = [NSMutableDictionary dictionary];
    msgBody[@"msgtype"] = @"m.video";
    msgBody[@"body"] = @"Video";
    if (videoURL) msgBody[@"url"] = videoURL;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"h"] = @((int)height);
    info[@"w"] = @((int)width);
    info[@"duration"] = @(duration);
    info[@"mimetype"] = @"video/mp4";
    info[@"size"] = @(size);
    if (thumbnailURL) info[@"thumbnail_url"] = thumbnailURL;
    msgBody[@"info"] = info;

    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody options:0 error:&err];
    if (err) { completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)uploadFileAtPath:(NSString *)filePath
                mimeType:(NSString *)mimeType
                filename:(NSString *)filename
                progress:(void(^)(float fraction))progress
              completion:(void(^)(NSString *contentURI, NSError *error))completion {
    [self uploadFileAtPath:filePath
                  mimeType:mimeType
                  filename:filename
                   isRetry:NO
                  progress:progress
                completion:completion];
}

- (void)uploadFileAtPath:(NSString *)filePath
                mimeType:(NSString *)mimeType
                filename:(NSString *)filename
                 isRetry:(BOOL)isRetry
                progress:(void(^)(float fraction))progress
              completion:(void(^)(NSString *contentURI, NSError *error))completion {
    NSString *basePath = isRetry ? @"/_matrix/media/r0/upload" : @"/_matrix/media/v3/upload";
    NSString *url = [NSString stringWithFormat:@"%@%@?filename=%@", self.homeserver, basePath, NeoURLEncode(filename ?: @"file")];

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    headers[@"Content-Type"] = mimeType ?: @"application/octet-stream";
    headers[@"User-Agent"] = @"MatrixClient-iOS6/1.0";
    if (self.accessToken) {
        headers[@"Authorization"] = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
    }

    [NeoCurlTransport uploadFile:filePath
                           toURL:url
                         headers:headers
                        progress:progress
                      completion:^(NSData *respData, NSInteger statusCode, NSError *curlErr) {
        if (statusCode == 404 && !isRetry) {
            NSLog(@"[Neo] Media v3 upload returned 404, retrying with r0 endpoint via libcurl...");
            [self uploadFileAtPath:filePath
                          mimeType:mimeType
                          filename:filename
                           isRetry:YES
                          progress:progress
                        completion:completion];
            return;
        }

        if (statusCode >= 400 || curlErr) {
            NSString *errMsg = nil;
            if (respData && [respData length] > 0) {
                NSDictionary *errJson = [NSJSONSerialization JSONObjectWithData:respData options:0 error:nil];
                if ([errJson isKindOfClass:[NSDictionary class]] && errJson[@"error"]) {
                    errMsg = errJson[@"error"];
                } else {
                    errMsg = [[NSString alloc] initWithData:respData encoding:NSUTF8StringEncoding];
                }
            }
            if (!errMsg || [errMsg length] == 0) {
                errMsg = curlErr ? [curlErr localizedDescription] : [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
            }
            NSLog(@"[Neo] Media libcurl upload failed (HTTP %ld): %@", (long)statusCode, errMsg);
            NSError *err = [NSError errorWithDomain:@"MatrixAPIClient" code:statusCode userInfo:@{NSLocalizedDescriptionKey: errMsg}];
            if (completion) completion(nil, err);
            return;
        }

        NSError *jsonErr = nil;
        NSDictionary *json = respData ? [NSJSONSerialization JSONObjectWithData:respData options:0 error:&jsonErr] : nil;
        if (jsonErr) {
            NSLog(@"[Neo] Media upload JSON error: %@", jsonErr);
            if (completion) completion(nil, jsonErr);
            return;
        }

        NSString *contentURI = [json isKindOfClass:[NSDictionary class]] ? json[@"content_uri"] : nil;
        if (!contentURI || [contentURI length] == 0) {
            NSLog(@"[Neo] Media upload missing content_uri: %@", json);
            NSError *err = [NSError errorWithDomain:@"MatrixAPIClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing content_uri"}];
            if (completion) completion(nil, err);
            return;
        }

        if (completion) completion(contentURI, nil);
    }];
}

- (void)uploadData:(NSData *)data
          mimeType:(NSString *)mimeType
          filename:(NSString *)filename
        completion:(void(^)(NSString *contentURI, NSError *error))completion {
    [self uploadData:data
            mimeType:mimeType
            filename:filename
             isRetry:NO
          completion:completion];
}

- (void)uploadData:(NSData *)data
          mimeType:(NSString *)mimeType
          filename:(NSString *)filename
           isRetry:(BOOL)isRetry
        completion:(void(^)(NSString *contentURI, NSError *error))completion {
    NSString *basePath = isRetry ? @"/_matrix/media/r0/upload" : @"/_matrix/media/v3/upload";
    NSString *url = [NSString stringWithFormat:@"%@%@?filename=%@", self.homeserver, basePath, NeoURLEncode(filename ?: @"file")];

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    headers[@"Content-Type"] = mimeType ?: @"application/octet-stream";
    headers[@"User-Agent"] = @"MatrixClient-iOS6/1.0";
    if (self.accessToken) {
        headers[@"Authorization"] = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
    }

    [NeoCurlTransport uploadData:data
                           toURL:url
                         headers:headers
                      completion:^(NSData *respData, NSInteger statusCode, NSError *curlErr) {
        if (statusCode == 404 && !isRetry) {
            NSLog(@"[Neo] Media v3 upload returned 404, retrying with r0 endpoint via libcurl...");
            [self uploadData:data
                    mimeType:mimeType
                    filename:filename
                     isRetry:YES
                  completion:completion];
            return;
        }

        if (statusCode >= 400 || curlErr) {
            NSString *errMsg = nil;
            if (respData && [respData length] > 0) {
                NSDictionary *errJson = [NSJSONSerialization JSONObjectWithData:respData options:0 error:nil];
                if ([errJson isKindOfClass:[NSDictionary class]] && errJson[@"error"]) {
                    errMsg = errJson[@"error"];
                } else {
                    errMsg = [[NSString alloc] initWithData:respData encoding:NSUTF8StringEncoding];
                }
            }
            if (!errMsg || [errMsg length] == 0) {
                errMsg = curlErr ? [curlErr localizedDescription] : [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
            }
            NSLog(@"[Neo] Media libcurl uploadData failed (HTTP %ld): %@", (long)statusCode, errMsg);
            NSError *err = [NSError errorWithDomain:@"MatrixAPIClient" code:statusCode userInfo:@{NSLocalizedDescriptionKey: errMsg}];
            if (completion) completion(nil, err);
            return;
        }

        NSError *jsonErr = nil;
        NSDictionary *json = respData ? [NSJSONSerialization JSONObjectWithData:respData options:0 error:&jsonErr] : nil;
        if (jsonErr) {
            NSLog(@"[Neo] Media upload JSON error: %@", jsonErr);
            if (completion) completion(nil, jsonErr);
            return;
        }

        NSString *contentURI = [json isKindOfClass:[NSDictionary class]] ? json[@"content_uri"] : nil;
        if (!contentURI || [contentURI length] == 0) {
            NSLog(@"[Neo] Media upload missing content_uri: %@", json);
            NSError *err = [NSError errorWithDomain:@"MatrixAPIClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing content_uri"}];
            if (completion) completion(nil, err);
            return;
        }

        if (completion) completion(contentURI, nil);
    }];
}

- (void)sendImageMessage:(NSString *)imageURL
                   roomId:(NSString *)roomId
                  caption:(NSString *)caption
               completion:(MatrixCompletion)completion {
    [self sendImageMessage:imageURL
                    roomId:roomId
                   caption:caption
                     width:0
                    height:0
                      size:0
                completion:completion];
}

- (void)sendImageMessage:(NSString *)imageURL
                   roomId:(NSString *)roomId
                  caption:(NSString *)caption
                    width:(CGFloat)width
                   height:(CGFloat)height
                     size:(NSInteger)size
               completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
                     NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];

    NSMutableDictionary *msgBody = [NSMutableDictionary dictionary];
    msgBody[@"msgtype"] = @"m.image";
    msgBody[@"body"] = ([caption length] > 0) ? caption : @"Photo";
    if (imageURL) msgBody[@"url"] = imageURL;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (width > 0) info[@"w"] = @((int)width);
    if (height > 0) info[@"h"] = @((int)height);
    if (size > 0) info[@"size"] = @(size);
    info[@"mimetype"] = @"image/jpeg";
    if ([info count] > 0) {
        msgBody[@"info"] = info;
    }

    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody options:0 error:&err];
    if (err) { if (completion) completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)sendFileMessage:(NSString *)fileURL
                 roomId:(NSString *)roomId
               filename:(NSString *)filename
               mimeType:(NSString *)mimeType
                   size:(NSInteger)size
             completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
                      NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];

    NSMutableDictionary *msgBody = [NSMutableDictionary dictionary];
    msgBody[@"msgtype"] = @"m.file";
    msgBody[@"body"] = [filename length] > 0 ? filename : @"File";
    if (fileURL) msgBody[@"url"] = fileURL;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if ([mimeType length] > 0) info[@"mimetype"] = mimeType;
    if (size > 0) info[@"size"] = @(size);
    msgBody[@"info"] = info;

    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody options:0 error:&err];
    if (err) { if (completion) completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)sendAudioMessage:(NSString *)audioURL
                  roomId:(NSString *)roomId
                filename:(NSString *)filename
                mimeType:(NSString *)mimeType
                duration:(NSInteger)duration
                    size:(NSInteger)size
              completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
                      NeoURLEncode(roomId), NeoURLEncode(txnId)];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];

    NSMutableDictionary *msgBody = [NSMutableDictionary dictionary];
    msgBody[@"msgtype"] = @"m.audio";
    msgBody[@"body"] = [filename length] > 0 ? filename : @"Audio";
    if (audioURL) msgBody[@"url"] = audioURL;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if ([mimeType length] > 0) info[@"mimetype"] = mimeType;
    if (size > 0) info[@"size"] = @(size);
    if (duration > 0) info[@"duration"] = @(duration);
    msgBody[@"info"] = info;

    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody options:0 error:&err];
    if (err) { if (completion) completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)getRoomMessages:(NSString *)roomId
             completion:(MatrixCompletion)completion {
    NSString *encodedId = NeoURLEncode(roomId);
    NSInteger limit = [[NSUserDefaults standardUserDefaults] integerForKey:@"neo_message_limit"];
    if (limit <= 0) limit = 50;
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/messages?dir=b&limit=%ld",
                      encodedId, (long)limit];
    NSURLRequest *req = [self requestWithPath:path method:@"GET"];
    [self sendRequest:req completion:completion];
}

- (void)getMembersForRoom:(NSString *)roomId
               completion:(void(^)(NSDictionary *members, NSError *error))completion {
    NSDictionary *cached = [self cachedMembersForRoom:roomId];
    if (cached) {
        completion(cached, nil);
        return;
    }

    NSString *encodedId = NeoURLEncode(roomId);
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/members", encodedId];
    NSURLRequest *req = [self requestWithPath:path method:@"GET"];

    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connErr) {
        if (connErr) {
            completion(nil, connErr);
            return;
        }
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        if (httpResp.statusCode >= 400) {
            completion(nil, [NSError errorWithDomain:@"MatrixAPI" code:httpResp.statusCode userInfo:nil]);
            return;
        }
        if (!data) {
            completion(@{}, nil);
            return;
        }
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr) {
            completion(nil, jsonErr);
            return;
        }
        NSMutableDictionary *members = [NSMutableDictionary dictionary];
        NSArray *chunk = json[@"chunk"];
        if (![chunk isKindOfClass:[NSArray class]]) chunk = @[];

        for (id evtRaw in chunk) {
            if (![evtRaw isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *evt = (NSDictionary *)evtRaw;

            id typeRaw = evt[@"type"];
            if (![typeRaw isKindOfClass:[NSString class]]) continue;
            if (![(NSString *)typeRaw isEqualToString:@"m.room.member"]) continue;

            id userIdRaw = evt[@"state_key"];
            if (![userIdRaw isKindOfClass:[NSString class]]) continue;
            NSString *userId = (NSString *)userIdRaw;
            if ([userId length] == 0) continue;

            id contentRaw = evt[@"content"];
            NSDictionary *content = [contentRaw isKindOfClass:[NSDictionary class]]
                ? (NSDictionary *)contentRaw : @{};

            id membershipRaw = content[@"membership"];
            if ([membershipRaw isKindOfClass:[NSString class]] &&
                ![(NSString *)membershipRaw isEqualToString:@"join"]) {
                continue;
            }

            id displayNameRaw = content[@"displayname"];
            NSString *displayName = [displayNameRaw isKindOfClass:[NSString class]]
                ? (NSString *)displayNameRaw : userId;

            id avatarUrlRaw = content[@"avatar_url"];
            NSString *avatarUrl = [avatarUrlRaw isKindOfClass:[NSString class]]
                ? (NSString *)avatarUrlRaw : @"";

            [members setObject:@{@"displayname": displayName, @"avatar_url": avatarUrl}
                        forKey:userId];
        }

        NSLog(@"[Members] Parsed %lu valid members from %lu chunk events",
              (unsigned long)[members count], (unsigned long)[chunk count]);
        [self cacheMembers:members forRoom:roomId];
        completion(members, nil);
    }];
}



#pragma mark - Cache

- (UIImage *)cachedImageForMXC:(NSString *)mxcURL {
    return [self imageFromAvatarDiskForKey:mxcURL];
}

#pragma mark - Message Events Disk Cache

- (NSString *)messageCacheDir {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths[0] stringByAppendingPathComponent:@"com.neo.messageCache"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

- (NSString *)messageCachePathForRoom:(NSString *)roomId {
    NSString *safe = [roomId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [[self messageCacheDir] stringByAppendingPathComponent:safe];
}

- (void)saveMessageEvents:(NSArray *)events forRoom:(NSString *)roomId {
    if (!events || !roomId) return;
    NSInteger count = [events count];
    if (count <= 5) {
        [events writeToFile:[self messageCachePathForRoom:roomId] atomically:YES];
    } else {
        NSArray *first = [events subarrayWithRange:NSMakeRange(0, 5)];
        [first writeToFile:[self messageCachePathForRoom:roomId] atomically:YES];
    }
}

- (NSArray *)cachedMessageEventsForRoom:(NSString *)roomId {
    return [NSArray arrayWithContentsOfFile:[self messageCachePathForRoom:roomId]];
}

- (NSArray *)cachedMessagesForRoom:(NSString *)roomId {
    NSArray *mem = [self.messageCache objectForKey:roomId];
    if (mem) return mem;
    NSArray *events = [self cachedMessageEventsForRoom:roomId];
    if (!events) return nil;
    NSMutableArray *msgs = [NSMutableArray array];
    for (NSDictionary *evt in [events reverseObjectEnumerator]) {
        if (![evt isKindOfClass:[NSDictionary class]]) continue;
        NSString *type = evt[@"type"];
        if (![type isEqualToString:@"m.room.message"]) continue;
        MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:evt roomId:roomId];
        if (msg && msg.eventId) [msgs addObject:msg];
    }
    if ([msgs count] > 0) {
        [self.messageCache setObject:msgs forKey:roomId];
        return msgs;
    }
    return nil;
}

- (void)cacheMessages:(NSArray *)messages forRoom:(NSString *)roomId {
    [self.messageCache setObject:messages forKey:roomId];
}

- (NSDictionary *)cachedMembersForRoom:(NSString *)roomId {
    NSDictionary *mem = [self.memberCache objectForKey:roomId];
    if (mem) return mem;
    return [self loadMembersFromDiskForRoom:roomId];
}

- (void)cacheMembers:(NSDictionary *)members forRoom:(NSString *)roomId {
    [self.memberCache setObject:members forKey:roomId];
    [self saveMembersToDisk:members forRoom:roomId memberCount:[members count]];
}

#pragma mark - Persistent Member Cache

- (NSString *)memberCacheDir {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths[0] stringByAppendingPathComponent:@"com.neo.memberCache"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:cacheDir]) {
        [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return cacheDir;
}

- (NSString *)memberCachePathForRoom:(NSString *)roomId {
    NSString *safeName = [roomId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [[self memberCacheDir] stringByAppendingPathComponent:safeName];
}

- (void)saveMembersToDisk:(NSDictionary *)members forRoom:(NSString *)roomId memberCount:(NSInteger)count {
    if (!members || [members count] == 0) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableDictionary *plist = [NSMutableDictionary dictionary];
        [plist setObject:members forKey:@"members"];
        [plist setObject:@(count) forKey:@"memberCount"];
        [plist setObject:[NSDate date] forKey:@"cachedAt"];
        NSString *path = [self memberCachePathForRoom:roomId];
        [plist writeToFile:path atomically:YES];
    });
}

- (NSDictionary *)loadMembersFromDiskForRoom:(NSString *)roomId {
    NSString *path = [self memberCachePathForRoom:roomId];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!plist) return nil;
    NSDictionary *members = plist[@"members"];
    if (![members isKindOfClass:[NSDictionary class]] || [members count] == 0) return nil;
    [self.memberCache setObject:members forKey:roomId];
    return members;
}

- (NSInteger)cachedMemberCountForRoom:(NSString *)roomId {
    NSString *path = [self memberCachePathForRoom:roomId];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
    return [plist[@"memberCount"] integerValue];
}

- (NSString *)mxcURLToHTTP:(NSString *)mxcURL {
    return [self mxcURLToHTTP:mxcURL thumbnail:NO];
}

- (NSString *)mxcURLToHTTP:(NSString *)mxcURL thumbnail:(BOOL)thumbnail {
    if (![mxcURL hasPrefix:@"mxc://"]) return nil;
    NSString *path = [mxcURL substringFromIndex:6];
    NSRange slash = [path rangeOfString:@"/"];
    if (slash.location == NSNotFound) return nil;
    NSString *serverName = [path substringToIndex:slash.location];
    NSString *mediaId = [path substringFromIndex:slash.location + 1];

    if (thumbnail) {
        return [NSString stringWithFormat:
            @"%@/_matrix/client/v1/media/thumbnail/%@/%@?width=256&height=256&method=scale",
            self.homeserver, serverName, mediaId];
    }
    return [NSString stringWithFormat:
        @"%@/_matrix/client/v1/media/download/%@/%@",
        self.homeserver, serverName, mediaId];
}

- (void)downloadImageFromMXC:(NSString *)mxcURL
                  completion:(void(^)(UIImage *image, NSError *error))completion {
    if (!mxcURL || [mxcURL length] == 0) {
        completion(nil, nil);
        return;
    }

    UIImage *cached = [self.avatarCache objectForKey:mxcURL];
    if (cached) {
        completion(cached, nil);
        return;
    }

    UIImage *diskImage = [self imageFromAvatarDiskForKey:mxcURL];
    if (diskImage) {
        [self.avatarCache setObject:diskImage forKey:mxcURL];
        completion(diskImage, nil);
        return;
    }

    // Avatars: 256x256 thumbnail primary (60pt views need ~120px @2x); full download only as fallback
    [self downloadFromURL:[self mxcURLToHTTP:mxcURL thumbnail:YES]
               fallbackURL:[self mxcURLToHTTP:mxcURL thumbnail:NO]
                  cacheKey:mxcURL
                 completion:completion];
}

- (void)downloadDataFromMXC:(NSString *)mxcURL
                 completion:(void(^)(NSData *data, NSString *mimeType, NSError *error))completion {
    if (!mxcURL || [mxcURL length] == 0 || !completion) {
        if (completion) completion(nil, nil, nil);
        return;
    }
    NSString *urlString = [self mxcURLToHTTP:mxcURL];
    NSURL *url = urlString ? [NSURL URLWithString:urlString] : nil;
    if (!url) {
        completion(nil, nil, [NSError errorWithDomain:@"MatrixAPI" code:-1 userInfo:nil]);
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:@"GET"];
    [req setTimeoutInterval:60];
    if (self.accessToken) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
   forHTTPHeaderField:@"Authorization"];
    }
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connErr) {
        if (connErr || !data || [data length] == 0) {
            completion(nil, nil, connErr);
            return;
        }
        NSString *mime = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            mime = [(NSHTTPURLResponse *)response allHeaderFields][@"Content-Type"];
        }
        completion(data, mime, nil);
    }];
}

+ (void)cleanupMediaCacheOlderThanDays:(NSInteger)days {
    NSString *cachesRoot = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    NSString *mediaDir = [cachesRoot stringByAppendingPathComponent:@"MediaCache"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:mediaDir error:nil];
    if (!contents) return;
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-(NSTimeInterval)days * 86400.0];
    for (NSString *name in contents) {
        NSString *path = [mediaDir stringByAppendingPathComponent:name];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        NSDate *modDate = [attrs fileModificationDate];
        if (modDate && [modDate compare:cutoff] == NSOrderedAscending) {
            [fm removeItemAtPath:path error:nil];
        }
    }
}

- (void)downloadFromURL:(NSString *)urlString
            fallbackURL:(NSString *)fallbackURLString
               cacheKey:(NSString *)cacheKey
             completion:(void(^)(UIImage *image, NSError *error))completion {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self downloadFromURL:urlString fallbackURL:fallbackURLString cacheKey:cacheKey completion:completion];
        });
        return;
    }
    
    // WATCHDOG: Si han pasado 90s sin actividad pero hay descargas pendientes,
    // el contador probablemente quedó pegado (timeout máximo es 20s)
    if ([_pendingImageDownloads count] > 0 && _activeImageDownloads > 0 &&
        ([NSDate timeIntervalSinceReferenceDate] - _lastImgActivity) > 90.0) {
        IMGLog(@"WATCHDOG: Reset _activeImageDownloads (stuck for >90s)");
        _activeImageDownloads = 0;
    }
    
    if (!_pendingImageDownloads) _pendingImageDownloads = [NSMutableArray array];

    NSMutableDictionary *job = [NSMutableDictionary dictionary];
    [job setObject:urlString ?: @"" forKey:@"url"];
    [job setObject:fallbackURLString ?: @"" forKey:@"fb"];
    [job setObject:cacheKey ?: @"" forKey:@"key"];
    if (completion) [job setObject:completion forKey:@"completion"];
    [_pendingImageDownloads addObject:job];
    [self drainImageQueue];
}

- (void)drainImageQueue {
    if (_activeImageDownloads >= kMaxConcurrentImageDownloads) return;
    if (!_pendingImageDownloads || [_pendingImageDownloads count] == 0) return;

    NSDictionary *job = [_pendingImageDownloads objectAtIndex:0];
    [_pendingImageDownloads removeObjectAtIndex:0];
    _activeImageDownloads++;
    _lastImgActivity = [NSDate timeIntervalSinceReferenceDate];

    NSString *url = [job[@"url"] length] > 0 ? job[@"url"] : nil;
    NSString *fb = [job[@"fb"] length] > 0 ? job[@"fb"] : nil;
    NSString *key = job[@"key"];
    void (^jobCompletion)(UIImage *, NSError *) = job[@"completion"];

    [self performDownloadFromURL:url
                     fallbackURL:fb
                        cacheKey:key
                      completion:^(UIImage *image, NSError *error) {
        _activeImageDownloads--;
        _lastImgActivity = [NSDate timeIntervalSinceReferenceDate];
        [self drainImageQueue];
        if (jobCompletion) jobCompletion(image, error);
    }];
}

- (void)performDownloadFromURL:(NSString *)urlString
                   fallbackURL:(NSString *)fallbackURLString
                      cacheKey:(NSString *)cacheKey
                    completion:(void(^)(UIImage *image, NSError *error))completion {
    if (!urlString) {
        completion(nil, [NSError errorWithDomain:@"MatrixAPI" code:-1 userInfo:nil]);
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"MatrixAPI" code:-2 userInfo:nil]);
        return;
    }

    IMGLog(@"URL: %@", urlString);
    IMGLog(@"Token presente: %@", self.accessToken ? @"SI (len=%d)" : @"NO",
           (int)[self.accessToken length]);

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:@"GET"];
    [req setTimeoutInterval:20];
    if (self.accessToken) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
   forHTTPHeaderField:@"Authorization"];
    }

    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connErr) {
        if (connErr) {
            IMGLog(@"Error conexión: %@", connErr.localizedDescription);
            if (fallbackURLString && ![fallbackURLString isEqualToString:urlString]) {
                IMGLog(@"Intentando fallback: %@", fallbackURLString);
                [self performDownloadFromURL:fallbackURLString
                          fallbackURL:nil
                             cacheKey:cacheKey
                           completion:completion];
            } else {
                completion(nil, connErr);
            }
            return;
        }

        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        IMGLog(@"HTTP %ld para %@", (long)httpResp.statusCode, urlString);

        if (httpResp.statusCode >= 400) {
            NSString *bodyStr = data ?
                [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
            IMGLog(@"Error %ld: %@", (long)httpResp.statusCode, bodyStr);
            if (fallbackURLString && ![fallbackURLString isEqualToString:urlString]) {
                IMGLog(@"Intentando fallback: %@", fallbackURLString);
                [self performDownloadFromURL:fallbackURLString
                          fallbackURL:nil
                             cacheKey:cacheKey
                           completion:completion];
            } else {
                completion(nil, [NSError errorWithDomain:@"MatrixAPI"
                                                   code:httpResp.statusCode userInfo:nil]);
            }
            return;
        }

        if (!data || [data length] == 0) {
            IMGLog(@"Respuesta vacía");
            completion(nil, nil);
            return;
        }

        UIImage *image = [UIImage imageWithData:data];
        if (!image) {
            IMGLog(@"imageWithData falló. Bytes: %lu. Header: %@",
                  (unsigned long)[data length],
                  [[NSString alloc] initWithData:[data subdataWithRange:
                      NSMakeRange(0, MIN(16, [data length]))]
                                        encoding:NSISOLatin1StringEncoding]);
            NSString *ct = [(NSHTTPURLResponse *)response allHeaderFields][@"Content-Type"];
            IMGLog(@"Content-Type: %@, bytes: %lu", ct, (unsigned long)[data length]);
            completion(nil, nil);
            return;
        }

        IMGLog(@"OK: %.0fx%.0f desde %@", image.size.width, image.size.height, urlString);
        [self.avatarCache setObject:image forKey:cacheKey cost:[data length]];
        [self saveAvatarToDisk:image forKey:cacheKey];
        completion(image, nil);
    }];
}

#pragma mark - Avatar Disk Cache

- (NSString *)avatarCacheDir {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths[0] stringByAppendingPathComponent:@"com.neo.avatarCache"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

- (NSString *)avatarCachePathForKey:(NSString *)key {
    const char *str = [key UTF8String];
    unsigned char md[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), md);
    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", md[i]];
    }
    return [[self avatarCacheDir] stringByAppendingPathComponent:[hash stringByAppendingString:@".png"]];
}

- (void)saveAvatarToDisk:(UIImage *)image forKey:(NSString *)key {
    if (!image || [key length] == 0) return;
    if (image.size.width > 1024 || image.size.height > 1024) return;
    NSData *png = UIImagePNGRepresentation(image);
    if (!png) return;
    NSString *path = [self avatarCachePathForKey:key];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [png writeToFile:path atomically:YES];
    });
}

- (UIImage *)imageFromAvatarDiskForKey:(NSString *)key {
    if ([key length] == 0) return nil;
    NSString *path = [self avatarCachePathForKey:key];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

- (void)deleteCachedMediaForMXC:(NSString *)mxcURL {
    if (!mxcURL || [mxcURL length] == 0) return;
    
    [self.avatarCache removeObjectForKey:mxcURL];
    
    NSString *avatarPath = [self avatarCachePathForKey:mxcURL];
    [[NSFileManager defaultManager] removeItemAtPath:avatarPath error:nil];
    
    NSString *safeName = [mxcURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    safeName = [safeName stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    NSString *cachesRoot = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    
    NSString *mediaPath = [[cachesRoot stringByAppendingPathComponent:@"MediaCache"] 
                           stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", safeName]];
    [[NSFileManager defaultManager] removeItemAtPath:mediaPath error:nil];
    
    NSString *fileDir = [cachesRoot stringByAppendingPathComponent:@"FileCache"];
    NSArray *fileContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fileDir error:nil];
    for (NSString *fileName in fileContents) {
        if ([fileName hasPrefix:safeName]) {
            NSString *path = [fileDir stringByAppendingPathComponent:fileName];
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }
    }
}

- (void)uploadImage:(UIImage *)image
         completion:(void(^)(NSString *contentURI, NSError *error))completion {
    if (!image) {
        if (completion) {
            NSError *err = [NSError errorWithDomain:@"MatrixAPIClient"
                                               code:-1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Image is nil"}];
            completion(nil, err);
        }
        return;
    }
    NSData *imageData = UIImageJPEGRepresentation(image, 0.80);
    if (!imageData) {
        imageData = UIImageJPEGRepresentation(image, 0.50);
    }
    [self uploadData:imageData
            mimeType:@"image/jpeg"
            filename:@"image.jpg"
          completion:completion];
}

#pragma mark - Local room names

+ (NSString *)localNameForRoomId:(NSString *)roomId {
    if (!roomId) return nil;
    NSDictionary *names = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey:@"localRoomNames"];
    return names[roomId];
}

+ (void)setLocalName:(NSString *)name forRoomId:(NSString *)roomId {
    if (!roomId) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *names = [[defaults dictionaryForKey:@"localRoomNames"]
        mutableCopy] ?: [NSMutableDictionary dictionary];
    if (name && [name length] > 0) {
        names[roomId] = name;
    } else {
        [names removeObjectForKey:roomId];
    }
    [defaults setObject:names forKey:@"localRoomNames"];
    [defaults synchronize];
}

@end

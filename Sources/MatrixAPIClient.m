#import "MatrixAPIClient.h"
#import "NeoCompatibility.h"
#import <Security/Security.h>

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

@implementation MatrixAPIClient

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
        instance.messageCache = [[NSCache alloc] init];
        instance.memberCache = [[NSCache alloc] init];
        instance.avatarCache = [[NSCache alloc] init];
    });
    return instance;
}

- (void)saveCredentials {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.homeserver forKey:kDefaultsKeyHomeserver];
    [defaults setObject:self.accessToken forKey:kDefaultsKeyAccessToken];
    [defaults setObject:self.deviceId forKey:kDefaultsKeyDeviceId];
    [defaults setObject:self.userId forKey:kDefaultsKeyUserId];
    [defaults synchronize];

    if (self.deviceId) {
        NSString *path = @"/var/mobile/Library/MatrixClient";
        NSError *err = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        [self.deviceId writeToFile:[path stringByAppendingPathComponent:@"device_id"]
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:&err];
        if (err) {
            NSLog(@"MatrixAPIClient: Failed to write device_id: %@", err);
        }

    }

    // Write access_token for MatrixPushd
    if (self.accessToken) {
        NSString *path = @"/var/mobile/Library/MatrixClient";
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        NSString *tokenPath = [path stringByAppendingPathComponent:@"access_token"];
        NSError *tokenErr = nil;
        [self.accessToken writeToFile:tokenPath
                           atomically:YES
                             encoding:NSUTF8StringEncoding
                                error:&tokenErr];
        if (tokenErr) {
            NSLog(@"[MatrixAPIClient] Failed to write access_token: %@", tokenErr);
        } else {
            NSLog(@"[MatrixAPIClient] access_token written to %@", tokenPath);
        }
    }

    // Shared keychain for daemon
    if (self.accessToken) {
        [self keychainSet:@"win.otcidor.neo.token" value:self.accessToken];
    }
    if (self.homeserver) {
        [self keychainSet:@"win.otcidor.neo.homeserver" value:self.homeserver];
    }
}

- (void)keychainSet:(NSString *)key value:(NSString *)value {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlways
    };
    SecItemDelete((__bridge CFDictionaryRef)query);

    NSMutableDictionary *addQuery = [query mutableCopy];
    addQuery[(__bridge id)kSecValueData] = data;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    if (status != errSecSuccess) {
        NSLog(@"[MatrixAPIClient] Keychain save failed: %d", (int)status);
    }
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
    void (^handleResp)(NSURLResponse *, NSData *, NSError *) = ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            completion(nil, connectionError);
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
            completion(nil, err);
            return;
        }
        if (!data) {
            completion(@{}, nil);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&jsonError];
        if (jsonError) {
            completion(nil, jsonError);
        } else {
            completion(json, nil);
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
                      roomId, txnId];
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

- (void)editMessage:(NSString *)newBody
             roomId:(NSString *)roomId
            eventId:(NSString *)eventId
         completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:
        @"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
        roomId, txnId];
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
        roomId, txnId];
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
                     roomId, eventId, txnId];
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
        @"/_matrix/client/r0/rooms/%@/receipt/m.read/%@", roomId, eventId];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"POST"];
    NSData *emptyJson = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:nil];
    [req setHTTPBody:emptyJson];
    [self sendRequest:req completion:completion ?: ^(NSDictionary *r, NSError *e) {
        if (e) NSLog(@"[ReadReceipt] Error enviando receipt: %@", e);
    }];
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
                      roomId, txnId];
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

- (void)uploadData:(NSData *)data
          mimeType:(NSString *)mimeType
           filename:(NSString *)filename
        completion:(void(^)(NSString *contentURI, NSError *error))completion {
    NSString *path = @"/_matrix/media/r0/upload";
    if ([filename length] > 0) {
        NSString *enc = [filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        path = [NSString stringWithFormat:@"/_matrix/media/r0/upload?filename=%@", enc];
    }
    NSMutableURLRequest *req = [self requestWithPath:path method:@"POST"];
    [req setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    [req setHTTPBody:data];

    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *urlResp, NSData *respData, NSError *connErr) {
        if (connErr) { completion(nil, connErr); return; }
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:respData options:0 error:&jsonErr];
        if (jsonErr) { completion(nil, jsonErr); return; }
        completion(json[@"content_uri"], nil);
    }];
}

- (void)sendImageMessage:(NSString *)imageURL
                   roomId:(NSString *)roomId
                  caption:(NSString *)caption
               completion:(MatrixCompletion)completion {
    NSString *txnId = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/send/m.room.message/%@",
                     roomId, txnId];
    NSMutableURLRequest *req = [self requestWithPath:path method:@"PUT"];
    NSDictionary *msgBody = @{
        @"msgtype": @"m.image",
        @"body": caption ?: @"",
        @"url": imageURL
    };
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msgBody options:0 error:&err];
    if (err) { completion(nil, err); return; }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)registerPusherWithPushKey:(NSString *)pushKey
                       completion:(MatrixCompletion)completion {
    NSMutableURLRequest *req = [self requestWithPath:@"/_matrix/client/r0/pushers/set"
                                              method:@"POST"];
    NSDictionary *pusherData = @{
        @"kind": @"http",
        @"app_id": @"win.otcidor.matrixpush",
        @"pushkey": pushKey,
        @"data": @{
            @"url": @"https://push.otcidor.win/_matrix/push/v1/notify"
        },
        @"lang": @"en",
        @"device_display_name": @"iPhone 5 (iOS 6)"
    };
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:pusherData options:0 error:&err];
    if (err) {
        completion(nil, err);
        return;
    }
    [req setHTTPBody:jsonData];
    [self sendRequest:req completion:completion];
}

- (void)getRoomMessages:(NSString *)roomId
             completion:(MatrixCompletion)completion {
    NSString *encodedId = [roomId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *path = [NSString stringWithFormat:@"/_matrix/client/r0/rooms/%@/messages?dir=b&limit=50",
                      encodedId];
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

    NSString *encodedId = [roomId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
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

- (NSArray *)cachedMessagesForRoom:(NSString *)roomId {
    return [self.messageCache objectForKey:roomId];
}

- (void)cacheMessages:(NSArray *)messages forRoom:(NSString *)roomId {
    [self.messageCache setObject:messages forKey:roomId];
}

- (NSDictionary *)cachedMembersForRoom:(NSString *)roomId {
    return [self.memberCache objectForKey:roomId];
}

- (void)cacheMembers:(NSDictionary *)members forRoom:(NSString *)roomId {
    [self.memberCache setObject:members forKey:roomId];
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

    [self downloadFromURL:[self mxcURLToHTTP:mxcURL thumbnail:NO]
              fallbackURL:[self mxcURLToHTTP:mxcURL thumbnail:YES]
                 cacheKey:mxcURL
                completion:completion];
}

- (void)downloadFromURL:(NSString *)urlString
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
                [self downloadFromURL:fallbackURLString
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
                [self downloadFromURL:fallbackURLString
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
        [self.avatarCache setObject:image forKey:cacheKey];
        completion(image, nil);
    }];
}

- (void)uploadImage:(UIImage *)image
         completion:(void(^)(NSString *contentURI, NSError *error))completion {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    NSString *path = @"/_matrix/media/r0/upload";
    NSMutableURLRequest *req = [self requestWithPath:path method:@"POST"];
    [req setValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
    [req setHTTPBody:imageData];

    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *urlResp, NSData *data, NSError *connErr) {
        if (connErr) { completion(nil, connErr); return; }
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr) { completion(nil, jsonErr); return; }
        completion(json[@"content_uri"], nil);
    }];
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
